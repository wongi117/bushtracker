#!/bin/bash
# BushTrack — Vercel build script
# Public build — no API keys. Keys are for local dev only.

set -e

FLUTTER_DIR="$HOME/flutter"

echo "==> Checking Flutter..."
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "==> Installing Flutter (stable)..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "==> Flutter version:"
flutter --version

echo "==> Precaching web artifacts..."
flutter precache --web

echo "==> Getting dependencies..."
flutter pub get

echo "==> Building Flutter web (release)..."
DART_DEFINES=""
[ -n "$GEMINI_API_KEY" ]  && DART_DEFINES="$DART_DEFINES --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY"
[ -n "$GEMINI_KEY" ]      && DART_DEFINES="$DART_DEFINES --dart-define=GEMINI_KEY=$GEMINI_KEY"
[ -n "$MAPBOX_TOKEN" ]    && DART_DEFINES="$DART_DEFINES --dart-define=MAPBOX_TOKEN=$MAPBOX_TOKEN"
[ -n "$MAPTILER_KEY" ]    && DART_DEFINES="$DART_DEFINES --dart-define=MAPTILER_KEY=$MAPTILER_KEY"

# One id for this build: baked into the app (shown in the menu) and used for
# the cache-busted URLs, so the number on screen matches the ?v= being served.
export BUILD_ID="$(date -u +%Y%m%d%H%M%S)"
echo "==> Build id: $BUILD_ID"

flutter build web --release $DART_DEFINES --dart-define=BUILD_ID=$BUILD_ID

echo "==> Cache-busting (every build gets its own URLs)..."
bash cache-bust-web.sh build/web

echo "==> Build complete. Output: build/web"
ls -lh build/web