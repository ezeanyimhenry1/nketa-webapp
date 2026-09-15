# Reproduce the benchmark

## Test set

50 clips:

- 15 Igbo names (`local_name_*.wav`, Intron TTS bootstrap)
- 10 code-switched phrases (`local_cs_*.wav`, Intron TTS bootstrap)
- 25 AfriSwitch in-the-wild clips (`afriswitch_*.wav`, human speech, CC BY-NC-SA 4.0)

Manifest: `benchmark/test_set.json` in the repository.

## Setup

```bash
pip3 install -r requirements-benchmark.txt
python3 scripts/build_test_set.py
```

For AfriSwitch clips and Sunbird, accept terms on Hugging Face and set `HF_TOKEN` in `.env`:

- [huggingface.co/datasets/intronhealth/AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch)
- Sunbird African faster-whisper (gated model)

```bash
python3 scripts/fetch_afriswitch_samples.py --limit 25 --no-bootstrap
python3 scripts/build_test_set.py
python3 scripts/bootstrap_local_audio.py --force --source all
```

## Run four models

```bash
python3 scripts/benchmark_stt.py --models intron --merge
python3 scripts/benchmark_stt.py --models faster_whisper --faster-whisper-model base --merge
python3 scripts/benchmark_stt.py --models faster_whisper_small --merge
python3 scripts/benchmark_stt.py --models sunbird_whisper --merge
```

Outputs: `benchmark/results/stt_benchmark.csv` and `benchmark/results/BENCHMARK_REPORT.md`.

## Models compared

| Model ID | Description |
|----------|-------------|
| `intron` | Intron Sahara (production STT, explicit Igbo) |
| `faster_whisper` | Open-source Whisper base (local, auto language) |
| `faster_whisper_small` | Open-source Whisper tiny (local, auto language) |
| `sunbird_whisper` | Sunbird African fine-tune (Igbo via `sa` token; gated HF model) |

Optional baselines (not in our final CSV): OpenAI Whisper API, Google STT.

## API keys (.env)

```
INTRON_API_KEY=...
HF_TOKEN=...              # AfriSwitch download + Sunbird model
OPENAI_API_KEY=...        # optional Whisper API
GOOGLE_SPEECH_API_KEY=... # optional Google STT
```

Do not commit `.env` to version control.
