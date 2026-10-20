// Page side of the browser viewer.
//
// The MoonBit module prints one FRAME line per step through its only import,
// `spectest.print_char`. Each page load runs a short slice of the demo at full
// speed (a few hundred steps, well under a second), draws it back in real time
// at 60 frames per second, and then instantiates the module again with the
// next continuation step. The simulation is deterministic, so the slices join
// seamlessly and the page never blocks on one long run.

const MODULE_URL = "../_build/wasm-gc/release/build/bridge/bridge.wasm";
// Wall-clock seconds per rendered frame.
const FRAME_SECONDS = 1 / 60;

const canvas = document.getElementById("canvas");
const context = canvas.getContext("2d");
const fields = new Map();
for (const element of document.querySelectorAll(".status [data-field]")) {
  fields.set(element.dataset.field, element);
}
const errorBox = document.getElementById("error");

let slices = [];
let playing = 0;
let lastDraw = 0;
let startStep = 0;
let stopped = false;

function parseFrame(line) {
  const parts = line.split("\t");
  if (parts.length < 9 || parts[0] !== "FRAME") {
    return null;
  }
  const pairs = parts[8].split(" ");
  const count = Number.parseInt(pairs[0], 10);
  const xs = new Float32Array(count);
  const ys = new Float32Array(count);
  for (let i = 0; i < count; i += 1) {
    xs[i] = Number.parseFloat(pairs[i * 2 + 1]);
    ys[i] = Number.parseFloat(pairs[i * 2 + 2]);
  }
  return {
    step: Number.parseInt(parts[1], 10),
    time: Number.parseFloat(parts[2]),
    width: Number.parseFloat(parts[3]),
    height: Number.parseFloat(parts[4]),
    maxPressure: Number.parseFloat(parts[5]),
    maxSpeed: Number.parseFloat(parts[6]),
    status: parts[7],
    xs,
    ys,
  };
}

async function runSlice(fromStep) {
  const response = await fetch(MODULE_URL);
  if (!response.ok) {
    throw new Error(`cannot load the module: HTTP ${response.status}`);
  }
  const bytes = await response.arrayBuffer();
  const lines = [];
  let chars = [];
  const { instance } = await WebAssembly.instantiate(bytes, {
    spectest: {
      print_char: (codePoint) => {
        if (codePoint === 10) {
          if (chars.length > 0) {
            lines.push(chars.map((c) => String.fromCodePoint(c)).join(""));
            chars = [];
          }
        } else {
          chars.push(codePoint);
        }
      },
    },
  });
  // The module exports the session entry; the page passes the continuation and
  // collects the FRAME lines the run prints.
  instance.exports.mps_session(fromStep);
  instance.exports.mps_run();
  if (chars.length > 0) {
    lines.push(chars.map((c) => String.fromCodePoint(c)).join(""));
  }
  return lines.map(parseFrame).filter(Boolean);
}

function draw(frame) {
  const width = canvas.width;
  const height = canvas.height;
  const scale = Math.min(width / frame.width, height / frame.height);
  const offsetX = (width - frame.width * scale) * 0.5;
  const offsetY = (height - frame.height * scale) * 0.5;

  context.fillStyle = "#0b1018";
  context.fillRect(0, 0, width, height);
  context.fillStyle = "#16202c";
  context.fillRect(offsetX, height - offsetY - frame.height * scale, frame.width * scale, frame.height * scale);

  const speed = Math.min(frame.maxSpeed / 2.5, 1);
  // One particle covers about one particle spacing; keep it at least 3 px so a
  // small canvas still reads as water.
  const size = Math.max(3, scale * 0.011);
  for (let i = 0; i < frame.xs.length; i += 1) {
    const depth = 1 - Math.min(Math.max(frame.ys[i] / frame.height, 0), 1);
    const r = 40 + 60 * speed;
    const g = 70 + 90 * speed;
    const b = 200 - 40 * depth + 40 * speed;
    context.fillStyle = `rgb(${r | 0},${g | 0},${b | 0})`;
    const x = offsetX + frame.xs[i] * scale;
    const y = height - (offsetY + frame.ys[i] * scale);
    context.fillRect(x, y - size, size, size);
  }

  fields.get("time").textContent = `t ${frame.time.toFixed(3)} s`;
  fields.get("step").textContent = `step ${frame.step}`;
  fields.get("particles").textContent = `${frame.xs.length} particles`;
  fields.get("speed").textContent = `vmax ${frame.maxSpeed.toFixed(3)} m/s`;
  const status = fields.get("status");
  status.textContent = frame.status;
  status.classList.toggle("ready", frame.status === "ok");
}

function tick(now) {
  if (stopped || slices.length === 0) {
    return;
  }
  if (lastDraw === 0) {
    lastDraw = now;
  }
  // Advance by wall-clock time, at least one frame per repaint.
  const advance = Math.max(1, Math.round(((now - lastDraw) / 1000) * 60));
  lastDraw = now;
  playing = Math.min(slices.length - 1, playing + advance);
  draw(slices[playing]);
  if (playing >= slices.length - 1) {
    requestAnimationFrame(playNext);
    return;
  }
  requestAnimationFrame(tick);
}

async function playNext() {
  if (stopped) {
    return;
  }
  startStep = slices.length > 0 ? slices[slices.length - 1].step : startStep;
  slices = [];
  playing = 0;
  lastDraw = 0;
  try {
    slices = await runSlice(startStep);
  } catch (error) {
    showError(String(error?.message ?? error));
    return;
  }
  if (slices.length === 0) {
    fields.get("status").textContent = "finished";
    return;
  }
  requestAnimationFrame(tick);
}

function showError(message) {
  errorBox.hidden = false;
  errorBox.textContent = message;
  fields.get("status").textContent = "error";
  stopped = true;
}

playNext();
