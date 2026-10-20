#!/bin/sh
# Cross-backend gate: the native terminal host and the wasm-gc browser host run
# the same steps and must print byte-identical FRAME lines.
#
# Usage: tools/smoke.sh [steps]
set -eu
cd "$(dirname "$0")/.."
steps="${1:-60}"
node="${NODE:-node}"
work=".work/smoke"
mkdir -p "$work"

moon build --release --target native
moon build --release --target wasm-gc

./_build/native/release/build/cmd/terminal/terminal.exe --steps "$steps" > "$work/native.txt"
"$node" tools/run-wasm.mjs _build/wasm-gc/release/build/cmd/dam_break/dam_break.wasm > "$work/wasm-all.txt"
# The browser module always runs its full demo; keep the same number of frames.
head -n "$((steps + 1))" "$work/wasm-all.txt" > "$work/wasm.txt"

if cmp -s "$work/native.txt" "$work/wasm.txt"; then
  echo "smoke: native and wasm-gc produced identical output ($((steps + 1)) frames)"
else
  echo "smoke: native and wasm-gc output differs" >&2
  diff -u "$work/native.txt" "$work/wasm.txt" | head -40 >&2 || true
  exit 1
fi
