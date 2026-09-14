#!/usr/bin/env python3
"""Fetch Igbo code-switched clips from Intron AfriSwitch on Hugging Face."""

from __future__ import annotations

import os

# hf-xet downloads can hang indefinitely on some macOS setups; use HTTP instead.
os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
os.environ.setdefault("HF_HUB_DOWNLOAD_TIMEOUT", "300")

import argparse
import json
import re
import sys
import wave
from io import BytesIO
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH_DIR = ROOT / "benchmark"
AUDIO_DIR = BENCH_DIR / "audio"
AFRISWITCH_META = BENCH_DIR / "afriswitch_entries.json"
ENV_PATH = ROOT / ".env"

DATASET_ID = "intronhealth/AfriSwitch"
DATASET_CONFIG = "igbo"
LICENSE = "CC BY-NC-SA 4.0"
SOURCE_URL = "https://huggingface.co/datasets/intronhealth/AfriSwitch"

BOOTSTRAP_PHRASES = [
    "My name is Chinedu and I am from Enugu",
    "Kedu aha gị please tell me",
    "Nna m bụ doctor in Lagos",
    "Chukwu gozie gị thank you so much",
    "I want to learn Igbo language",
    "Biko help me with this translation",
    "Onye kwe chi ya ekwe as they say",
    "Igbo amaka and our culture is rich",
    "Ndewo how are you today",
    "I am going to the market now",
    "Ebee ka ị nọ where are you",
    "Gịnị ka ị na-eme what are you doing",
    "Nọ n'ụlọ stay at home please",
    "Ka anyị gaa let us go together",
    "Ọ dị mma that is good news",
    "I na-asụ Igbo very well",
    "My mother is from Anambra state",
    "We need to preserve our language",
    "Speak Igbo with your children",
    "This app helps me write Nsibidi",
    "Emeka is my brother and friend",
    "I love Igbo proverbs and stories",
    "Please repeat that one more time",
    "The meeting starts at three pm",
    "Thank you for teaching me Igbo",
]


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    if not ENV_PATH.exists():
        return values
    for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        values[key.strip()] = val.strip().strip('"').strip("'")
    return values


def hf_token() -> str | None:
    env = load_env()
    return env.get("HF_TOKEN") or env.get("HUGGINGFACE_TOKEN") or os.environ.get("HF_TOKEN")


def strip_en_tags(text: str) -> str:
    return re.sub(r"\[\[EN\]\]|\[\[/EN\]\]", "", text).strip()


def write_wav(path: Path, pcm_bytes: bytes, sample_rate: int = 16000) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_bytes)


def save_audio_array(path: Path, array, sampling_rate: int) -> None:
    import numpy as np

    audio = np.asarray(array, dtype=np.float32)
    if audio.ndim > 1:
        audio = audio.mean(axis=0)
    pcm = (np.clip(audio, -1.0, 1.0) * 32767).astype(np.int16)
    write_wav(path, pcm.tobytes(), sampling_rate)


def fetch_from_parquet(limit: int, seed: int, token: str) -> list[dict]:
    """Download parquet shards one at a time until *limit* clips are saved."""
    import random

    import pyarrow.parquet as pq
    from huggingface_hub import hf_hub_download

    parquet_files = [
        f"data/{DATASET_CONFIG}/test-{i:05d}-of-00004.parquet" for i in range(4)
    ]
    random.seed(seed)
    random.shuffle(parquet_files)

    entries: list[dict] = []
    for rel in parquet_files:
        if len(entries) >= limit:
            break

        print(f"  downloading {rel}...")
        local = hf_hub_download(
            DATASET_ID,
            rel,
            repo_type="dataset",
            token=token,
        )
        rows = pq.read_table(local).to_pylist()
        random.shuffle(rows)

        for row in rows:
            if len(entries) >= limit:
                break

            entry_id = f"afriswitch_{len(entries):04d}"
            wav_path = AUDIO_DIR / f"{entry_id}.wav"
            entry = _row_to_entry(row, entry_id, wav_path)
            if entry is None:
                continue

            entries.append(entry)
            print(f"  saved {entry_id} {entry['reference'][:50]!r}...")

    if len(entries) < limit:
        raise RuntimeError(
            f"Only collected {len(entries)} clips from parquet shards (wanted {limit})"
        )

    return entries


def _reference_from_row(row: dict) -> str:
    reference = row.get("transcription") or ""
    if not reference.strip():
        reference = strip_en_tags(row.get("transcription_tagged") or "")
    return reference.strip()


def _metadata_entry(row: dict, entry_id: str, wav_path: Path) -> dict | None:
    reference = _reference_from_row(row)
    if not reference:
        return None
    return {
        "id": entry_id,
        "reference": reference,
        "category": "afriswitch",
        "language_pair": "ig-en",
        "source": "afriswitch",
        "speaker_id": "unknown",
        "dialect": "Igbo (in-the-wild)",
        "noise": "in-the-wild",
        "consent": True,
        "recording_type": "human",
        "dataset": DATASET_ID,
        "dataset_config": DATASET_CONFIG,
        "license": LICENSE,
        "source_url": SOURCE_URL,
        "duration_s": row.get("duration"),
        "cmi": row.get("cmi"),
        "num_switch_points": row.get("num_switch_points"),
        "audio_path": str(wav_path.relative_to(ROOT)),
    }


def _request_json(url: str, *, params: dict, headers: dict, timeout: int = 60) -> dict:
    import time

    import requests

    last_exc: Exception | None = None
    for attempt in range(5):
        try:
            resp = requests.get(url, params=params, headers=headers, timeout=timeout)
            resp.raise_for_status()
            payload = resp.json()
            if payload.get("error"):
                raise RuntimeError(payload["error"])
            return payload
        except Exception as exc:
            last_exc = exc
            if attempt == 4:
                break
            time.sleep(2**attempt)
    raise last_exc  # type: ignore[misc]


def fetch_from_datasets_server(limit: int, seed: int, token: str) -> list[dict]:
    """Fetch clips via HF datasets-server (small per-row downloads, no parquet shards)."""
    import random

    import requests

    headers = {"Authorization": f"Bearer {token}"}
    base_params = {
        "dataset": DATASET_ID,
        "config": DATASET_CONFIG,
        "split": "test",
    }
    rows_url = "https://datasets-server.huggingface.co/rows"
    page_size = 100

    probe = _request_json(
        rows_url, params={**base_params, "offset": 0, "length": 1}, headers=headers
    )
    total = int(probe.get("num_rows_total") or 0)
    if total <= 0:
        raise RuntimeError("datasets-server returned no rows")

    random.seed(seed)
    page_starts = list(range(0, total, page_size))
    random.shuffle(page_starts)

    entries: list[dict] = []
    for page_start in page_starts:
        if len(entries) >= limit:
            break

        payload = _request_json(
            rows_url,
            params={**base_params, "offset": page_start, "length": page_size},
            headers=headers,
        )
        page_rows = payload.get("rows") or []
        random.shuffle(page_rows)

        for item in page_rows:
            if len(entries) >= limit:
                break

            row = item["row"]
            entry_id = f"afriswitch_{len(entries):04d}"
            wav_path = AUDIO_DIR / f"{entry_id}.wav"
            entry = _metadata_entry(row, entry_id, wav_path)
            if entry is None:
                continue

            audio = row.get("audio") or []
            src = audio[0].get("src") if audio else None
            if not src:
                continue

            audio_resp = requests.get(src, timeout=120)
            audio_resp.raise_for_status()
            wav_path.parent.mkdir(parents=True, exist_ok=True)
            wav_path.write_bytes(audio_resp.content)

            entries.append(entry)
            print(
                f"  saved {entry_id} ({row.get('duration')}s) "
                f"{entry['reference'][:50]!r}..."
            )

    if len(entries) < limit:
        raise RuntimeError(
            f"Only collected {len(entries)} clips from datasets-server (wanted {limit})"
        )

    return entries


def _row_to_entry(row: dict, entry_id: str, wav_path: Path) -> dict | None:
    audio = row.get("audio")
    if audio is None:
        return None

    reference = _reference_from_row(row)
    if not reference:
        return None

    array = audio.get("array")
    sr = int(audio.get("sampling_rate") or 16000)
    if array is None:
        return None

    save_audio_array(wav_path, array, sr)
    return _metadata_entry(row, entry_id, wav_path)


def fetch_from_datasets_streaming(limit: int, seed: int, token: str) -> list[dict]:
    from datasets import load_dataset

    ds = load_dataset(
        DATASET_ID, DATASET_CONFIG, split="test", streaming=True, token=token
    )
    ds = ds.shuffle(seed=seed, buffer_size=1000)

    entries: list[dict] = []
    for row in ds:
        if len(entries) >= limit:
            break

        entry_id = f"afriswitch_{len(entries):04d}"
        wav_path = AUDIO_DIR / f"{entry_id}.wav"
        entry = _row_to_entry(row, entry_id, wav_path)
        if entry is None:
            continue

        entries.append(entry)
        print(
            f"  saved {entry_id} ({row.get('duration')}s) "
            f"{entry['reference'][:50]!r}..."
        )

    return entries


def fetch_from_datasets(limit: int, seed: int, token: str) -> list[dict]:
    from datasets import load_dataset

    ds = load_dataset(DATASET_ID, DATASET_CONFIG, split="test", token=token)
    ds = ds.shuffle(seed=seed)

    entries: list[dict] = []
    for row in ds:
        if len(entries) >= limit:
            break

        entry_id = f"afriswitch_{len(entries):04d}"
        wav_path = AUDIO_DIR / f"{entry_id}.wav"
        entry = _row_to_entry(row, entry_id, wav_path)
        if entry is None:
            continue

        entries.append(entry)
        print(
            f"  saved {entry_id} ({row.get('duration')}s) "
            f"{entry['reference'][:50]!r}..."
        )

    return entries


def bootstrap_macos(limit: int) -> list[dict]:
    """Generate placeholder clips when HF access is unavailable."""
    import subprocess
    import unicodedata

    def normalize(text: str) -> str:
        text = unicodedata.normalize("NFKD", text.lower())
        return "".join(c for c in text if c.isalnum())

    entries: list[dict] = []
    for i, reference in enumerate(BOOTSTRAP_PHRASES[:limit]):
        entry_id = f"afriswitch_{i:04d}"
        wav_path = AUDIO_DIR / f"{entry_id}.wav"
        tmp = wav_path.with_suffix(".aiff")
        subprocess.run(["say", "-o", str(tmp), reference], check=True)
        subprocess.run(
            ["afconvert", "-f", "WAVE", "-d", "LEI16@16000", str(tmp), str(wav_path)],
            check=True,
        )
        tmp.unlink(missing_ok=True)

        entries.append(
            {
                "id": entry_id,
                "reference": reference,
                "category": "afriswitch",
                "language_pair": "ig-en",
                "source": "afriswitch_bootstrap",
                "speaker_id": "bootstrap",
                "dialect": "Enugu (synthetic)",
                "noise": "quiet",
                "consent": True,
                "recording_type": "macos_say_bootstrap",
                "dataset": DATASET_ID,
                "dataset_config": DATASET_CONFIG,
                "license": LICENSE,
                "source_url": SOURCE_URL,
                "audio_path": str(wav_path.relative_to(ROOT)),
            }
        )
        print(f"  bootstrap {entry_id} {reference[:50]!r}...")

    return entries


def fetch(limit: int, seed: int, force_bootstrap: bool, allow_bootstrap: bool) -> list[dict]:
    if force_bootstrap:
        print("Using macOS say bootstrap (no HF download).")
        return bootstrap_macos(limit)

    token = hf_token()
    if not token:
        msg = (
            "No HF_TOKEN in .env — AfriSwitch is gated on Hugging Face.\n"
            "  1. Accept terms at https://huggingface.co/datasets/intronhealth/AfriSwitch\n"
            "  2. Add HF_TOKEN=hf_... to .env\n"
            "  3. Re-run this script"
        )
        if allow_bootstrap:
            print(msg + "\nFalling back to bootstrap clips.", file=sys.stderr)
            return bootstrap_macos(limit)
        raise SystemExit(msg)

    errors: list[str] = []
    for label, fn in (
        ("datasets-server", fetch_from_datasets_server),
        ("parquet", fetch_from_parquet),
        ("streaming", fetch_from_datasets_streaming),
        ("datasets", fetch_from_datasets),
    ):
        try:
            return fn(limit, seed, token)
        except Exception as exc:
            print(f"{label} fetch failed ({exc})", file=sys.stderr)
            errors.append(f"{label}: {exc}")

    msg = "All Hugging Face download methods failed:\n  " + "\n  ".join(errors)
    if allow_bootstrap:
        print(msg + "\nUsing bootstrap.", file=sys.stderr)
        return bootstrap_macos(limit)
    raise SystemExit(msg)


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch AfriSwitch Igbo samples")
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--bootstrap",
        action="store_true",
        help="Skip HF download; generate interim macOS say clips",
    )
    parser.add_argument(
        "--no-bootstrap",
        action="store_true",
        help="Fail instead of falling back to macOS say clips when HF download fails",
    )
    args = parser.parse_args()

    print(f"Fetching up to {args.limit} clips from {DATASET_ID} ({DATASET_CONFIG})...")
    entries = fetch(
        args.limit,
        args.seed,
        args.bootstrap,
        allow_bootstrap=not args.no_bootstrap,
    )
    AFRISWITCH_META.write_text(
        json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"Wrote {len(entries)} entries to {AFRISWITCH_META}")
    print("Run: python3 scripts/build_test_set.py")


if __name__ == "__main__":
    main()
