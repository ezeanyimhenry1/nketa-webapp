# STT Benchmark Report - Nketa / Sahara CodeSwitch Challenge

## 1. Methodology

- **Primary model:** Intron Sahara (`use_language_asr_input=ig`) - production STT for Nketa
- **Baselines:** faster-whisper base/small (local, auto language); Sunbird African (Igbo via `sa`) if HF access granted; OpenAI Whisper-1 (auto language); optional Google STT (`ig-NG` + `en-NG`)
- **Language handling:** Intron uses explicit Igbo; standard Whisper has no Igbo code so baselines use auto-detect or Sunbird's Igbo mapping
- **Datasets:** Local Nketa clips (Igbo names + code-switched phrases) + [Intron AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) Igbo subset (CC BY-NC-SA 4.0)
- **Metrics:** WER, CER (diacritic-sensitive), exact match, latency, name lookup success (downstream Nketa task)
- **Reporting:** Stratified results by category and source

## 2. Overall Results

| Model | N | Avg WER | Avg CER | Exact Match | Name Lookup | Avg Latency (s) |
|---|---:|---:|---:|---:|---:|---:|
| faster_whisper | 50 | 0.940 | 0.537 | 3/50 | 3/50 | 1.82 |
| faster_whisper_small | 50 | 0.980 | 0.672 | 1/50 | 0/50 | 1.38 |
| intron | 50 | 0.740 | 0.295 | 13/50 | 14/50 | 14.81 |
| sunbird_whisper | 50 | 0.900 | 1.244 | 5/50 | 8/50 | 11.41 |

## 3. Stratified by Category

| Model | Category | N | Avg WER | Avg CER | Exact Match |
| faster_whisper_small | afriswitch | 25 | 1.000 | 0.643 | 0/25 |
| faster_whisper_small | code_switched | 10 | 0.900 | 0.532 | 1/10 |
| faster_whisper_small | igbo_name | 15 | 1.000 | 0.812 | 0/15 |
| faster_whisper | afriswitch | 25 | 1.000 | 0.567 | 0/25 |
| faster_whisper | code_switched | 10 | 0.800 | 0.392 | 2/10 |
| faster_whisper | igbo_name | 15 | 0.933 | 0.585 | 1/15 |
| intron | afriswitch | 25 | 0.920 | 0.372 | 2/25 |
| intron | code_switched | 10 | 0.800 | 0.334 | 2/10 |
| intron | igbo_name | 15 | 0.400 | 0.141 | 9/15 |
| sunbird_whisper | afriswitch | 25 | 1.000 | 0.398 | 0/25 |
| sunbird_whisper | code_switched | 10 | 0.600 | 0.222 | 4/10 |
| sunbird_whisper | igbo_name | 15 | 0.933 | 3.334 | 1/15 |

## 4. Stratified by Source

| Model | Source | N | Avg WER | Avg CER |
| faster_whisper_small | afriswitch | 25 | 1.000 | 0.643 |
| faster_whisper_small | local | 25 | 0.960 | 0.700 |
| faster_whisper | afriswitch | 25 | 1.000 | 0.567 |
| faster_whisper | local | 25 | 0.880 | 0.507 |
| intron | afriswitch | 25 | 0.920 | 0.372 |
| intron | local | 25 | 0.560 | 0.218 |
| sunbird_whisper | afriswitch | 25 | 1.000 | 0.398 |
| sunbird_whisper | local | 25 | 0.800 | 2.089 |

## 5. Pros and Cons per Model

### faster-whisper base (local)

- **Pros:** Open-source local Whisper via CTranslate2; no API rate limits; auto language detection. Observed avg WER 0.940, name lookup 3/50, latency 1.82s.
- **Cons:** No dedicated Igbo token; base checkpoint underperforms on Igbo vs Sahara.

### faster-whisper tiny (local)

- **Pros:** Second open-source local baseline; faster inference than base. Observed avg WER 0.980, name lookup 0/50, latency 1.38s.
- **Cons:** Tiny checkpoint; weakest on Igbo diacritics and code-switch vs Sahara.

### Intron Sahara

- **Pros:** Built for African Igbo-English code-switching; used in production Nketa speak-to-Nsibidi flow. Observed avg WER 0.740, name lookup 14/50, latency 14.81s.
- **Cons:** API dependency and rate limits; short-clip sensitivity without padding.

### Sunbird African faster-whisper

- **Pros:** Fine-tuned for 51 African languages; Igbo via language token `sa`. Observed avg WER 0.900, name lookup 8/50, latency 11.41s.
- **Cons:** Model download size; English segments in code-switched clips may be mis-handled.

## 6. Implications for Nketa

- **Production STT:** Intron Sahara powers speak-to-Nsibidi and proverb practice.
- **Fallback:** User can edit the heard transcript before lookup; offline dictionary still works for typed names.
- **TTS:** Intron Igbo voice for pronunciation; cached locally on device.

## 7. Limitations

- AfriSwitch clips are **in-the-wild human speech** from [intronhealth/AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) (Igbo config).
- Local Nketa clips use **Intron Igbo TTS** (`intron_tts_bootstrap`). Human recordings per [`benchmark/RECORDING_GUIDE.md`](../RECORDING_GUIDE.md) improve realism.
- Synthetic or studio audio improves consistency but under-represents spontaneous code-switching, accent diversity, and background noise.
- Standard Whisper baselines use **auto language detection** (Igbo is not in Whisper's language list).
- Sunbird baseline forces Igbo via Whisper token `sa`; may not match English-heavy code-switch segments.
- **OpenAI Whisper-1 API** was not evaluated - batch runs hit 429 rate limits.
- Local Whisper baselines used **base** and **tiny** checkpoints; large-v3/medium downloads stalled on my machine.

## 8. Raw Data

See `benchmark/results/stt_benchmark.csv` for per-clip results.

