# Nketa

**Symbols of the past. Knowledge for the future.**

**Sahara CodeSwitch Africa Challenge | Education and Culture**

Nketa (formerly [The Igbo Bible](https://theigbobible.netlify.app)) is a Flutter app for Igbo language and culture. You speak a name or phrase; Intron Sahara transcribes it; the app looks up Nsibidi symbols, proverbs, and translations.

## Demo video

YouTube (unlisted): _add your link before submitting_

## Submission checklist

| Item | Where |
|------|--------|
| Solution write-up | [Solution](solution.md) |
| Demo video | Link above |
| Technical documentation | This site |
| STT benchmark (4 models, 50 clips) | [Benchmark report](benchmark-report.md) + [Sample clips](benchmark-samples.md) |
| Ethics and inclusion | [Ethics](ethics.md) |

## What is in this site

| Page | Contents |
|------|----------|
| [Solution](solution.md) | Product story, code-switching, user journeys, Intron integration |
| [Benchmark report](benchmark-report.md) | STT comparison and interpretation |
| [Sample clips](benchmark-samples.md) | Listen and compare model transcripts |
| [Reproduce benchmark](benchmark-howto.md) | How I ran the evaluation |
| [Ethics](ethics.md) | Consent, privacy, fairness |

## Code-switch highlights in the app

- **Translate:** Say `"My name is Chinedu"` - STT transcribes the full phrase; dictionary lookup finds `Chinedu`; shared Nsibidi image shows the Igbo name, not the English wrapper.
- **Proverb practice:** Recite the Igbo proverb alone, or use **guided code-switch mode** with an English intro (`"The proverb is..."`) - scoring extracts and matches the Igbo segment.
- **Everywhere voice is used:** Intron Sahara STT with explicit Igbo language mode (`ig`).

## Benchmark at a glance

Four STT systems on the same 50 clips (15 Igbo names, 10 code-switched phrases, 25 AfriSwitch in-the-wild samples):

| Model | Avg WER | Exact match | Name lookup |
|-------|--------:|------------:|------------:|
| Intron Sahara | 0.740 | 13/50 | **14/50** |
| Sunbird African | 0.900 | 5/50 | 8/50 |
| faster-whisper base | 0.940 | 3/50 | 3/50 |
| faster-whisper tiny | 0.980 | 1/50 | 0/50 |

Name lookup measures whether Nketa can find the correct dictionary entry from the STT transcript - the task that matters for speak-to-Nsibidi.

## Repository

Application source is in a private repository. I can grant organizer read access on request.

Public product page: [theigbobible.netlify.app](https://theigbobible.netlify.app)

Challenge details: [intron.io/compete](https://www.intron.io/compete/)
