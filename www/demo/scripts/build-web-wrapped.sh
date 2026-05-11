#!/usr/bin/env bash
# Build the Flutter web app under /app/ and place an iframe wrapper at the
# root. SST uploads build/wrap/ to the demo's S3 bucket.
#
# See wrap/index.html for the explanation of why the iframe wrapper exists
# (flutter#186317 workaround).

set -euo pipefail

# 1. Build Flutter with base href /app/ so all asset URLs resolve under
#    https://workbench.genuiform.draht.dev/app/.
flutter build web --release --wasm --base-href=/app/

# 2. Assemble the wrap directory: root index.html is the iframe wrapper,
#    the Flutter app lives under /app/.
rm -rf build/wrap
mkdir -p build/wrap/app
cp -r build/web/. build/wrap/app/
cp wrap/index.html build/wrap/index.html
