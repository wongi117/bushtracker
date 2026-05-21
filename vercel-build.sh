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

flutter build web --release $DART_DEFINES

echo "==> Build complete. Output: build/web"
ls -lh build/web
