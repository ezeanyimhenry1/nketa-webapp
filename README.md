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

Privacy, terms, and payment redirects use `https://nketa.netlify.app/` (deploy the same routes as before: `/privacy`, `/terms`, `/payment-success`, `/subscribe`, `/logo.png`).
