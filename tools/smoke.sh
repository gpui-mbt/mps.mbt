#!/bin/sh
# Cross-backend gate: the native terminal host and the wasm-gc browser module
# run the same steps and must print byte-identical FRAME lines.
#
# Usage: tools/smoke.sh [steps]
set -eu
cd "$(dirname "$0")/.."
steps="${1:-300}"
node="${NODE:-node}"
work=".work/smoke"
mkdir -p "$work"

moon build --release --target native
moon build --release --target wasm-gc

./_build/native/release/build/cmd/terminal/terminal.exe --steps "$steps" > "$work/native.txt"
"$node" tools/run-wasm.mjs _build/wasm-gc/release/build/bridge/bridge.wasm > "$work/wasm-all.txt"
# The browser module prints only the session's own frames; the native host also
# prints the initial state as frame 0, which is dropped here so both sides start
# at step 1.
sed -n "1,${steps}p" "$work/wasm-all.txt" > "$work/wasm.txt"
tail -n "+2" "$work/native.txt" > "$work/native-only.txt"
mv "$work/native-only.txt" "$work/native.txt"

if cmp -s "$work/native.txt" "$work/wasm.txt"; then
  echo "smoke: native and wasm-gc produced identical output ($((steps + 1)) frames)"
else
  echo "smoke: native and wasm-gc output differs" >&2
  diff -u "$work/native.txt" "$work/wasm.txt" 2>/dev/null | cut -c1-160 | head -20 >&2 || true
  exit 1
fi
