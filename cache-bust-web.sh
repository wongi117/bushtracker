#!/bin/bash
# Give every web build its own URLs, so phones pick up new deploys.
#
# vercel.json lets browsers cache the app for a year, but Flutter's file names
# never change between builds (main.dart.js, flutter_bootstrap.js,
# assets/fonts/MaterialIcons-Regular.otf ...). Returning visitors therefore
# kept running whatever build they first loaded — and because the icon font is
# trimmed to the icons each build uses, newly added icons showed as blank
# boxes against a stale cached font.
#
# index.html is re-checked on every visit, so it is the anchor: it points at
# this build's bootstrap, which points at this build's main.dart.js and asset
# folder. Old cached copies are simply never asked for again, and the new
# ones can be cached for a year safely.
#
# Usage: bash cache-bust-web.sh [web build dir]    (default: build/web)
set -euo pipefail

WEB="${1:-build/web}"
ID="${BUILD_ID:-$(date -u +%Y%m%d%H%M%S)}"

if [ ! -f "$WEB/index.html" ] || [ ! -f "$WEB/flutter_bootstrap.js" ] || [ ! -d "$WEB/assets" ]; then
  echo "cache-bust: $WEB doesn't look like a fresh Flutter web build" >&2
  exit 1
fi

# 1. Assets move into a versioned folder, and the engine is told where.
mkdir -p "$WEB/v/$ID"
mv "$WEB/assets" "$WEB/v/$ID/assets"
sed -i "s|_flutter\.loader\.load({|_flutter.loader.load({config:{assetBase:\"v/$ID/\"},|" "$WEB/flutter_bootstrap.js"

# 2. This build's main.dart.js.
sed -i "s|\"main\.dart\.js\"|\"main.dart.js?v=$ID\"|g" "$WEB/flutter_bootstrap.js"

# 3. This build's bootstrap.
sed -i "s|src=\"flutter_bootstrap\.js\"|src=\"flutter_bootstrap.js?v=$ID\"|" "$WEB/index.html"

# Refuse to ship a half-rewritten app: every rewrite must have landed.
grep -q "assetBase:\"v/$ID/\"" "$WEB/flutter_bootstrap.js" || { echo "cache-bust: assetBase not injected" >&2; exit 1; }
grep -q "main.dart.js?v=$ID" "$WEB/flutter_bootstrap.js"   || { echo "cache-bust: main.dart.js not versioned" >&2; exit 1; }
grep -q "flutter_bootstrap.js?v=$ID" "$WEB/index.html"      || { echo "cache-bust: bootstrap not versioned" >&2; exit 1; }

echo "==> Cache-busted web build as v/$ID"
