#!/usr/bin/env python3
"""Pre-generate Intron TTS audio for JSON content and write asset paths."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen

try:
    import requests
except ImportError:
    print("Install requests: pip install requests", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "data"
AUDIO_DIR = ROOT / "assets" / "audio"
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


def stable_id(prefix: str, text: str) -> str:
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]
    return f"{prefix}_{digest}"


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
        "output_audio_format": "opus",
    }

    resp = requests.post(TTS_GENERATE, headers=headers, json=payload, timeout=120)
    if resp.status_code == 503:
        body = resp.json()
        text_id = body.get("data", {}).get("text_id")
        if text_id:
            return poll_tts(api_key, text_id)
        return None

    resp.raise_for_status()
    body = resp.json()
    data = body.get("data", {})
    if data.get("processing_status") == "TTS_TEXT_AUDIO_GENERATED":
        return data.get("audio_path")
    return None


def enqueue_tts(api_key: str, text: str, language: str, accent: str, gender: str) -> str | None:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "text": text,
        "voice_language": language,
        "voice_accent": accent,
        "voice_gender": gender,
        "output_audio_format": "opus",
    }
    resp = requests.post(TTS_ENQUEUE, headers=headers, json=payload, timeout=60)
    resp.raise_for_status()
    text_id = resp.json().get("data", {}).get("text_id")
    if not text_id:
        return None
    return poll_tts(api_key, text_id)


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


def download_audio(url: str, dest: Path) -> None:
    req = Request(url, headers={"User-Agent": "nketa-audio-generator/1.0"})
    with urlopen(req, timeout=120) as resp:
        dest.write_bytes(resp.read())


def synthesize_to_asset(
    api_key: str,
    prefix: str,
    text: str,
    language: str,
    accent: str,
    gender: str,
    force: bool,
) -> str | None:
    if not text.strip():
        return None

    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    file_id = stable_id(prefix, text)
    dest = AUDIO_DIR / f"{file_id}.opus"
    asset_ref = f"asset://audio/{file_id}.opus"

    if dest.exists() and not force:
        return asset_ref

    audio_url = tts_generate(api_key, text, language, accent, gender)
    if not audio_url:
        audio_url = enqueue_tts(api_key, text, language, accent, gender)
    if not audio_url:
        print(f"  failed: {text[:40]!r}")
        return None

    download_audio(audio_url, dest)
    print(f"  saved {dest.name} for {text[:40]!r}")
    return asset_ref


def process_cosmology(api_key: str, language: str, accent: str, gender: str, force: bool) -> None:
    path = DATA_DIR / "igbo_cosmology.json"
    items = json.loads(path.read_text(encoding="utf-8"))
    for item in items:
        audio = synthesize_to_asset(
            api_key, "cosmo", item.get("name", ""), language, accent, gender, force
        )
        if audio:
            item["audio"] = audio
    path.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def process_proverbs(api_key: str, language: str, accent: str, gender: str, force: bool) -> None:
    path = DATA_DIR / "proverbs.json"
    items = json.loads(path.read_text(encoding="utf-8"))
    for item in items:
        audio = synthesize_to_asset(
            api_key, "proverb", item.get("igbo", ""), language, accent, gender, force
        )
        if audio:
            item["audio"] = audio
    path.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def process_stories(api_key: str, language: str, accent: str, gender: str, force: bool) -> None:
    path = DATA_DIR / "stories.json"
    items = json.loads(path.read_text(encoding="utf-8"))
    for item in items:
        text = item.get("title") or item.get("excerpt") or ""
        audio = synthesize_to_asset(
            api_key, "story", text, language, accent, gender, force
        )
        if audio:
            item["audio"] = audio
    path.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def process_dictionary(api_key: str, language: str, accent: str, gender: str, force: bool, limit: int) -> None:
    path = DATA_DIR / "dictionary.json"
    items = json.loads(path.read_text(encoding="utf-8"))
    for item in items[:limit]:
        text = item.get("igboWord") or item.get("word") or ""
        audio = synthesize_to_asset(
            api_key, "name", text, language, accent, gender, force
        )
        if audio:
            item["pronunciation"] = audio
    path.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Intron TTS audio for JSON content")
    parser.add_argument("--cosmology", action="store_true")
    parser.add_argument("--proverbs", action="store_true")
    parser.add_argument("--stories", action="store_true")
    parser.add_argument("--dictionary", action="store_true")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--force", action="store_true", help="Regenerate even if file exists")
    parser.add_argument("--dictionary-limit", type=int, default=20)
    args = parser.parse_args()

    env = load_env()
    api_key = os.environ.get("INTRON_API_KEY") or env.get("INTRON_API_KEY", "")
    if not api_key:
        print("Set INTRON_API_KEY in .env or environment", file=sys.stderr)
        sys.exit(1)

    language = env.get("INTRON_VOICE_LANGUAGE", "ig")
    accent = env.get("INTRON_VOICE_ACCENT", "igbo")
    gender = env.get("INTRON_VOICE_GENDER", "female")

    run_all = args.all or not any(
        [args.cosmology, args.proverbs, args.stories, args.dictionary]
    )

    if run_all or args.cosmology:
        print("Cosmology...")
        process_cosmology(api_key, language, accent, gender, args.force)
    if run_all or args.proverbs:
        print("Proverbs...")
        process_proverbs(api_key, language, accent, gender, args.force)
    if run_all or args.stories:
        print("Stories...")
        process_stories(api_key, language, accent, gender, args.force)
    if run_all or args.dictionary:
        print(f"Dictionary (limit {args.dictionary_limit})...")
        process_dictionary(
            api_key, language, accent, gender, args.force, args.dictionary_limit
        )

    print("Done. Add assets/audio/ to pubspec.yaml if not already listed.")


if __name__ == "__main__":
    main()
