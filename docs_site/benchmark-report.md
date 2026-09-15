# STT Benchmark Report

**Nketa / Sahara CodeSwitch Challenge**

Download full results: [stt_benchmark.csv](files/stt_benchmark.csv)

Listen to clips and compare transcripts on the [Sample clips](benchmark-samples.md) page.

## Methodology

- **Primary model:** Intron Sahara (`use_language_asr_input=ig`) - production STT in Nketa
- **Baselines:** faster-whisper base and tiny (local, auto language); Sunbird African faster-whisper (Igbo via `sa` token)
- **Language handling:** Intron uses explicit Igbo; standard Whisper has no Igbo language code; Sunbird maps Igbo via language token `sa`
- **Datasets:** Local Nketa clips (Igbo names + code-switched phrases) plus [Intron AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) Igbo subset (CC BY-NC-SA 4.0)
- **Metrics:** WER, CER (diacritic-sensitive), exact match, latency, name lookup success (can Nketa find the name from the transcript?)
- **Reporting:** Results split by category and source

## Overall results

| Model | N | Avg WER | Avg CER | Exact match | Name lookup | Avg latency (s) |
|-------|--:|--------:|--------:|------------:|------------:|----------------:|
| intron | 50 | 0.740 | 0.295 | 13/50 | 14/50 | 14.81 |
| sunbird_whisper | 50 | 0.900 | 1.244 | 5/50 | 8/50 | 11.41 |
| faster_whisper | 50 | 0.940 | 0.537 | 3/50 | 3/50 | 1.82 |
| faster_whisper_small | 50 | 0.980 | 0.672 | 1/50 | 0/50 | 1.38 |

## By category

| Model | Category | N | Avg WER | Avg CER | Exact match |
|-------|----------|--:|--------:|--------:|------------:|
| intron | igbo_name | 15 | 0.400 | 0.141 | 9/15 |
| intron | code_switched | 10 | 0.800 | 0.334 | 2/10 |
| intron | afriswitch | 25 | 0.920 | 0.372 | 2/25 |
| sunbird_whisper | igbo_name | 15 | 0.933 | 3.334 | 1/15 |
| sunbird_whisper | code_switched | 10 | 0.600 | 0.222 | 4/10 |
| sunbird_whisper | afriswitch | 25 | 1.000 | 0.398 | 0/25 |
| faster_whisper | igbo_name | 15 | 0.933 | 0.585 | 1/15 |
| faster_whisper | code_switched | 10 | 0.800 | 0.392 | 2/10 |
| faster_whisper | afriswitch | 25 | 1.000 | 0.567 | 0/25 |
| faster_whisper_small | igbo_name | 15 | 1.000 | 0.812 | 0/15 |
| faster_whisper_small | code_switched | 10 | 0.900 | 0.532 | 1/10 |
| faster_whisper_small | afriswitch | 25 | 1.000 | 0.643 | 0/25 |

## By source

| Model | Source | N | Avg WER | Avg CER |
|-------|--------|--:|--------:|--------:|
| intron | local | 25 | 0.560 | 0.218 |
| intron | afriswitch | 25 | 0.920 | 0.372 |
| sunbird_whisper | local | 25 | 0.800 | 2.089 |
| sunbird_whisper | afriswitch | 25 | 1.000 | 0.398 |
| faster_whisper | local | 25 | 0.880 | 0.507 |
| faster_whisper | afriswitch | 25 | 1.000 | 0.567 |
| faster_whisper_small | local | 25 | 0.960 | 0.700 |
| faster_whisper_small | afriswitch | 25 | 1.000 | 0.643 |

## Model notes

### Intron Sahara

- **Pros:** Built for African Igbo-English code-switching; powers speak-to-Nsibidi in production. Best overall WER (0.740) and name lookup (14/50).
- **Cons:** API dependency; short clips need padding before the API accepts them.

### Sunbird African faster-whisper

- **Pros:** Fine-tuned for 51 African languages; best code-switched WER (0.600 vs 0.800 for Intron); second-best name lookup (8/50).
- **Cons:** High CER (1.244) on diacritics; 0/25 exact match on AfriSwitch in-the-wild clips; large model download.

### faster-whisper base (local)

- **Pros:** Open-source, no API rate limits, fast inference (~1.8s per clip).
- **Cons:** No Igbo language token; weak on diacritics and AfriSwitch clips (0/25 exact match).

### faster-whisper tiny (local)

- **Pros:** Fastest local baseline (~1.4s per clip).
- **Cons:** Lowest accuracy; no successful name lookups on this test set.

## What this means for Nketa

- **Production STT:** Intron Sahara for speak-to-Nsibidi and proverb practice.
- **Fallback:** User can edit the heard transcript before lookup; typed search still works offline for dictionary names.
- **TTS:** Intron Igbo voice with on-device cache.

## Interpretation

### Why name lookup matters

WER alone does not capture whether an app can act on speech. Nketa's speak-to-Nsibidi flow needs the dictionary to find the Igbo name inside a code-switched phrase like `"My name is Chinedu"`. Name lookup success (14/50 for Intron) is the metric closest to real user outcomes.

### Category stories

| Category | Best WER | Story |
|----------|----------|-------|
| Igbo names (local) | Intron 0.400 | Intron gets 9/15 exact match; baselines struggle with TTS bootstrap names |
| Code-switched (local) | Sunbird 0.600 | Sunbird beats Intron (0.800) on mixed phrases, but Intron still wins name lookup overall |
| AfriSwitch in-the-wild | All struggle | 0-2 exact match per model; in-the-wild human speech is hardest |

### Example clips to listen

| Clip | Link | What to notice |
|------|------|----------------|
| `name_1` (Chinedu) | [Sample clips](benchmark-samples.md#name_1) | Intron exact match; Whisper mishears as unrelated words |
| `cs_6` (Onye kwe chi ya ekwe) | [Sample clips](benchmark-samples.md#cs_6) | Proverb-like code-switch; compare Intron vs Sunbird |
| `afriswitch_0000` | [Sample clips](benchmark-samples.md#afriswitch_0000) | In-the-wild human speech; all models show high WER |

### Production choice

Intron Sahara has higher latency (~14.8s vs ~1.4-11.4s for local models) but wins on name lookup and diacritic-sensitive CER (0.295 vs 0.537+). For Nketa, a correct Nsibidi lookup matters more than raw speed. Sunbird is a strong second baseline for code-switched WER but weak on AfriSwitch and diacritics (CER 1.244).

## Limitations

- AfriSwitch clips are in-the-wild human speech from [intronhealth/AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) (Igbo config).
- Local clips use **Intron Igbo TTS** (`intron_tts_bootstrap`). Human recordings would improve realism.
- Standard Whisper baselines use auto language detection (Igbo is not in Whisper's language list).
- Sunbird forces Igbo via Whisper token `sa`; may not match English-heavy code-switch segments.
- OpenAI Whisper-1 API was not evaluated (429 rate limits on batch runs).
- Local Whisper checkpoints are base and tiny; large-v3 download stalled on my machine.
