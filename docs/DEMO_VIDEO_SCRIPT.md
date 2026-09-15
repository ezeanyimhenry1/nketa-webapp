# Demo Video Script - Nketa (3 minutes)

Upload as **unlisted or public YouTube** link for hackathon submission.

**Format:** Screen recording on a real phone + voiceover. Keep pace brisk; judges watch many submissions.

## Pre-recording checklist

- [ ] `INTRON_API_KEY` set in `.env`
- [ ] App rebuilt on real device
- [ ] Test: speak "My name is Chinedu" -> Nsibidi appears; share image shows **Chinedu** not full phrase
- [ ] Test: Proverb practice with guided code-switch mode ON
- [ ] Benchmark report / docs site ready to show briefly
- [ ] Prepare opening title card or on-screen text overlay (see Intro)

### Device tests (real phone)

- [ ] First mic tap shows permission dialog (not immediate error)
- [ ] Translate: tap mic -> speak **"My name is Chinedu"** -> Nsibidi -> share image label is **Chinedu**
- [ ] Proverb Voice Practice: enable guided mode -> say English intro + Igbo proverb -> pass feedback
- [ ] Airplane mode shows sensible error for voice features

## On-screen text (optional overlay)

Use for the first 3-5 seconds, then fade out:

```
Nketa
Sahara CodeSwitch Africa Challenge
Education and Culture
```

## Script

### 0:00-0:20 - Intro

**On-screen:** App logo or home screen. Optional title overlay above.

**You say:**

> "Hi, I'm **[Your Name]**. This is **Nketa** - formerly The Igbo Bible - my submission for the **Intron Sahara CodeSwitch Africa Challenge**, Education and Culture category.
>
> Nketa helps Igbo learners and diaspora connect with heritage through **voice**. You speak in Igbo, English, or both. **Intron Sahara** transcribes it. Nketa links that speech to **Nsibidi symbols**, proverbs, and Igbo pronunciation."

**Show:** Quick glimpse of Translate screen, or a Nsibidi result already on screen.

**Tip:** Replace `[Your Name]` before recording. Say your name clearly - judges attribute submissions to people, not only repos.

---

### 0:20-0:40 - Problem and users

**On-screen:** Translate screen or browse screen.

**You say:**

> "Igbo is spoken by over 50 million people, but speech AI often fails on **Igbo names** and **mixed Igbo-English speech**. Nsibidi - the indigenous Igbo writing system - is hard to reach if you can't type Igbo diacritics.
>
> Nketa is **voice-first** for learners, parents, educators, and diaspora who want cultural connection without fighting the keyboard."

---

### 0:40-1:20 - Demo: speak-to-Nsibidi with code-switch

**On-screen:** Translate screen.

**You say:**

> "Watch what happens when I speak my name the way people actually talk - English and Igbo together."

**Actions:**

1. Tap mic
2. Say **"My name is Chinedu"**
3. Show partial transcript chip, then final result
4. Point out Nsibidi symbol for Chinedu
5. Tap **Generate Image** - show the shared image label is **Chinedu**, not the full English phrase
6. Tap speaker icon for Igbo pronunciation

**You say:**

> "Voice isn't just transcription. Intron STT returns the phrase; Nketa **finds the Igbo name inside it** and drives the next step: Nsibidi lookup, save, and share."

---

### 1:20-1:50 - Demo: proverb practice with code-switch

**On-screen:** Menu -> **Proverb Voice Practice**

**You say:**

> "Code-switching shows up in learning too. In proverb practice, you can recite pure Igbo - or use **guided code-switch mode** with an English intro."

**Actions:**

1. Enable **Guided code-switch mode**
2. Show prompt: e.g. "The proverb is..."
3. Tap mic; say English intro + Igbo proverb (e.g. "The proverb is Onye kwe chi ya ekwe")
4. Show feedback with score and **Matched:** Igbo segment
5. Show streak update if time allows

**You say:**

> "I score the **Igbo proverb segment**, not the full mixed sentence - so natural English framing still works."

---

### 1:50-2:20 - Benchmark highlights

**On-screen:** Docs site benchmark report or `benchmark/results/BENCHMARK_REPORT.md` - scroll to overall table, then sample clips link.

**You say:**

> "I benchmarked **four STT systems** on the same **50 clips**: Igbo names, code-switched phrases, and AfriSwitch in-the-wild human speech.
>
> **Intron Sahara** is what I ship in the app. Baselines: Sunbird African, faster-whisper base, and tiny.
>
> Intron wins on **name lookup** - 14 of 50 - the metric that matches speak-to-Nsibidi. Sunbird is competitive on code-switched WER but weaker on diacritics and AfriSwitch clips."

**Show:** Overall results table. Optionally flash sample clips page for 3 seconds.

---

### 2:20-2:45 - Ethics and production choice

**On-screen:** Ethics page on docs site, or app mic permission / "Heard:" edit UI.

**You say:**

> "Users see what the app heard and can edit before lookup. Voice goes to Intron for STT and TTS; pronunciation audio is cached on device. I report benchmark results by **category**, not only one average number.
>
> I chose Intron Sahara for production because accuracy on Igbo names and code-switch matters more than raw latency for this app."

---

### 2:45-3:00 - Close

**On-screen:** Title card or end slate:

```
Nketa
Symbols of the past. Knowledge for the future.
Docs: nketa-hackathon.netlify.app
[Your Name]
```

**You say:**

> "Nketa - Igbo culture through voice. Full documentation and benchmark clips are on the docs site in the description. Thank you."

---

## Alternate opening (demo-first, optional)

If you prefer a hook before the formal intro, record this as 0:00-0:15 then continue from **Problem and users**:

> "I say *My name is Chinedu* - and Nketa finds the Igbo name and shows the Nsibidi symbol. I'm **[Your Name]**, and this is Nketa for the Sahara CodeSwitch challenge."

Then run the Translate demo immediately, backfill intro/context at 0:40 if needed.

## YouTube title suggestion

```
Nketa - Igbo Voice, Nsibidi & Code-Switch STT | Sahara CodeSwitch Challenge
```

## YouTube description template

```
Nketa - Voice-powered Igbo cultural learning app
Sahara CodeSwitch Africa Challenge submission | Education and Culture
(formerly The Igbo Bible)

Built by: [Your Name]

What you'll see:
- Intro: Nketa + Intron Sahara code-switch STT
- Speak "My name is Chinedu" -> Nsibidi (share shows Igbo name)
- Proverb practice with guided English + Igbo code-switch mode
- STT benchmark: Intron vs Sunbird vs faster-whisper on 50 Igbo clips

Links:
Docs (benchmark, ethics, sample clips): https://nketa-hackathon.netlify.app
Product site: https://theigbobible.netlify.app

Tech: Flutter + Intron Voice AI (STT/TTS)
Category: Education and Culture
```

## Placeholder

**YouTube URL:** _paste after recording_
