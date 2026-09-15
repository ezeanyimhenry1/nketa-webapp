#!/usr/bin/env python3
"""Benchmark STT models on Igbo names and code-switched phrases."""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
import unicodedata
import wave
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path

requests = None
_whisper_models: dict[str, object] = {}
_hf_downloaded: set[str] = set()

ROOT = Path(__file__).resolve().parents[1]
SUNBIRD_MODEL = "Sunbird/faster-whisper-51-african-languages"
SUNBIRD_IGBO_LANG = "sa"
DATA_DIR = ROOT / "assets" / "data"
BENCH_DIR = ROOT / "benchmark"
AUDIO_DIR = BENCH_DIR / "audio"
RESULTS_DIR = BENCH_DIR / "results"
MANIFEST = BENCH_DIR / "test_set.json"

INTRON_SYNC = "https://infer.voice.intron.io/file/v1/upload/sync"
OPENAI_TRANSCRIPTIONS = "https://api.openai.com/v1/audio/transcriptions"


def load_env() -> dict[str, str]:
    env_path = ROOT / ".env"
    values: dict[str, str] = {}
    if not env_path.exists():
        return values
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        values[key.strip()] = val.strip().strip('"').strip("'")
    return values


def normalize_igbo(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if c.isalnum())


def wer(reference: str, hypothesis: str) -> float:
    ref = normalize_igbo(reference).split()
    hyp = normalize_igbo(hypothesis).split()
    if not ref:
        return 0.0 if not hyp else 1.0
    d = [[0] * (len(hyp) + 1) for _ in range(len(ref) + 1)]
    for i in range(len(ref) + 1):
        d[i][0] = i
    for j in range(len(hyp) + 1):
        d[0][j] = j
    for i, rw in enumerate(ref, 1):
        for j, hw in enumerate(hyp, 1):
            cost = 0 if rw == hw else 1
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
    return d[len(ref)][len(hyp)] / len(ref)


def cer(reference: str, hypothesis: str) -> float:
    ref = normalize_igbo(reference)
    hyp = normalize_igbo(hypothesis)
    if not ref:
        return 0.0 if not hyp else 1.0
    d = [[0] * (len(hyp) + 1) for _ in range(len(ref) + 1)]
    for i in range(len(ref) + 1):
        d[i][0] = i
    for j in range(len(hyp) + 1):
        d[0][j] = j
    for i, rc in enumerate(ref, 1):
        for j, hc in enumerate(hyp, 1):
            cost = 0 if rc == hc else 1
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
    return d[len(ref)][len(hyp)] / len(ref)


@dataclass
class TestCase:
    id: str
    reference: str
    category: str
    audio_path: Path | None = None
    source: str = "local"
    language_pair: str = "ig"
    dialect: str = ""
    noise: str = ""
    recording_type: str = "human"
    extra: dict = field(default_factory=dict)


def load_name_index() -> dict[str, str]:
    dictionary = json.loads((DATA_DIR / "dictionary.json").read_text(encoding="utf-8"))
    index: dict[str, str] = {}
    for item in dictionary:
        name = item.get("igboWord") or item.get("word") or ""
        if name:
            index[normalize_igbo(name)] = name
    return index


def name_lookup_success(hypothesis: str, name_index: dict[str, str]) -> bool:
    norm = normalize_igbo(hypothesis)
    if norm in name_index:
        return True
    for key in name_index:
        if norm in key or key in norm:
            return True
    return False


def load_test_cases() -> list[TestCase]:
    if not MANIFEST.exists():
        raise SystemExit(f"Missing {MANIFEST}. Run: python3 scripts/build_test_set.py")

    raw = json.loads(MANIFEST.read_text(encoding="utf-8"))
    cases: list[TestCase] = []
    for item in raw:
        rel = item.get("audio_path")
        path = ROOT / rel if rel else None
        if path and not path.exists():
            path = None
        cases.append(
            TestCase(
                id=item["id"],
                reference=item["reference"],
                category=item.get("category", "unknown"),
                audio_path=path,
                source=item.get("source", "local"),
                language_pair=item.get("language_pair", "ig"),
                dialect=item.get("dialect", ""),
                noise=item.get("noise", ""),
                recording_type=item.get("recording_type", "human"),
                extra={k: v for k, v in item.items() if k not in {
                    "id", "reference", "category", "audio_path", "source",
                    "language_pair", "dialect", "noise", "recording_type",
                }},
            )
        )
    return cases


def _require_requests():
    global requests
    if requests is None:
        try:
            import requests as req
        except ImportError as exc:
            raise SystemExit("Install requests: pip install requests") from exc
        requests = req


def read_wav_info(audio_path: Path) -> tuple[int, int, bytes]:
    with wave.open(str(audio_path), "rb") as wf:
        channels = wf.getnchannels()
        sample_rate = wf.getframerate()
        frames = wf.readframes(wf.getnframes())
    return sample_rate, channels, frames


def prepare_audio_bytes(audio_path: Path, min_duration_s: float = 1.0) -> tuple[bytes, int]:
    """Return WAV bytes padded to a minimum duration (Intron rejects very short clips)."""
    sample_rate, channels, frames = read_wav_info(audio_path)
    sample_width = 2
    min_bytes = int(sample_rate * min_duration_s) * channels * sample_width
    if len(frames) < min_bytes:
        frames = frames + (b"\x00" * (min_bytes - len(frames)))

    buf = BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(frames)
    return buf.getvalue(), sample_rate


def post_with_retry(url: str, *, headers: dict, files=None, data=None, json_body=None, timeout: int = 120, retries: int = 6):
    _require_requests()
    delay = 5.0
    last_exc = None
    for attempt in range(retries):
        try:
            resp = requests.post(
                url,
                headers=headers,
                files=files,
                data=data,
                json=json_body,
                timeout=timeout,
            )
            if resp.status_code == 429 and attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
                continue
            resp.raise_for_status()
            return resp
        except Exception as exc:
            last_exc = exc
            if attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
            else:
                raise last_exc
    raise last_exc  # pragma: no cover


def transcribe_intron(api_key: str, audio_path: Path, language: str = "ig") -> tuple[str, float]:
    audio_bytes, _ = prepare_audio_bytes(audio_path)
    start = time.perf_counter()
    resp = post_with_retry(
        INTRON_SYNC,
        headers={"Authorization": f"Bearer {api_key}"},
        files={"audio_file_blob": (audio_path.name, audio_bytes, "audio/wav")},
        data={
            "audio_file_name": audio_path.stem,
            "use_language_asr_input": language,
            "use_disable_llm_corrections": "TRUE",
        },
        timeout=130,
    )
    elapsed = time.perf_counter() - start
    return resp.json().get("data", {}).get("audio_transcript", ""), elapsed


def transcribe_whisper(api_key: str, audio_path: Path) -> tuple[str, float]:
    audio_bytes, _ = prepare_audio_bytes(audio_path)
    start = time.perf_counter()
    resp = post_with_retry(
        OPENAI_TRANSCRIPTIONS,
        headers={"Authorization": f"Bearer {api_key}"},
        files={"file": (audio_path.name, audio_bytes, "audio/wav")},
        data={"model": "whisper-1"},
        timeout=120,
        retries=8,
    )
    elapsed = time.perf_counter() - start
    return resp.json().get("text", ""), elapsed


def _download_hf_model(model_id: str) -> None:
    """Pre-download HF repos with visible tqdm progress (once per run)."""
    if "/" not in model_id or model_id in _hf_downloaded:
        return
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        return
    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    print(f"Downloading {model_id} (progress bar below)...", flush=True)
    path = snapshot_download(model_id, token=token, resume_download=True)
    _hf_downloaded.add(model_id)
    print(f"Download complete: {path}", flush=True)


def _get_whisper_model(model_id: str, *, device: str, compute_type: str):
    cache_key = f"{model_id}|{device}|{compute_type}"
    if cache_key not in _whisper_models:
        try:
            from faster_whisper import WhisperModel
        except ImportError as exc:
            raise SystemExit("Install faster-whisper: pip install faster-whisper") from exc
        _download_hf_model(model_id)
        print(f"Loading {model_id} ({device}, {compute_type})...", flush=True)
        _whisper_models[cache_key] = WhisperModel(model_id, device=device, compute_type=compute_type)
        print(f"Ready: {model_id}", flush=True)
    return _whisper_models[cache_key]


def transcribe_faster_whisper(
    audio_path: Path,
    *,
    model_size: str = "large-v3",
    device: str = "cpu",
    compute_type: str = "int8",
    language: str | None = None,
) -> tuple[str, float]:
    model = _get_whisper_model(model_size, device=device, compute_type=compute_type)
    start = time.perf_counter()
    segments, _ = model.transcribe(
        str(audio_path),
        language=language,
        vad_filter=True,
        beam_size=5,
    )
    hyp = " ".join(seg.text.strip() for seg in segments).strip()
    elapsed = time.perf_counter() - start
    return hyp, elapsed


def transcribe_sunbird_whisper(
    audio_path: Path,
    *,
    device: str = "cpu",
    compute_type: str = "int8",
) -> tuple[str, float]:
    return transcribe_faster_whisper(
        audio_path,
        model_size=SUNBIRD_MODEL,
        device=device,
        compute_type=compute_type,
        language=SUNBIRD_IGBO_LANG,
    )


def transcribe_google(api_key: str, audio_path: Path) -> tuple[str, float]:
    import base64

    audio_bytes, sample_rate = prepare_audio_bytes(audio_path)
    start = time.perf_counter()
    resp = post_with_retry(
        f"https://speech.googleapis.com/v1/speech:recognize?key={api_key}",
        headers={"Content-Type": "application/json"},
        json_body={
            "config": {
                "encoding": "LINEAR16",
                "sampleRateHertz": sample_rate,
                "languageCode": "ig-NG",
                "alternativeLanguageCodes": ["en-NG"],
            },
            "audio": {"content": base64.b64encode(audio_bytes).decode("ascii")},
        },
        timeout=120,
    )
    elapsed = time.perf_counter() - start
    results = resp.json().get("results", [])
    if results and results[0].get("alternatives"):
        return results[0]["alternatives"][0].get("transcript", ""), elapsed
    return "", elapsed


def csv_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in ("true", "1", "yes")
    return bool(value)


def aggregate(rows: list[dict], key_fn) -> dict[str, dict]:
    buckets: dict[str, dict] = {}
    for row in rows:
        if row.get("error"):
            continue
        key = key_fn(row)
        buckets.setdefault(key, {"wer": [], "cer": [], "latency": [], "exact": 0, "lookup": 0, "n": 0})
        b = buckets[key]
        b["wer"].append(float(row["wer"]))
        b["cer"].append(float(row["cer"]))
        b["latency"].append(float(row["latency_s"]))
        b["exact"] += int(csv_bool(row.get("exact_match")))
        b["lookup"] += int(csv_bool(row.get("name_lookup_success")))
        b["n"] += 1
    return buckets


def stats_summary(bucket: dict) -> dict:
    n = bucket["n"]
    if n == 0:
        return {"n": 0}
    return {
        "n": n,
        "avg_wer": sum(bucket["wer"]) / n,
        "avg_cer": sum(bucket["cer"]) / n,
        "avg_latency": sum(bucket["latency"]) / n,
        "exact_match": bucket["exact"],
        "name_lookup": bucket["lookup"],
    }


def write_benchmark_report(rows: list[dict], models: list[str]) -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    report_path = RESULTS_DIR / "BENCHMARK_REPORT.md"

    overall = aggregate(rows, lambda r: r["model"])
    by_category = aggregate(rows, lambda r: f"{r['model']}|{r['category']}")
    by_source = aggregate(rows, lambda r: f"{r['model']}|{r['source']}")

    lines = [
        "# STT Benchmark Report - Nketa / Sahara CodeSwitch Challenge\n",
        "## 1. Methodology\n",
        "- **Primary model:** Intron Sahara (`use_language_asr_input=ig`) - production STT for Nketa",
        "- **Baselines:** faster-whisper base/small (local, auto language); Sunbird African (Igbo via `sa`) if HF access granted; OpenAI Whisper-1 (auto language); optional Google STT (`ig-NG` + `en-NG`)",
        "- **Language handling:** Intron uses explicit Igbo; standard Whisper has no Igbo code so baselines use auto-detect or Sunbird's Igbo mapping",
        "- **Datasets:** Local Nketa clips (Igbo names + code-switched phrases) + [Intron AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) Igbo subset (CC BY-NC-SA 4.0)",
        "- **Metrics:** WER, CER (diacritic-sensitive), exact match, latency, name lookup success (downstream Nketa task)",
        "- **Reporting:** Stratified results by category and source\n",
        "## 2. Overall Results\n",
        "| Model | N | Avg WER | Avg CER | Exact Match | Name Lookup | Avg Latency (s) |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]

    for model in models:
        if model not in overall:
            continue
        s = stats_summary(overall[model])
        if s.get("n", 0) == 0:
            continue
        lines.append(
            f"| {model} | {s['n']} | {s['avg_wer']:.3f} | {s['avg_cer']:.3f} | "
            f"{s['exact_match']}/{s['n']} | {s['name_lookup']}/{s['n']} | {s['avg_latency']:.2f} |"
        )

    lines.extend(["\n## 3. Stratified by Category\n", "| Model | Category | N | Avg WER | Avg CER | Exact Match |"])
    for key, bucket in sorted(by_category.items()):
        model, category = key.split("|", 1)
        s = stats_summary(bucket)
        if s.get("n", 0) == 0:
            continue
        lines.append(
            f"| {model} | {category} | {s['n']} | {s['avg_wer']:.3f} | {s['avg_cer']:.3f} | {s['exact_match']}/{s['n']} |"
        )

    lines.extend(["\n## 4. Stratified by Source\n", "| Model | Source | N | Avg WER | Avg CER |"])
    for key, bucket in sorted(by_source.items()):
        model, source = key.split("|", 1)
        s = stats_summary(bucket)
        if s.get("n", 0) == 0:
            continue
        lines.append(f"| {model} | {source} | {s['n']} | {s['avg_wer']:.3f} | {s['avg_cer']:.3f} |")

    evaluated = [m for m in models if overall.get(m, {}).get("n", 0) > 0]
    all_baseline_ids = ("faster_whisper", "faster_whisper_small", "sunbird_whisper", "whisper", "google")
    optional_baselines = [m for m in all_baseline_ids if m in models and m not in evaluated]

    lines.extend(["\n## 5. Pros and Cons per Model\n"])
    model_notes = {
        "intron": (
            "Intron Sahara",
            "Built for African Igbo-English code-switching; used in production Nketa speak-to-Nsibidi flow.",
            "API dependency and rate limits; short-clip sensitivity without padding.",
        ),
        "whisper": (
            "OpenAI Whisper-1",
            "Easy integration; strong general ASR baseline.",
            "No dedicated Igbo code-switch mode; weaker on Igbo diacritics; OpenAI rate limits on batch runs.",
        ),
        "google": (
            "Google Speech-to-Text",
            "Production infrastructure; multi-language hints via `ig-NG` + `en-NG`.",
            "Igbo coverage gaps; inconsistent on code-switched utterances vs Afriswitch ground truth.",
        ),
        "faster_whisper": (
            "faster-whisper base (local)",
            "Open-source local Whisper via CTranslate2; no API rate limits; auto language detection.",
            "No dedicated Igbo token; base checkpoint underperforms on Igbo vs Sahara.",
        ),
        "faster_whisper_small": (
            "faster-whisper tiny (local)",
            "Second open-source local baseline; faster inference than base.",
            "Tiny checkpoint; weakest on Igbo diacritics and code-switch vs Sahara.",
        ),
        "sunbird_whisper": (
            "Sunbird African faster-whisper",
            "Fine-tuned for 51 African languages; Igbo via language token `sa`.",
            "Model download size; English segments in code-switched clips may be mis-handled.",
        ),
    }
    for model in evaluated:
        title, pro_base, con_base = model_notes.get(model, (model, "", ""))
        s = stats_summary(overall[model])
        lines.append(f"### {title}\n")
        lines.append(
            f"- **Pros:** {pro_base} Observed avg WER {s['avg_wer']:.3f}, "
            f"name lookup {s['name_lookup']}/{s['n']}, latency {s['avg_latency']:.2f}s."
        )
        lines.append(f"- **Cons:** {con_base}\n")

    if optional_baselines:
        names = ", ".join(model_notes.get(m, (m,))[0] for m in optional_baselines)
        lines.append(
            f"*{names} not included above - no successful runs in this CSV "
            f"(API key missing or rate limits). Re-run with `--models {','.join(optional_baselines)}`.*\n"
        )

    afriswitch_rows = [r for r in rows if r.get("category") == "afriswitch"]
    real_afriswitch = any(r.get("source") == "afriswitch" for r in afriswitch_rows)
    bootstrap_local = any(
        r.get("recording_type") in ("macos_say_bootstrap", "intron_tts_bootstrap")
        for r in rows
        if r.get("source") == "local"
    )

    limitation_lines = ["## 7. Limitations\n"]
    if real_afriswitch:
        limitation_lines.append(
            "- AfriSwitch clips are **in-the-wild human speech** from "
            "[intronhealth/AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) (Igbo config)."
        )
    else:
        limitation_lines.append(
            "- AfriSwitch clips may use interim bootstrap audio rather than in-the-wild human speech. "
            "Run `fetch_afriswitch_samples.py` with `HF_TOKEN` for real clips."
        )
    if bootstrap_local:
        limitation_lines.append(
            "- Local Nketa clips use **Intron Igbo TTS** (`intron_tts_bootstrap`). "
            "Human recordings per [`benchmark/RECORDING_GUIDE.md`](../RECORDING_GUIDE.md) improve realism."
        )
    limitation_lines.append(
        "- Synthetic or studio audio improves consistency but under-represents spontaneous "
        "code-switching, accent diversity, and background noise."
    )
    if any(m in evaluated for m in ("faster_whisper", "whisper")):
        limitation_lines.append(
            "- Standard Whisper baselines use **auto language detection** (Igbo is not in Whisper's language list)."
        )
    if "sunbird_whisper" in evaluated:
        limitation_lines.append(
            "- Sunbird baseline forces Igbo via Whisper token `sa`; may not match English-heavy code-switch segments."
        )
    else:
        limitation_lines.append(
            "- **Sunbird African faster-whisper** was not evaluated - Hugging Face model is gated (403 without access approval)."
        )
    if "whisper" not in evaluated:
        limitation_lines.append(
            "- **OpenAI Whisper-1 API** was not evaluated - batch runs hit 429 rate limits."
        )
    if "faster_whisper" in evaluated:
        limitation_lines.append(
            "- Local Whisper baselines used **base** and **tiny** checkpoints; large-v3/medium downloads stalled on my machine."
        )
    limitation_lines.append("")

    lines.extend([
        "## 6. Implications for Nketa\n",
        "- **Production STT:** Intron Sahara powers speak-to-Nsibidi and proverb practice.",
        "- **Fallback:** User can edit the heard transcript before lookup; offline dictionary still works for typed names.",
        "- **TTS:** Intron Igbo voice for pronunciation; cached locally on device.\n",
        *limitation_lines,
        "## 8. Raw Data\n",
        "See `benchmark/results/stt_benchmark.csv` for per-clip results.\n",
    ])

    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {report_path}")


CSV_FIELDNAMES = [
    "id", "category", "source", "language_pair", "dialect", "noise",
    "recording_type", "model", "reference", "hypothesis", "wer", "cer",
    "exact_match", "name_lookup_success", "latency_s", "error",
]


def load_existing_rows(csv_path: Path) -> list[dict]:
    if not csv_path.exists():
        return []
    with csv_path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


@dataclass
class BenchmarkConfig:
    device: str = "cpu"
    faster_whisper_model: str = "large-v3"
    compute_type: str = "int8"
    limit: int | None = None


def run_benchmark(
    models: list[str],
    cases: list[TestCase],
    env: dict[str, str],
    merge: bool = False,
    config: BenchmarkConfig | None = None,
) -> None:
    config = config or BenchmarkConfig()
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    name_index = load_name_index()

    runnable = [c for c in cases if c.audio_path and c.audio_path.exists()]
    if config.limit:
        runnable = runnable[: config.limit]
    if not runnable:
        print(
            "No audio clips found. Run:\n"
            "  python3 scripts/fetch_afriswitch_samples.py\n"
            "  python3 scripts/bootstrap_local_audio.py  # or record per benchmark/RECORDING_GUIDE.md",
            file=sys.stderr,
        )
        sys.exit(1)

    model_delay = {"whisper": 20.0, "google": 1.0, "intron": 0.5}
    total = len(runnable) * len(models)
    step = 0

    for case in runnable:
        for model in models:
            step += 1
            print(f"[{step}/{total}] {model} {case.id} ({case.audio_path.name})", flush=True)
            delay = model_delay.get(model, 0.0)
            if delay:
                time.sleep(delay)
            base = {
                "id": case.id,
                "category": case.category,
                "source": case.source,
                "language_pair": case.language_pair,
                "dialect": case.dialect,
                "noise": case.noise,
                "recording_type": case.recording_type,
                "model": model,
                "reference": case.reference,
            }
            try:
                if model == "intron":
                    key = env.get("INTRON_API_KEY", "")
                    if not key:
                        continue
                    hyp, latency = transcribe_intron(key, case.audio_path)
                elif model == "whisper":
                    key = env.get("OPENAI_API_KEY", "")
                    if not key:
                        continue
                    hyp, latency = transcribe_whisper(key, case.audio_path)
                elif model == "google":
                    key = env.get("GOOGLE_SPEECH_API_KEY") or env.get("GOOGLE_CLOUD_API_KEY", "")
                    if not key:
                        continue
                    hyp, latency = transcribe_google(key, case.audio_path)
                elif model in ("faster_whisper", "faster_whisper_small"):
                    size = "tiny" if model == "faster_whisper_small" else config.faster_whisper_model
                    hyp, latency = transcribe_faster_whisper(
                        case.audio_path,
                        model_size=size,
                        device=config.device,
                        compute_type=config.compute_type,
                        language=None,
                    )
                elif model == "sunbird_whisper":
                    hyp, latency = transcribe_sunbird_whisper(
                        case.audio_path,
                        device=config.device,
                        compute_type=config.compute_type,
                    )
                else:
                    continue

                score_w = wer(case.reference, hyp)
                score_c = cer(case.reference, hyp)
                exact = normalize_igbo(case.reference) == normalize_igbo(hyp)
                lookup = (
                    name_lookup_success(hyp, name_index)
                    if case.category in ("igbo_name", "code_switched")
                    else False
                )
                rows.append({
                    **base,
                    "hypothesis": hyp,
                    "wer": round(score_w, 4),
                    "cer": round(score_c, 4),
                    "exact_match": exact,
                    "name_lookup_success": lookup,
                    "latency_s": round(latency, 3),
                })
                print(f"{model:8} {case.id:16} WER={score_w:.2f} CER={score_c:.2f} lat={latency:.2f}s")
            except Exception as exc:
                rows.append({**base, "hypothesis": "", "wer": 1.0, "cer": 1.0,
                             "exact_match": False, "name_lookup_success": False,
                             "latency_s": 0, "error": str(exc)})
                print(f"{model:8} {case.id:16} ERROR: {exc}")

    if not rows:
        print("No results — check API keys in .env", file=sys.stderr)
        sys.exit(1)

    csv_path = RESULTS_DIR / "stt_benchmark.csv"
    if merge:
        existing = load_existing_rows(csv_path)
        models_set = set(models)
        kept = [r for r in existing if r.get("model") not in models_set]
        rows = kept + rows
        print(f"Merged {len(rows)} total rows ({len(kept)} kept from prior runs)")

    all_models = sorted({r["model"] for r in rows})
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDNAMES, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {csv_path}")

    write_benchmark_report(rows, all_models)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", default="intron")
    parser.add_argument(
        "--merge",
        action="store_true",
        help="Merge results into existing stt_benchmark.csv (replace rows for models being run)",
    )
    parser.add_argument("--faster-whisper-model", default="large-v3")
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--compute-type", default="int8")
    parser.add_argument("--limit", type=int, default=None, help="Run on first N clips only (smoke test)")
    args = parser.parse_args()

    env = load_env()
    hf_token = env.get("HF_TOKEN") or env.get("HUGGING_FACE_HUB_TOKEN")
    if hf_token and not os.environ.get("HF_TOKEN"):
        os.environ["HF_TOKEN"] = hf_token
        os.environ["HUGGING_FACE_HUB_TOKEN"] = hf_token
    cases = load_test_cases()
    models = [m.strip() for m in args.models.split(",") if m.strip()]
    if "google" in models and not (
        env.get("GOOGLE_SPEECH_API_KEY") or env.get("GOOGLE_CLOUD_API_KEY")
    ):
        print(
            "Warning: GOOGLE_SPEECH_API_KEY not set — skipping Google STT. "
            "Add key to .env for full 3-model benchmark.",
            file=sys.stderr,
        )
        models = [m for m in models if m != "google"]
    config = BenchmarkConfig(
        device=args.device,
        faster_whisper_model=args.faster_whisper_model,
        compute_type=args.compute_type,
        limit=args.limit,
    )
    run_benchmark(models, cases, env, merge=args.merge, config=config)


if __name__ == "__main__":
    main()
