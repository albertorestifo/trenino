// Records every IO value change from the TreninoBridge stream to a JSONL file.
//
//   node integrations/simrail/record-session.mjs [name] [--url ws://127.0.0.1:31275/api/v1/stream] [--token T]
//
// Drive normally (or operate one control at a time); press Ctrl+C to stop.
// Each line: {"t":unixMs,"values":{path:value}}; the first lines are the vehicle
// schema and the full initial state. Requires Node 22+ (built-in WebSocket).
import { createWriteStream, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
const opt = (flag, fallback) => {
  const i = args.indexOf(flag);
  return i >= 0 ? args.splice(i, 2)[1] : fallback;
};
const url = opt("--url", "ws://127.0.0.1:31275/api/v1/stream");
const token = opt("--token", undefined);
const name = args[0];

const dir = join(dirname(fileURLToPath(import.meta.url)), "recordings");
mkdirSync(dir, { recursive: true });

let out;
let changes = 0;
const ws = new WebSocket(token ? `${url}?token=${encodeURIComponent(token)}` : url);

let generation = -1;

ws.onopen = () => ws.send(JSON.stringify({ id: "veh", op: "vehicle" }));

ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id === "veh") {
    if (!msg.ok) console.log(`waiting for a train (${msg.error})`);
    else msg.op = "vehicle"; // same shape as the pushed event
  }
  if (msg.op === "vehicle" && msg.vehicle && msg.vehicle.generation !== generation) {
    generation = msg.vehicle.generation;
    out?.end();
    const vehicleName = (name ?? msg.vehicle.vehicle.name ?? "vehicle").replace(/[^A-Za-z0-9_.-]/g, "_");
    const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
    const file = join(dir, `${vehicleName}-${stamp}.jsonl`);
    out = createWriteStream(file);
    out.write(JSON.stringify({ t: Date.now(), vehicle: msg.vehicle }) + "\n");
    ws.send(JSON.stringify({ id: "rec", op: "subscribe", paths: ["*"], maxHz: 20 }));
    console.log(`recording ${msg.vehicle.vehicle.name} -> ${file}`);
  } else if (msg.id === "rec" && msg.ok) {
    out?.write(JSON.stringify({ t: Date.now(), initial: true, values: msg.values }) + "\n");
  } else if (msg.op === "values") {
    out?.write(JSON.stringify({ t: msg.t, values: msg.values }) + "\n");
    changes += Object.keys(msg.values).length;
  }
};
ws.onerror = (e) => console.error("websocket error:", e.message ?? e);
ws.onclose = () => { out?.end(); console.log(`closed after ${changes} value changes`); process.exit(0); };

process.on("SIGINT", () => { console.log(`\nstopping (${changes} value changes)`); ws.close(); });
