#!/usr/bin/env python3
"""Bootstrap benchmark WAV files via Intron Igbo TTS."""

from __future__ import annotations

import argparse
import audioop
import json
import os
import sys
import time
import unicodedata
import wave
from pathlib import Path

try:
    import requests
except ImportError:
    print("Install requests: pip install requests", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from build_test_set import local_audio_filename
BENCH_DIR = ROOT / "benchmark"
AUDIO_DIR = BENCH_DIR / "audio"
MANIFEST = BENCH_DIR / "test_set.json"
TTS_GENERATE = "https://infer.voice.intron.io/tts/v1/generate"
TTS_ENQUEUE = "https://infer.voice.intron.io/tts/v1/enqueue"
TTS_STATUS = "https://infer.voice.intron.io/tts/v1/status"


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
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if c.isalnum())


def poll_tts(api_key: str, text_id: str, attempts: int = 30) -> str | None:
    headers = {"Authorization": f"Bearer {api_key}"}
    for i in range(attempts):
        time.sleep(1 if i < 3 else 2)
        resp = requests.get(f"{TTS_STATUS}/{text_id}", headers=headers, timeout=30)
        if resp.status_code != 200:
            continue
        data = resp.json().get("data", {})
        status = data.get("processing_status")
        if status == "TTS_TEXT_AUDIO_GENERATED":
            return data.get("audio_path")
        if status == "TTS_TEXT_AUDIO_PROCESSING_FAILED":
            return None
    return None


def enqueue_tts(
    api_key: str,
    text: str,
    language: str,
    accent: str,
    gender: str,
) -> str | None:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "text": text,
        "voice_language": language,
        "voice_accent": accent,
        "voice_gender": gender,
        "output_audio_format": "wav",
    }
    resp = requests.post(TTS_ENQUEUE, headers=headers, json=payload, timeout=60)
    resp.raise_for_status()
    text_id = resp.json().get("data", {}).get("text_id")
    if not text_id:
        return None
    return poll_tts(api_key, text_id)


def tts_generate(
    api_key: str,
    text: str,
    language: str = "ig",
    accent: str = "igbo",
    gender: str = "female",
) -> str | None:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "text": text,
        "voice_language": language,
        "voice_accent": accent,
        "voice_gender": gender,
        "output_audio_format": "wav",
    }
    resp = requests.post(TTS_GENERATE, headers=headers, json=payload, timeout=120)
    if resp.status_code == 503:
        text_id = resp.json().get("data", {}).get("text_id")
        if text_id:
            return poll_tts(api_key, text_id)
        return enqueue_tts(api_key, text, language, accent, gender)
    if resp.status_code != 200:
        print(f"  TTS HTTP {resp.status_code}: {resp.text[:200]}", file=sys.stderr)
        return enqueue_tts(api_key, text, language, accent, gender)
    data = resp.json().get("data", {})
    if data.get("processing_status") == "TTS_TEXT_AUDIO_GENERATED":
        return data.get("audio_path")
    return enqueue_tts(api_key, text, language, accent, gender)


def download_bytes(url: str) -> bytes:
    resp = requests.get(url, headers={"User-Agent": "nketa-benchmark/1.0"}, timeout=120)
    resp.raise_for_status()
    return resp.content


def ensure_16k_mono_wav(src: Path, dest: Path) -> bool:
    """Convert PCM WAV to 16 kHz mono PCM16 (Intron TTS returns 22050 Hz WAV)."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        with wave.open(str(src), "rb") as wf:
            channels = wf.getnchannels()
            rate = wf.getframerate()
            width = wf.getsampwidth()
            frames = wf.readframes(wf.getnframes())
    except wave.Error as exc:
        print(f"  not a WAV file: {src.name} ({exc})", file=sys.stderr)
        return False

    if channels != 1 or width != 2:
        print(f"  unsupported format: {channels}ch {width * 8}-bit", file=sys.stderr)
        return False

    if rate != 16000:
        frames, _ = audioop.ratecv(frames, width, channels, rate, 16000, None)

    with wave.open(str(dest), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(16000)
        out.writeframes(frames)

    if src != dest:
        src.unlink(missing_ok=True)
    return dest.exists()


def save_wav_from_url(url: str, dest: Path) -> bool:
    data = download_bytes(url)
    tmp = dest.with_suffix(".tmp")
    tmp.write_bytes(data)
    ok = ensure_16k_mono_wav(tmp, dest)
    tmp.unlink(missing_ok=True)
    return ok


def dest_for_case(case: dict) -> Path:
    return AUDIO_DIR / local_audio_filename(case["id"])


def source_matches(case: dict, source_filter: str) -> bool:
    src = case.get("source", "")
    if source_filter == "all":
        return src in ("local", "afriswitch_bootstrap")
    if source_filter == "local":
        return src == "local"
    if source_filter == "afriswitch":
        return src in ("afriswitch_bootstrap", "afriswitch")
    return False


def main() -> None:
    parser = argparse.ArgumentParser(description="Bootstrap benchmark WAVs via Intron Igbo TTS")
    parser.add_argument("--force", action="store_true", help="Overwrite existing WAV files")
    parser.add_argument(
        "--source",
        choices=["local", "afriswitch", "all"],
        default="all",
        help="Which test_set entries to synthesize",
    )
    args = parser.parse_args()

    env = load_env()
    api_key = os.environ.get("INTRON_API_KEY") or env.get("INTRON_API_KEY", "")
    if not api_key:
        print("Set INTRON_API_KEY in .env", file=sys.stderr)
        sys.exit(1)

    language = env.get("INTRON_VOICE_LANGUAGE", "ig")
    accent = env.get("INTRON_VOICE_ACCENT", "igbo")
    gender = env.get("INTRON_VOICE_GENDER", "female")

    if not MANIFEST.exists():
        print("Run: python3 scripts/build_test_set.py first", file=sys.stderr)
        sys.exit(1)

    cases = json.loads(MANIFEST.read_text(encoding="utf-8"))
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    created = 0
    skipped = 0
    for case in cases:
        if not source_matches(case, args.source):
            continue

        dest = dest_for_case(case)
        if dest.exists() and not args.force:
            skipped += 1
            continue

        text = case["reference"]
        print(f"Synthesizing {dest.name} for {text[:50]!r}...")
        url = tts_generate(api_key, text, language, accent, gender)
        if not url:
            print(f"  failed: {case['id']}", file=sys.stderr)
            continue

        if save_wav_from_url(url, dest):
            case["audio_path"] = str(dest.relative_to(ROOT))
            case["recording_type"] = "intron_tts_bootstrap"
            created += 1
            time.sleep(0.5)
        else:
            print(f"  save failed: {case['id']}", file=sys.stderr)

    MANIFEST.write_text(json.dumps(cases, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Created/updated {created} WAV files ({skipped} skipped).")
    print("Replace with human/in-the-wild recordings before final submission if possible.")


if __name__ == "__main__":
    main()
