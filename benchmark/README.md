# Nketa STT Benchmark — Sahara CodeSwitch Challenge

Benchmark Igbo speech recognition for the hackathon submission.

Local bootstrap WAVs are **not** stored in git — regenerate with `bootstrap_local_audio.py`. AfriSwitch clips (`afriswitch_*.wav`) are committed.

**Audio naming:** `local_name_1.wav`, `local_cs_1.wav` = Intron TTS bootstrap; `afriswitch_0000.wav` = in-the-wild AfriSwitch human speech.

## Quick start

```bash
pip3 install -r requirements-benchmark.txt

python3 scripts/build_test_set.py

# AfriSwitch (~25 clips): accept terms at huggingface.co/datasets/intronhealth/AfriSwitch, add HF_TOKEN to .env
python3 scripts/fetch_afriswitch_samples.py --limit 25 --no-bootstrap
python3 scripts/build_test_set.py

python3 scripts/bootstrap_local_audio.py --force --source all
```

## Run benchmark (3+ models)

Intron results can be merged with baselines via `--merge`:

```bash
# Primary (Sahara) — already run if stt_benchmark.csv has intron rows
python3 scripts/benchmark_stt.py --models intron --merge

# Open-source local baselines (no API calls)
python3 scripts/benchmark_stt.py --models faster_whisper --faster-whisper-model base --merge
python3 scripts/benchmark_stt.py --models faster_whisper_small --merge   # uses tiny checkpoint

# Optional (may fail without access / quota)
python3 scripts/benchmark_stt.py --models sunbird_whisper --merge   # gated HF model
python3 scripts/benchmark_stt.py --models whisper --merge             # OpenAI API
```

Smoke test (first 3 clips):

```bash
python3 scripts/benchmark_stt.py --models faster_whisper --limit 3 --merge
```

Optional Google STT (when key available):

```bash
python3 scripts/benchmark_stt.py --models google --merge
```

## Outputs

| File | Purpose |
|------|---------|
| `test_set.json` | Test manifest with metadata |
| `results/stt_benchmark.csv` | Per-clip results |
| `results/BENCHMARK_REPORT.md` | Submission benchmark report |

## API keys (.env)

```
INTRON_API_KEY=...
HF_TOKEN=...              # AfriSwitch download
OPENAI_API_KEY=...        # Whisper API baseline
GOOGLE_SPEECH_API_KEY=... # optional Google baseline
```

## Models

| Model ID | Description |
|----------|-------------|
| `intron` | Intron Sahara (production STT, explicit Igbo) |
| `faster_whisper` | Open-source Whisper base (local, auto language) |
| `faster_whisper_small` | Open-source Whisper tiny (local, auto language) |
| `sunbird_whisper` | Sunbird African fine-tune (Igbo via `sa` token; gated) |
| `whisper` | OpenAI Whisper-1 API (auto language) |
| `google` | Google Speech-to-Text (`ig-NG` + `en-NG`) |

## Datasets

- **Local:** Nketa Igbo names + code-switched phrases ([`RECORDING_GUIDE.md`](RECORDING_GUIDE.md))
- **AfriSwitch:** [intronhealth/AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) Igbo config (CC BY-NC-SA 4.0)

Results are reported by category and source (Igbo names, code-switched, AfriSwitch).
