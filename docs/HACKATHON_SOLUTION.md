# Nketa - Solution Description

**Sahara CodeSwitch Africa Challenge | Education and Culture**

## About Nketa

Nketa is the new name for **The Igbo Bible**, an Igbo language and heritage app. Public product page: [theigbobible.netlify.app](https://theigbobible.netlify.app). Submission docs: hackathon MkDocs site in this repo.

## Problem

Igbo is spoken by over 50 million people, yet most speech AI systems struggle with Igbo names, code-switched Igbo-English speech, and diacritics. Nsibidi - the indigenous Igbo writing system - is largely inaccessible to learners who cannot type or spell Igbo correctly. Existing translation apps require keyboard input and do not connect speech to cultural symbols.

## Target users

- Igbo learners and diaspora reconnecting with language and heritage
- Parents seeking Nsibidi representations of Igbo names for children
- Educators teaching Igbo proverbs, cosmology, and writing systems
- Low-literacy users who benefit from voice-first interfaces

## Solution

**Nketa** is a Flutter mobile app that combines Igbo cultural content with Intron Voice AI:

1. **Speak your Igbo name, get Nsibidi** - User speaks (e.g. "My name is Chinedu"); Intron STT transcribes; substring dictionary lookup finds Chinedu; Nsibidi displayed and shared with Igbo name on image.
2. **Proverb voice practice** - User recites proverb (Igbo only or English intro + Igbo in guided code-switch mode); code-switch-aware scoring; streak tracking.
3. **Igbo TTS pronunciation** - Cosmology terms, proverbs, names read aloud via Intron TTS with on-device caching.

## Code-switching

| Pattern | Example | Handling |
|---------|---------|----------|
| English + Igbo name | "My name is Chinedu" | `findName()` substring match |
| English intro + proverb | "The proverb is..." + Igbo | `ProverbPracticeService` word-span extraction |
| Pure Igbo | "Chinedu" | Direct match |

## Voice-driven actions

| Voice input | Downstream action |
|-------------|-------------------|
| Spoken Igbo name or phrase | Nsibidi lookup + save/share (Igbo name on image) |
| Spoken proverb | Code-switch-aware similarity score + feedback |
| Spoken search query | Filter names / dictionary results |
| Tap speaker icon | Generate/play Igbo pronunciation |

## Key technical decisions

| Decision | Rationale |
|----------|-----------|
| Intron Sahara STT (`ig`) | Native Igbo-English code-switching support |
| Streaming STT WebSocket | Live partial transcript UX on Translate screen |
| Sync STT fallback | Resilience when WebSocket unavailable |
| Substring name lookup | Tolerates English framing in spoken input |
| Proverb word-span scoring | Scores Igbo segment in mixed utterances |
| Local name dictionary first | Fast, offline-capable Nsibidi lookup before AI/API |
| Intron Igbo TTS + disk cache | Reduce API calls; faster repeat playback |
| igbo_api Nsibidi source | Real symbols vs placeholder Unicode |

## Architecture

```
Mic -> Intron STT (ig) -> transcript
                          |
              IgboNsibidiNamesService.findName()
                          |
              Nsibidi display / share (Igbo name label)

Speaker -> Intron TTS (ig) -> cache -> audioplayers
```

## Content

- 130 Igbo names with real Nsibidi (igbo_api dictionary)
- Proverbs, cosmology, stories, history timeline (JSON, GitHub-first loading)
- Offline asset fallback when remote JSON unavailable

## Related documents

- [Benchmark Report](../benchmark/results/BENCHMARK_REPORT.md)
- [Ethics and Inclusion](./ETHICS_AND_INCLUSION.md)
- [Demo video](https://youtu.be/N06dcGXm1XM) | [Demo script](./DEMO_VIDEO_SCRIPT.md)
- Public docs site: https://nketa-hackathon.netlify.app
