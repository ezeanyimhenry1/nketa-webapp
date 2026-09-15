#!/usr/bin/env python3
"""Generate docs_site/benchmark-samples.md from benchmark CSV and test set."""

from __future__ import annotations

import csv
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "benchmark" / "results" / "stt_benchmark.csv"
TEST_SET_PATH = ROOT / "benchmark" / "test_set.json"
OUTPUT_PATH = ROOT / "docs_site" / "benchmark-samples.md"

MODEL_ORDER = ("intron", "sunbird_whisper", "faster_whisper", "faster_whisper_small")
MODEL_LABELS = {
    "intron": "Intron Sahara",
    "sunbird_whisper": "Sunbird African",
    "faster_whisper": "faster-whisper base",
    "faster_whisper_small": "faster-whisper tiny",
}

CATEGORY_SECTIONS = (
    ("igbo_name", "Igbo names", "igbo_name"),
    ("code_switched", "Code-switched phrases", "code_switched"),
    ("afriswitch", "AfriSwitch in-the-wild", "afriswitch"),
)


def load_test_set() -> dict[str, dict]:
    entries = json.loads(TEST_SET_PATH.read_text(encoding="utf-8"))
    return {e["id"]: e for e in entries}


def audio_filename(entry: dict) -> str:
    path = entry.get("audio_path", "")
    return Path(path).name


def escape_html(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    text = re.sub(r"\s+", " ", text)
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def format_bool(value: str) -> str:
    return "yes" if str(value).lower() in ("true", "1", "yes") else "no"


def load_csv_rows() -> dict[str, list[dict]]:
    by_id: dict[str, list[dict]] = defaultdict(list)
    with CSV_PATH.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            by_id[row["id"]].append(row)
    return by_id


def clip_block(clip_id: str, meta: dict, rows: list[dict]) -> str:
    rows_by_model = {r["model"]: r for r in rows}
    ref = meta.get("reference") or rows[0].get("reference", "")
    filename = audio_filename(meta)
    category = meta.get("category", rows[0].get("category", ""))
    source = meta.get("source", rows[0].get("source", ""))
    recording_type = meta.get("recording_type", rows[0].get("recording_type", ""))

    lines = [
        f'<details id="{clip_id}">',
        f"<summary><strong>{clip_id}</strong> - {escape_html(ref)}</summary>",
        "",
        f"- **Category:** {category}",
        f"- **Source:** {source}",
        f"- **Recording:** {recording_type}",
        f"- **Reference:** {escape_html(ref)}",
        "",
        f'<audio controls src="/assets/audio/{filename}"></audio>',
        "",
        "<table>",
        "<thead><tr><th>Model</th><th>Hypothesis</th><th>WER</th><th>Exact match</th><th>Latency (s)</th></tr></thead>",
        "<tbody>",
    ]

    for model in MODEL_ORDER:
        row = rows_by_model.get(model)
        if not row:
            continue
        label = MODEL_LABELS.get(model, model)
        hypothesis = escape_html(row.get("hypothesis") or row.get("error") or "(empty)")
        wer = row.get("wer", "")
        exact = format_bool(row.get("exact_match", ""))
        latency = row.get("latency_s", "")
        try:
            wer_str = f"{float(wer):.3f}"
        except (TypeError, ValueError):
            wer_str = wer
        try:
            lat_str = f"{float(latency):.2f}"
        except (TypeError, ValueError):
            lat_str = latency
        lines.append(
            f"<tr><td>{label}</td><td>{hypothesis}</td><td>{wer_str}</td>"
            f"<td>{exact}</td><td>{lat_str}</td></tr>"
        )

    lines.extend(["</tbody>", "</table>", "", "</details>", ""])
    return "\n".join(lines)


def generate() -> None:
    test_set = load_test_set()
    by_id = load_csv_rows()

    lines = [
        "# Sample clips",
        "",
        "Each clip has one input recording and four STT transcripts (Intron Sahara, Sunbird African, faster-whisper base, faster-whisper tiny).",
        "",
        "Jump to:",
        "- [Igbo names](#igbo_name)",
        "- [Code-switched phrases](#code_switched)",
        "- [AfriSwitch in-the-wild](#afriswitch)",
        "",
    ]

    for category, title, anchor in CATEGORY_SECTIONS:
        clip_ids = [cid for cid, meta in test_set.items() if meta.get("category") == category]
        clip_ids.sort(key=lambda cid: (test_set[cid].get("source", ""), cid))
        if not clip_ids:
            continue
        lines.extend([f"## {title} {{#{anchor}}}", ""])
        for clip_id in clip_ids:
            meta = test_set[clip_id]
            rows = by_id.get(clip_id, [])
            if not rows:
                continue
            lines.append(clip_block(clip_id, meta, rows))

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} ({len(by_id)} clips)")


if __name__ == "__main__":
    generate()
