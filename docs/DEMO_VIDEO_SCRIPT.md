# Demo Video Script - Nketa (3 minutes)

Upload as **unlisted or public YouTube** link for hackathon submission.

## Pre-recording checklist

- [ ] `INTRON_API_KEY` set in `.env`
- [ ] App rebuilt on real device
- [ ] Test: speak "My name is Chinedu" -> Nsibidi appears; share image shows **Chinedu** not full phrase
- [ ] Test: Proverb practice with guided code-switch mode ON
- [ ] Benchmark report generated (`benchmark/results/BENCHMARK_REPORT.md`)

### Device tests (real phone)

- [ ] First mic tap shows permission dialog (not immediate error)
- [ ] Translate: tap mic -> speak **"My name is Chinedu"** -> Nsibidi -> share image label is **Chinedu**
- [ ] Proverb Voice Practice: enable guided mode -> say English intro + Igbo proverb -> pass feedback
- [ ] Airplane mode shows sensible error for voice features

## Script

### 0:00-0:30 - Problem and users

> "Igbo is spoken by over 50 million people, but speech AI often fails on our names and mixed Igbo-English speech. Nsibidi - our indigenous writing system - is hard to access if you can't type Igbo. Nketa - formerly The Igbo Bible - fixes this with voice."

Show: app home / translate screen.

### 0:30-1:15 - Speak-to-Nsibidi with code-switch

> "Watch what happens when I speak my name in English and Igbo."

1. Tap mic on Translate screen
2. Say **"My name is Chinedu"**
3. Show partial transcript chip, then Nsibidi result
4. Tap Generate Image - show shared image says **Chinedu**, not the full English phrase
5. Tap speaker icon for Igbo pronunciation

> "Voice drives a downstream action: find the Igbo name inside mixed speech, then show Nsibidi."

### 1:15-1:45 - Proverb practice with code-switch

Navigate: Menu -> **Proverb Voice Practice**

1. Enable **Guided code-switch mode**
2. Show English prompt: "The proverb is..."
3. Tap mic and say intro + Igbo proverb
4. Show matched Igbo segment in feedback and streak update

### 1:45-2:15 - Benchmark highlights

Show slide or scroll through benchmark report / docs site:

> "We benchmarked four STT systems on 50 clips - Igbo names, code-switched phrases, and AfriSwitch in-the-wild samples. Intron Sahara is production. Baselines: Sunbird African, faster-whisper base, and tiny."

> "Intron wins on name lookup - 14 of 50 - what matters for speak-to-Nsibidi. Sunbird is best on code-switched WER but weak on diacritics."

Show overall results table and link to sample clips page on docs site.

### 2:15-2:45 - Ethics and inclusion

> "Users consent to mic access, can edit what the app heard, and pronunciation audio is cached locally. We report benchmark results by subgroup, not just average accuracy."

### 2:45-3:00 - Close

> "Nketa - learn Igbo culture through voice. Docs site and private repo access in description. Built for the Sahara CodeSwitch Africa Challenge."

**On-screen:** Docs site URL, app name Nketa, your name/team.

## YouTube description template

```
Nketa - Voice-powered Igbo cultural learning app
Sahara CodeSwitch Africa Challenge submission
(formerly The Igbo Bible)

Features:
- Speak Igbo name (even "My name is Chinedu") -> Nsibidi symbol
- Proverb voice practice with code-switch mode
- Igbo TTS pronunciation

Docs: https://nketa-hackathon.netlify.app
Product: https://theigbobible.netlify.app
Benchmark: see docs site / benchmark report
```

## Placeholder

**YouTube URL:** _paste after recording_
