# Nketa

Igbo language and culture app (Flutter).

## Getting Started

```bash
flutter pub get
flutter run
```

## Environment

Create a `.env` file in the project root (see existing `.env` keys for API URLs, keys, and subscription IDs).

For Android subscriptions after rebrand, set `SUBSCRIPTION_ID=nketa` in `.env`. Keep `APPLE_SUBSCRIPTION_ID` as your existing iOS product ID.

## Firebase (post-rebrand)

Android now uses bundle ID `com.henryezeanyim.nketa`. iOS keeps `com.henryezeanyim.theigbobible`.

1. In [Firebase Console](https://console.firebase.google.com/), open project `the-igbo-bible`.
2. Add a new **Android** app with package name `com.henryezeanyim.nketa`.
3. Keep the existing **iOS** app (`com.henryezeanyim.theigbobible`).
4. Run `flutterfire configure` and regenerate:
   - `lib/firebase_options.dart`
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
5. In Google Cloud Console, ensure the Android OAuth client matches the new package and update `GOOGLE_SERVER_CLIENT_ID` in `.env` if needed.

## External URLs

Privacy, terms, and payment redirects use `https://nketa.app/` (`/privacy`, `/terms`, `/payment-success`, `/icon.png`). The web app is `https://web.nketa.app`.

## Hackathon / Benchmark

Sahara CodeSwitch Africa Challenge submission materials:

- **Public docs site:** https://nketa-hackathon.netlify.app
- **Demo video:** https://youtu.be/N06dcGXm1XM
- In-repo copies: [Solution](docs/HACKATHON_SOLUTION.md), [Benchmark report](benchmark/results/BENCHMARK_REPORT.md), [Demo script](docs/DEMO_VIDEO_SCRIPT.md)

### Preview submission docs locally

```bash
pip install -r requirements-docs.txt
python3 scripts/build_docs.py
python3 -m mkdocs serve
```

Open http://127.0.0.1:8000 for the submission site (solution, benchmark report, listen-and-compare sample clips).

### Netlify deploy

1. Netlify -> Add site -> Import from Git (private repo is fine)
2. Site name e.g. `nketa-hackathon`
3. Build command and publish directory are set in [`netlify.toml`](netlify.toml)
4. No env vars needed for the docs build

Reproduce the STT benchmark: see [benchmark/README.md](benchmark/README.md).
