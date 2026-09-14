# Nketa — Solution Description

**Sahara CodeSwitch Africa Challenge | Education & Culture**

## Problem

Igbo is spoken by over 50 million people, yet most speech AI systems struggle with Igbo names, code-switched Igbo–English speech, and diacritics. Nsibidi — the indigenous Igbo writing system — is largely inaccessible to learners who cannot type or spell Igbo correctly. Existing translation apps require keyboard input and do not connect speech to cultural symbols.

## Target users

- Igbo learners and diaspora reconnecting with language and heritage
- Parents seeking Nsibidi representations of Igbo names for children
- Educators teaching Igbo proverbs, cosmology, and writing systems
- Low-literacy users who benefit from voice-first interfaces

## Solution

**Nketa** is a Flutter mobile app that combines Igbo cultural content with Intron Voice AI:

1. **Speak your Igbo name → get Nsibidi** — User speaks a name; Intron STT transcribes; the app looks up the name in a 130-entry Nsibidi dictionary and displays the symbol.
2. **Proverb voice practice** — User recites an Igbo proverb; STT output is scored against the reference; streak tracking encourages learning.
3. **Igbo TTS pronunciation** — Cosmology terms, proverbs, names, and translation results are read aloud in Igbo via Intron TTS with on-device caching.

## Voice-driven actions

Voice input drives downstream tasks:

| Voice input | Downstream action |
|-------------|-------------------|
| Spoken Igbo name | Nsibidi symbol lookup + save/share |
| Spoken proverb | Similarity score + feedback + next proverb |
| Spoken search query | Filter names / dictionary results |
| Tap speaker icon | Generate/play Igbo pronunciation |

## Key technical decisions

| Decision | Rationale |
|----------|-----------|
| Intron Sahara STT (`ig`) | Native Igbo–English code-switching support |
| Streaming STT WebSocket | Live partial transcript UX on Translate screen |
| Sync STT fallback | Resilience when WebSocket unavailable |
| Local name dictionary first | Fast, offline-capable Nsibidi lookup before AI/API |
| Intron Igbo TTS + disk cache | Reduce API calls; faster repeat playback |
| igbo_api Nsibidi source | 5,000+ real symbols vs placeholder Unicode |

## Architecture

```
Mic → Intron STT (ig) → transcript
                          ↓
              IgboNsibidiNamesService.findName()
                          ↓
              Nsibidi display / save / share

Speaker → Intron TTS (ig) → cache → audioplayers
```

## Content

- 130 Igbo names with real Nsibidi (igbo_api dictionary)
- Proverbs, cosmology, stories, history timeline (JSON, GitHub-first loading)
- Offline asset fallback when remote JSON unavailable

## Repository

https://github.com/ezeanyimhenry1/the_igbo_bible

## Related documents

- [Benchmark Report](../benchmark/results/BENCHMARK_REPORT.md)
- [Ethics & Inclusion](./ETHICS_AND_INCLUSION.md)
- [Demo Video Script](./DEMO_VIDEO_SCRIPT.md)
