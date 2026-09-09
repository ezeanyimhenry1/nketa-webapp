#!/usr/bin/env python3
"""Benchmark STT models on Igbo names and code-switched phrases."""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path

requests = None  # lazy import for benchmark runs

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "data"
BENCH_DIR = ROOT / "benchmark"
AUDIO_DIR = BENCH_DIR / "audio"
RESULTS_DIR = BENCH_DIR / "results"

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


def normalize(text: str) -> str:
    import unicodedata

    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if c.isalnum())


def wer(reference: str, hypothesis: str) -> float:
    ref = normalize(reference).split()
    hyp = normalize(hypothesis).split()
    if not ref:
        return 0.0 if not hyp else 1.0
    # Levenshtein at word level
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


@dataclass
class TestCase:
    id: str
    reference: str
    audio_path: Path | None
    category: str


def build_test_set(limit_names: int = 25) -> list[TestCase]:
    dictionary = json.loads((DATA_DIR / "dictionary.json").read_text(encoding="utf-8"))
    cases: list[TestCase] = []

    for item in dictionary[:limit_names]:
        name = item.get("igboWord") or item.get("word") or ""
        if not name:
            continue
        audio = AUDIO_DIR / f"{normalize(name)}.wav"
        cases.append(
            TestCase(
                id=f"name_{item.get('id', name)}",
                reference=name,
                audio_path=audio if audio.exists() else None,
                category="igbo_name",
            )
        )

    code_switched = [
        ("cs_1", "My name is Chinedu", "My name is Chinedu"),
        ("cs_2", "Kedu aha gị", "Kedu aha gi"),
        ("cs_3", "Nna m bụ Emeka", "Nna m bu Emeka"),
        ("cs_4", "I am from Enugu", "I am from Enugu"),
        ("cs_5", "Chukwu gozie gị", "Chukwu gozie gi"),
        ("cs_6", "Onye kwe chi ya ekwe", "Onye kwe chi ya ekwe"),
        ("cs_7", "Biko kwuo ya ọzọ", "Biko kwuo ya ozo"),
        ("cs_8", "Nọ n'ụlọ", "No n'ulo"),
        ("cs_9", "Igbo amaka", "Igbo amaka"),
        ("cs_10", "Ndewo how are you", "Ndewo how are you"),
    ]
    for cid, reference, _ in code_switched:
        audio = AUDIO_DIR / f"{cid}.wav"
        cases.append(
            TestCase(
                id=cid,
                reference=reference,
                audio_path=audio if audio.exists() else None,
                category="code_switched",
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


def transcribe_intron(api_key: str, audio_path: Path, language: str = "ig") -> tuple[str, float]:
    _require_requests()
    start = time.perf_counter()
    with audio_path.open("rb") as f:
        resp = requests.post(
            INTRON_SYNC,
            headers={"Authorization": f"Bearer {api_key}"},
            files={"audio_file_blob": (audio_path.name, f, "audio/wav")},
            data={
                "audio_file_name": audio_path.stem,
                "use_language_asr_input": language,
                "use_disable_llm_corrections": "TRUE",
            },
            timeout=130,
        )
    elapsed = time.perf_counter() - start
    resp.raise_for_status()
    transcript = resp.json().get("data", {}).get("audio_transcript", "")
    return transcript, elapsed


def transcribe_whisper(api_key: str, audio_path: Path) -> tuple[str, float]:
    _require_requests()
    start = time.perf_counter()
    with audio_path.open("rb") as f:
        resp = requests.post(
            OPENAI_TRANSCRIPTIONS,
            headers={"Authorization": f"Bearer {api_key}"},
            files={"file": (audio_path.name, f, "audio/wav")},
            data={"model": "whisper-1", "language": "ig"},
            timeout=120,
        )
    elapsed = time.perf_counter() - start
    resp.raise_for_status()
    return resp.json().get("text", ""), elapsed


def transcribe_google(api_key: str, audio_path: Path) -> tuple[str, float]:
    """Google Cloud Speech-to-Text v1 sync recognize."""
    import base64

    _require_requests()
    audio_bytes = audio_path.read_bytes()
    start = time.perf_counter()
    resp = requests.post(
        f"https://speech.googleapis.com/v1/speech:recognize?key={api_key}",
        json={
            "config": {
                "encoding": "LINEAR16",
                "sampleRateHertz": 16000,
                "languageCode": "ig-NG",
                "alternativeLanguageCodes": ["en-NG"],
            },
            "audio": {"content": base64.b64encode(audio_bytes).decode("ascii")},
        },
        timeout=120,
    )
    elapsed = time.perf_counter() - start
    resp.raise_for_status()
    results = resp.json().get("results", [])
    transcript = ""
    if results:
        alt = results[0].get("alternatives", [])
        if alt:
            transcript = alt[0].get("transcript", "")
    return transcript, elapsed


def write_test_manifest(cases: list[TestCase]) -> None:
    BENCH_DIR.mkdir(parents=True, exist_ok=True)
    manifest = BENCH_DIR / "test_set.json"
    payload = [
        {
            "id": c.id,
            "reference": c.reference,
            "audio_path": str(c.audio_path) if c.audio_path else None,
            "category": c.category,
        }
        for c in cases
    ]
    manifest.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {manifest}")


def run_benchmark(models: list[str], cases: list[TestCase], env: dict[str, str]) -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []

    runnable = [c for c in cases if c.audio_path and c.audio_path.exists()]
    if not runnable:
        print(
            "No audio clips found in benchmark/audio/. "
            "Record WAV files named after normalized references or cs_* ids.",
            file=sys.stderr,
        )
        write_test_manifest(cases)
        sys.exit(0)

    for case in runnable:
        for model in models:
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
                    key = env.get("GOOGLE_SPEECH_API_KEY", "")
                    if not key:
                        continue
                    hyp, latency = transcribe_google(key, case.audio_path)
                else:
                    continue

                score = wer(case.reference, hyp)
                exact = normalize(case.reference) == normalize(hyp)
                rows.append(
                    {
                        "id": case.id,
                        "category": case.category,
                        "model": model,
                        "reference": case.reference,
                        "hypothesis": hyp,
                        "wer": round(score, 4),
                        "exact_match": exact,
                        "latency_s": round(latency, 3),
                    }
                )
                print(f"{model:8} {case.id:12} WER={score:.2f} lat={latency:.2f}s")
            except Exception as exc:
                rows.append(
                    {
                        "id": case.id,
                        "category": case.category,
                        "model": model,
                        "reference": case.reference,
                        "hypothesis": "",
                        "wer": 1.0,
                        "exact_match": False,
                        "latency_s": 0,
                        "error": str(exc),
                    }
                )
                print(f"{model:8} {case.id:12} ERROR: {exc}")

    csv_path = RESULTS_DIR / "stt_benchmark.csv"
    md_path = RESULTS_DIR / "results.md"
    if rows:
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)

        summary: dict[str, dict] = {}
        for row in rows:
            model = row["model"]
            summary.setdefault(model, {"wer": [], "latency": [], "exact": 0, "n": 0})
            summary[model]["wer"].append(float(row["wer"]))
            summary[model]["latency"].append(float(row["latency_s"]))
            summary[model]["exact"] += 1 if row.get("exact_match") else 0
            summary[model]["n"] += 1

        lines = ["# STT Benchmark Results\n"]
        for model, stats in summary.items():
            n = stats["n"]
            avg_wer = sum(stats["wer"]) / n if n else 0
            avg_lat = sum(stats["latency"]) / n if n else 0
            lines.append(f"## {model}\n")
            lines.append(f"- Samples: {n}")
            lines.append(f"- Avg WER: {avg_wer:.3f}")
            lines.append(f"- Exact match: {stats['exact']}/{n}")
            lines.append(f"- Avg latency: {avg_lat:.2f}s\n")

        md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"Wrote {csv_path} and {md_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--models",
        default="intron,whisper,google",
        help="Comma-separated: intron,whisper,google",
    )
    parser.add_argument("--names-limit", type=int, default=25)
    parser.add_argument("--manifest-only", action="store_true")
    args = parser.parse_args()

    env = load_env()
    cases = build_test_set(args.names_limit)
    write_test_manifest(cases)

    if args.manifest_only:
        return

    models = [m.strip() for m in args.models.split(",") if m.strip()]
    run_benchmark(models, cases, env)


if __name__ == "__main__":
    main()
