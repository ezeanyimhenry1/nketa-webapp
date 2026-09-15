# Nketa

**Sahara CodeSwitch Africa Challenge | Education and Culture**

Nketa is a Flutter app for Igbo language and culture. You speak a name or phrase; Intron Sahara transcribes it; the app looks up Nsibidi symbols, proverbs, and translations.

## Demo video

YouTube (unlisted): _add your link before submitting_

## What is in this site

| Page | Contents |
|------|----------|
| [Solution](solution.md) | Problem, users, voice features, architecture |
| [Benchmark report](benchmark-report.md) | STT comparison on 50 Igbo clips |
| [Sample clips](benchmark-samples.md) | Listen to each clip and compare model transcripts |
| [Reproduce benchmark](benchmark-howto.md) | How we ran the evaluation |
| [Ethics](ethics.md) | Consent, privacy, fairness |

## Benchmark at a glance

Four STT systems on the same 50 clips (15 Igbo names, 10 code-switched phrases, 25 AfriSwitch in-the-wild samples):

| Model | Avg WER | Exact match | Name lookup |
|-------|--------:|------------:|------------:|
| Intron Sahara | 0.740 | 13/50 | 14/50 |
| Sunbird African | 0.900 | 5/50 | 8/50 |
| faster-whisper base | 0.940 | 3/50 | 3/50 |
| faster-whisper tiny | 0.980 | 1/50 | 0/50 |

Intron is what we ship in the app. Sunbird and faster-whisper baselines run locally.

## Repository

Application source is in a private repository. Organizer read access is available on request.

Challenge details: [intron.io/compete](https://www.intron.io/compete/)
