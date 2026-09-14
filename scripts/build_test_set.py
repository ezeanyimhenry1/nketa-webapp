#!/usr/bin/env python3
"""Build benchmark/test_set.json manifest."""

from __future__ import annotations

import json
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "data"
BENCH_DIR = ROOT / "benchmark"
AUDIO_DIR = BENCH_DIR / "audio"
MANIFEST = BENCH_DIR / "test_set.json"


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if c.isalnum())


def local_audio_filename(case_id: str) -> str:
    """Predictable names: local_name_1.wav, local_cs_1.wav (vs afriswitch_0000.wav)."""
    if case_id.startswith(("name_", "cs_")):
        return f"local_{case_id}.wav"
    return f"{case_id}.wav"


def legacy_local_audio_filename(case_id: str, reference: str) -> str | None:
    """Previous bootstrap naming before local_* prefix."""
    if case_id.startswith("name_"):
        return f"{normalize(reference)}.wav"
    if case_id.startswith("cs_"):
        return f"{case_id}.wav"
    return None


def migrate_local_audio(cases: list[dict]) -> int:
    """Rename legacy local WAVs to local_{case_id}.wav."""
    renamed = 0
    for case in cases:
        if case.get("source") != "local":
            continue
        cid = case["id"]
        new_path = AUDIO_DIR / local_audio_filename(cid)
        legacy_name = legacy_local_audio_filename(cid, case.get("reference", ""))
        if not legacy_name:
            continue
        old_path = AUDIO_DIR / legacy_name
        if old_path.exists() and not new_path.exists():
            old_path.rename(new_path)
            renamed += 1
        if new_path.exists():
            case["audio_path"] = str(new_path.relative_to(ROOT))
    return renamed


CODE_SWITCHED = [
    ("cs_1", "My name is Chinedu"),
    ("cs_2", "Kedu aha gị"),
    ("cs_3", "Nna m bụ Emeka"),
    ("cs_4", "I am from Enugu"),
    ("cs_5", "Chukwu gozie gị"),
    ("cs_6", "Onye kwe chi ya ekwe"),
    ("cs_7", "Biko kwuo ya ọzọ"),
    ("cs_8", "Nọ n'ụlọ"),
    ("cs_9", "Igbo amaka"),
    ("cs_10", "Ndewo how are you"),
]


def audio_rel(path: Path) -> str | None:
    if path.exists():
        return str(path.relative_to(ROOT))
    return None


def build(names_limit: int = 15) -> list[dict]:
    dictionary = json.loads((DATA_DIR / "dictionary.json").read_text(encoding="utf-8"))
    cases: list[dict] = []

    for item in dictionary[:names_limit]:
        name = item.get("igboWord") or item.get("word") or ""
        if not name:
            continue
        case_id = f"name_{item.get('id', name)}"
        wav = AUDIO_DIR / local_audio_filename(case_id)
        cases.append(
            {
                "id": case_id,
                "reference": name,
                "category": "igbo_name",
                "language_pair": "ig",
                "source": "local",
                "speaker_id": "speaker_a",
                "dialect": "Enugu",
                "noise": "quiet",
                "consent": True,
                "recording_type": "intron_tts_bootstrap",
                "audio_path": audio_rel(wav),
            }
        )

    for cid, reference in CODE_SWITCHED:
        wav = AUDIO_DIR / local_audio_filename(cid)
        cases.append(
            {
                "id": cid,
                "reference": reference,
                "category": "code_switched",
                "language_pair": "ig-en",
                "source": "local",
                "speaker_id": "speaker_a",
                "dialect": "Enugu",
                "noise": "quiet",
                "consent": True,
                "recording_type": "intron_tts_bootstrap",
                "audio_path": audio_rel(wav),
            }
        )

    return cases


def merge_afriswitch(existing: list[dict], afriswitch: list[dict]) -> list[dict]:
    local_ids = {c["id"] for c in existing}
    merged = list(existing)
    for entry in afriswitch:
        if entry["id"] not in local_ids:
            merged.append(entry)
    return merged


def main() -> None:
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    cases = build()

    afriswitch_meta = BENCH_DIR / "afriswitch_entries.json"
    if afriswitch_meta.exists():
        extra = json.loads(afriswitch_meta.read_text(encoding="utf-8"))
        cases = merge_afriswitch(cases, extra)
        for entry in cases:
            if entry.get("source") == "afriswitch":
                p = ROOT / entry["audio_path"] if entry.get("audio_path") else None
                if p and not p.exists():
                    entry["audio_path"] = None

    n = migrate_local_audio(cases)
    if n:
        print(f"Renamed {n} legacy local WAV(s) to local_* naming")

    MANIFEST.write_text(json.dumps(cases, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {MANIFEST} ({len(cases)} cases)")


if __name__ == "__main__":
    main()
