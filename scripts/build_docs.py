#!/usr/bin/env python3
"""Prepare docs_site assets before mkdocs build."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO_SRC = ROOT / "benchmark" / "audio"
AUDIO_DST = ROOT / "docs_site" / "assets" / "audio"
FILES_DST = ROOT / "docs_site" / "files"
CSV_SRC = ROOT / "benchmark" / "results" / "stt_benchmark.csv"
CSV_DST = FILES_DST / "stt_benchmark.csv"


def sync_audio() -> int:
    import json

    AUDIO_DST.mkdir(parents=True, exist_ok=True)
    test_set_path = ROOT / "benchmark" / "test_set.json"
    entries = json.loads(test_set_path.read_text(encoding="utf-8"))
    wav_names = sorted({Path(e["audio_path"]).name for e in entries})

    copied = 0
    missing = []
    for name in wav_names:
        src = AUDIO_SRC / name
        if not src.exists():
            missing.append(name)
            continue
        dst = AUDIO_DST / name
        if not dst.exists() or src.stat().st_mtime > dst.stat().st_mtime:
            shutil.copy2(src, dst)
            copied += 1

    if missing:
        print(f"Missing {len(missing)} WAV files in {AUDIO_SRC}", file=sys.stderr)
        for name in missing[:5]:
            print(f"  - {name}", file=sys.stderr)
        return 1

    print(f"Synced {len(wav_names)} WAV files to {AUDIO_DST} ({copied} updated)")
    return 0


def sync_csv() -> None:
    FILES_DST.mkdir(parents=True, exist_ok=True)
    shutil.copy2(CSV_SRC, CSV_DST)
    print(f"Copied {CSV_SRC.name} to {CSV_DST}")


def run_gallery() -> int:
    script = ROOT / "scripts" / "generate_benchmark_gallery.py"
    result = subprocess.run([sys.executable, str(script)], check=False)
    return result.returncode


def main() -> int:
    code = sync_audio()
    if code:
        return code
    sync_csv()
    return run_gallery()


if __name__ == "__main__":
    raise SystemExit(main())
