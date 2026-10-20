#!/usr/bin/env node
// Runs a wasm-gc build of the demo in Node exactly as a browser would: the
// module imports only `spectest.print_char`, and the collected characters are
// written to standard output. No Node-specific APIs are used beyond reading
// the module file, which keeps the execution path identical to the page.
import { readFile } from "node:fs/promises";

const path = process.argv[2];
if (!path) {
  console.error("usage: node tools/run-wasm.mjs <module.wasm>");
  process.exit(2);
}

const bytes = await readFile(path);
const chunks = [];
const { instance } = await WebAssembly.instantiate(bytes, {
  spectest: {
    print_char: (codePoint) => chunks.push(codePoint),
  },
});
instance.exports._start();
process.stdout.write(chunks.map((c) => String.fromCodePoint(c)).join(""));
