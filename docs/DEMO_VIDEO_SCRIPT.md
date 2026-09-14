# Demo Video Script — Nketa (3 minutes)

Upload as **unlisted or public YouTube** link for hackathon submission.

## Pre-recording checklist

- [ ] `INTRON_API_KEY` set in `.env`
- [ ] App rebuilt after iOS mic permission fix (`pod install`, `flutter clean`, `flutter run`)
- [ ] Test on real device: speak "Chinedu" → Nsibidi appears
- [ ] Benchmark report generated (`benchmark/results/BENCHMARK_REPORT.md`)

### Device tests (real phone)

- [ ] First mic tap shows permission dialog (not immediate error)
- [ ] Translate: tap mic → speak **"Chinedu"** → transcript → Nsibidi symbol → speaker plays Igbo
- [ ] Proverb Voice Practice: recite proverb → feedback and streak update
- [ ] Airplane mode shows sensible error for voice features

## Script

### 0:00–0:30 — Problem & users

> "Igbo is spoken by over 50 million people, but speech AI often fails on our names and mixed Igbo–English speech. Nsibidi — our indigenous writing system — is hard to access if you can't type Igbo. Nketa fixes this with voice."

Show: app home / translate screen.

### 0:30–1:15 — Speak-to-Nsibidi

> "Watch what happens when I speak my Igbo name."

1. Tap mic on Translate screen
2. Say **"Chinedu"** (or another name)
3. Show partial transcript chip, then Nsibidi result
4. Tap speaker icon for Igbo pronunciation
5. Save or share the symbol

> "Voice isn't just transcription — it drives a downstream action: name to Nsibidi symbol."

### 1:15–1:45 — Proverb practice

Navigate: Menu → **Proverb Voice Practice**

1. Show Igbo proverb on screen
2. Tap mic and recite
3. Show similarity feedback and streak

### 1:45–2:15 — Benchmark highlights

Show slide or scroll through `BENCHMARK_REPORT.md`:

> "We benchmarked three STT systems on the same 50 clips — 15 Igbo names, 10 code-switched phrases, and 25 AfriSwitch in-the-wild samples. Intron Sahara is our production model. We compared it against two open-source faster-whisper baselines running locally — base and tiny — with auto language detection."

> "Intron wins on what matters for Nketa: lower WER, better name lookup, and it handles Igbo–English code-switch. The Whisper baselines are faster but much less accurate on Igbo. Sunbird African and OpenAI Whisper API were blocked by gated model access and rate limits — documented in our limitations."

Show overall results table: Intron WER ~0.74 vs faster-whisper ~0.94–0.98; name lookup 14/50 vs 0–3/50.

### 2:15–2:45 — Ethics & inclusion

> "Users consent to mic access, can edit what the app heard, and pronunciation audio is cached locally. We report benchmark results by subgroup, not just average accuracy."

### 2:45–3:00 — Close

> "Nketa — learn Igbo culture through voice. GitHub link in description. Built for the Sahara CodeSwitch Africa Challenge."

**On-screen:** GitHub URL, app name, your name/team.

## YouTube description template

```
Nketa — Voice-powered Igbo cultural learning app
Sahara CodeSwitch Africa Challenge submission

Features:
- Speak Igbo name → Nsibidi symbol
- Proverb voice practice
- Igbo TTS pronunciation

GitHub: https://github.com/ezeanyimhenry1/the_igbo_bible
Benchmark: see benchmark/results/BENCHMARK_REPORT.md
```

## Placeholder

**YouTube URL:** _paste after recording_
