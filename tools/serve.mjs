#!/usr/bin/env node
// Minimal static server for the browser viewer.
//
// Serves the repository root so `web/index.html` can read the wasm build under
// `_build/`. No dependencies, no caching: one process, one port.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";

const root = resolve(process.argv[3] ?? ".");
const port = Number(process.argv[2] ?? 8080);
const types = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".wasm", "application/wasm"],
  [".json", "application/json"],
]);

createServer(async (request, response) => {
  const url = new URL(request.url ?? "/", "http://localhost");
  let path = decodeURIComponent(url.pathname);
  if (path.endsWith("/")) {
    path += "index.html";
  }
  const target = normalize(join(root, path));
  if (!target.startsWith(root)) {
    response.writeHead(403).end("forbidden");
    return;
  }
  try {
    const info = await stat(target);
    if (!info.isFile()) {
      response.writeHead(404).end("not found");
      return;
    }
    const body = await readFile(target);
    response.writeHead(200, {
      "content-type": types.get(extname(target)) ?? "application/octet-stream",
      "cache-control": "no-store",
    });
    response.end(body);
  } catch {
    response.writeHead(404).end("not found");
  }
}).listen(port, "127.0.0.1", () => {
  console.log(`serving ${root} at http://127.0.0.1:${port}/web/`);
});
