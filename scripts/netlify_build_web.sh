#!/usr/bin/env bash
# Builds the Flutter web app for the Netlify site at web.nketa.app.
# Writes a public .env on Netlify only. Secret API keys stay in Cloud Functions.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_DIR="${NETLIFY_CACHE_DIR:-$HOME/.cache}/flutter"
  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    rm -rf "$FLUTTER_DIR"
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

flutter config --enable-web --no-analytics
flutter precache --web
flutter pub get

if [ "${NETLIFY:-}" = "true" ]; then
  cat > .env << EOF
JSON_URL=${JSON_URL:-https://raw.githubusercontent.com/ezeanyimhenry1/}
IGBO_API_BASE_URL=${IGBO_API_BASE_URL:-https://igboapi.com/api/v2}
OPENAI_API_BASE_URL=${OPENAI_API_BASE_URL:-https://api.openai.com/v1}
WEB_API_BASE_URL=${WEB_API_BASE_URL:-https://us-central1-the-igbo-bible.cloudfunctions.net}
GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID:-994305615388-s61dbjj93dfms6hd0pe59pcrqud2lff0.apps.googleusercontent.com}
GOOGLE_SERVER_CLIENT_ID=${GOOGLE_SERVER_CLIENT_ID:-}
FIREBASE_VAPID_KEY=${FIREBASE_VAPID_KEY:-}
APPLE_SUBSCRIPTION_ID=${APPLE_SUBSCRIPTION_ID:-theigbobible}
SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-nketa}
APP_STORE_ID=${APP_STORE_ID:-}
INTRON_VOICE_LANGUAGE=${INTRON_VOICE_LANGUAGE:-ig}
INTRON_VOICE_ACCENT=${INTRON_VOICE_ACCENT:-igbo}
INTRON_VOICE_GENDER=${INTRON_VOICE_GENDER:-female}
INTRON_ASR_LANGUAGE=${INTRON_ASR_LANGUAGE:-ig}
EOF
fi

flutter build web --release --base-href /
