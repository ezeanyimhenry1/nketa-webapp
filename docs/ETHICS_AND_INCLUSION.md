# Ethics, Safety & Inclusion — Nketa

## Consent

- Benchmark audio clips are recorded with **explicit verbal or written consent** from each speaker.
- Consent covers de-identified use for the Sahara CodeSwitch Africa Challenge and optional public benchmark submission.
- AfriSwitch clips use [intronhealth/AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) under **CC BY-NC-SA 4.0**; no additional personal data is collected.

## Privacy

- **In-app:** Audio is sent to Intron Voice API for STT/TTS only when the user taps the microphone or speaker icon. Nketa does not operate a backend that stores user voice recordings.
- **TTS cache:** Generated pronunciation audio is cached on the user's device (`intron_tts_cache` directory), not uploaded.
- **Translation data:** Typed or spoken text may be sent to OpenAI/IgboAPI for translation when the names dictionary does not match.
- **Benchmark scripts:** Local Python scripts send audio to STT APIs for evaluation only; results are stored in CSV/Markdown files locally.

## Safety

- Microphone permission is requested with a clear iOS/Android usage string before any recording.
- Users see a **"Heard: …"** confirmation after STT and can edit the transcript before Nsibidi lookup.
- Voice features require network connectivity; the app shows an error when offline rather than failing silently.
- No voice data is used to train models without explicit consent.

## Bias and fairness awareness

We report STT performance **stratified by subgroup** (Igbo names vs code-switched phrases vs AfriSwitch in-the-wild clips), not only aggregate WER.

Known limitations:

- Igbo has multiple dialects (Owerri, Enugu, Anambra, etc.); models may perform unevenly across regions.
- Local benchmark clips use **Intron Igbo TTS** (`recording_type: intron_tts_bootstrap`), clearly labeled in metadata. AfriSwitch clips are real in-the-wild human speech.

## Inclusion

- **Voice-first design** supports users who cannot type Igbo diacritics.
- **Cultural preservation:** Nsibidi symbols, proverbs, and cosmology content serve heritage education.
- **Diaspora access:** App works internationally with internet; core JSON content available offline.
- **Affordable access:** Free tier with usage limits; no paywall on cultural content browsing.

## Responsible data use summary

| Data type | Collected? | Stored? | Shared with |
|-----------|------------|---------|-------------|
| Voice (in-app) | On user action | Not on Nketa servers | Intron API |
| Voice (benchmark) | With consent | Local WAV files | STT APIs for eval |
| Name lookups | User input | Device only | IgboAPI if no dictionary match |
| Usage stats | App events | Firebase/local | Firebase (existing) |
