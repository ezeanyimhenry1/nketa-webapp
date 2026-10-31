# Nketa web app setup

The Flutter app can be built for the browser as an installable PWA. A few Firebase Console steps cannot be done from this repo.

## 1. Create a Firebase Web app

1. Open Firebase Console → project `the-igbo-bible`.
2. Add a **Web** app.
3. Replace `appId: '1:994305615388:web:placeholder'` in `lib/firebase_options.dart` and `web/firebase-messaging-sw.js` with the real web app id.
4. Add the hosted domain under Authentication → Settings → Authorized domains.
5. Create a Google OAuth **Web client ID**. Put it in:
   - `.env` as `GOOGLE_WEB_CLIENT_ID`
   - `web/index.html` as `google-signin-client_id`
6. Cloud Messaging → Web Push certificates → copy the **public** VAPID key into `.env` as `FIREBASE_VAPID_KEY`.

## 2. API proxy and reminders

The web client must not ship OpenAI, Intron, or Flutterwave keys. Those live in Cloud Functions.

```bash
cd the_igbo_bible/functions
npm install
firebase functions:secrets:set OPENAI_API_KEY
firebase functions:secrets:set INTRON_API_KEY
firebase functions:secrets:set FLUTTERWAVE_API_KEY
firebase deploy --only functions,firestore:rules
```

Then set in the Flutter `.env`:

```
WEB_API_BASE_URL=https://us-central1-the-igbo-bible.cloudfunctions.net
FIREBASE_VAPID_KEY=your_public_vapid_key
GOOGLE_WEB_CLIENT_ID=your_web_client_id.apps.googleusercontent.com
```

## 3. Build and host at the origin root

Host the Flutter web build at the **root** of `https://web.nketa.app`. A subpath breaks the service worker, `start_url`, and iOS Add to Home Screen.

`netlify.toml` builds this PWA with `scripts/netlify_build_web.sh` and publishes `build/web`. The MkDocs docs build lives in `netlify.docs.toml` and is not the web app site.

On the web app Netlify site, set `IGBO_API_KEY` so dictionary lookup works. Set `FIREBASE_VAPID_KEY` when you want web push. Do not put `OPENAI_API_KEY`, `INTRON_API_KEY`, `FLUTTERWAVE_API_KEY`, or `HF_TOKEN` in Netlify. Those stay in Cloud Functions. The build writes a public `.env` and would publish any secret you add to that file.

`web/index.html` registers `firebase-messaging-sw.js` as the page service worker. That worker caches the app shell and handles web push.

## 4. Marketing site

`nketa_fe` is `https://nketa.app`. `VITE_WEB_APP_URL` should be `https://web.nketa.app`.
