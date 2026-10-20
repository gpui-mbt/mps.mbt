#!/usr/bin/env node
// Loads the browser viewer in headless Chrome and saves a screenshot.
//
// Usage: node tools/screenshot.mjs <url> <out.png> [waitMs]
// Set CHROME_PATH to override the browser binary.
import { createRequire } from "node:module";

// Playwright is resolved from NODE_PATH when the repository does not install
// it itself; the browser binary comes from CHROME_PATH.
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH || "playwright");

const [url, out, waitMs = "2500"] = process.argv.slice(2);
if (!url || !out) {
  console.error("usage: node tools/screenshot.mjs <url> <out.png> [waitMs]");
  process.exit(2);
}

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome",
  args: ["--no-sandbox", "--use-gl=swiftshader"],
});
const page = await browser.newPage({ viewport: { width: 1040, height: 760 } });
const problems = [];
page.on("console", (message) => {
  if (message.type() === "error") {
    problems.push(message.text());
  }
});
page.on("pageerror", (error) => problems.push(String(error)));
await page.goto(url, { waitUntil: "networkidle" });
await page.waitForTimeout(Number(waitMs));
const status = await page.textContent(".status");
await page.screenshot({ path: out });
await browser.close();
console.log(status?.replace(/\s+/g, " ").trim());
if (problems.length > 0) {
  console.error(problems.join("\n"));
  process.exit(1);
}
