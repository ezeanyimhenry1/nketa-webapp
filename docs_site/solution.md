# Solution

**Category:** Education and Culture

## Problem

Igbo is spoken by over 50 million people, but most speech tools struggle with Igbo names, mixed Igbo-English speech, and diacritics. Nsibidi, the indigenous Igbo writing system, is hard to reach if you cannot type Igbo correctly. Translation apps usually expect keyboard input and do not link speech to cultural symbols.

## Who it is for

- Igbo learners and diaspora reconnecting with language and heritage
- Parents who want Nsibidi representations of Igbo names
- Educators teaching proverbs, cosmology, and writing systems
- Users who prefer voice over typing, especially when diacritics are difficult

## What we built

**Nketa** is a Flutter mobile app using Intron Voice AI:

1. **Speak a name, get Nsibidi** - Intron STT transcribes speech; the app matches against a 130-name dictionary and shows the symbol.
2. **Proverb practice** - Recite a proverb; STT output is scored against the reference with streak tracking.
3. **Igbo pronunciation** - Cosmology terms, proverbs, and names are read aloud via Intron TTS with on-device caching.

## Voice features

| Input | What happens next |
|-------|-------------------|
| Spoken Igbo name | Nsibidi lookup, save, share |
| Spoken proverb | Similarity score and feedback |
| Spoken search | Filter names in the dictionary |
| Tap speaker icon | Play Igbo pronunciation |

## Technical choices

| Choice | Why |
|--------|-----|
| Intron Sahara STT (`ig`) | Igbo-English code-switch support |
| Streaming STT WebSocket | Live partial transcript on Translate screen |
| Sync STT fallback | Works when WebSocket is unavailable |
| Local name dictionary first | Fast offline Nsibidi lookup |
| Intron Igbo TTS + disk cache | Fewer API calls on repeat playback |
| igbo_api Nsibidi source | Real symbols, not placeholder Unicode |

## Architecture

| Step | Component |
|------|-----------|
| 1 | Mic captures audio |
| 2 | Intron STT (`ig`) returns transcript |
| 3 | `IgboNsibidiNamesService.findName()` matches dictionary |
| 4 | Nsibidi symbol shown; user can save or share |
| TTS | Intron Igbo voice, cached on device, played via audioplayers |

## Content

- 130 Igbo names with Nsibidi from igbo_api
- Proverbs, cosmology, stories, history timeline (JSON, GitHub-first with offline fallback)
