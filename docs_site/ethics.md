# Ethics, safety, and inclusion

## Consent

- Benchmark audio clips are recorded with explicit verbal or written consent from each speaker.
- Consent covers de-identified use for the Sahara CodeSwitch Africa Challenge and public benchmark submission.
- AfriSwitch clips use [intronhealth/AfriSwitch](https://huggingface.co/datasets/intronhealth/AfriSwitch) under **CC BY-NC-SA 4.0**.

## Privacy

- **In-app:** Audio goes to Intron Voice API for STT/TTS only when the user taps mic or speaker. I do not operate servers that store user voice recordings.
- **TTS cache:** Pronunciation audio is cached on the user's device (`intron_tts_cache`), not uploaded.
- **Translation:** Typed or spoken text may go to OpenAI or IgboAPI when the dictionary has no match.
- **Benchmark scripts:** Python scripts send audio to STT APIs for evaluation only; results are CSV and Markdown files.

## Safety

- Microphone permission is requested with a clear usage string before recording.
- Users see **"Heard: ..."** after STT and can edit the transcript before Nsibidi lookup.
- Voice features show an error when offline instead of failing silently.
- No voice data is used to train models without explicit consent.

## Bias and fairness

I report STT performance by subgroup (Igbo names, code-switched phrases, AfriSwitch clips), not only a single average WER.

Known limitations:

- Igbo has many dialects; models may perform unevenly by region.
- Local benchmark clips use Intron TTS bootstrap audio, clearly labeled in metadata. AfriSwitch clips are real human speech.

## Inclusion

- Voice-first design for users who cannot type Igbo diacritics.
- Nsibidi, proverbs, and cosmology content support heritage education.
- App works internationally with internet; core JSON works offline.
- Free tier with usage limits; cultural browsing is not paywalled.

## Data use summary

| Data | Collected? | Stored? | Shared with |
|------|------------|---------|-------------|
| Voice (in-app) | On user action | Not on Nketa servers | Intron API |
| Voice (benchmark) | With consent | Local WAV files | STT APIs for evaluation |
| Name lookups | User input | Device only | IgboAPI if no dictionary match |
| Usage stats | App events | Firebase/local | Firebase |
