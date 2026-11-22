// Steps every IO-bound cab control of the current SimRail train through its positions,
// records which values react, then restores it. Writes integrations/simrail/sweeps/<vehicle>-<label>.json.
//
//   node integrations/simrail/sweep-controls.mjs [label] [--url ws://127.0.0.1:31275/api/v1/stream]
//        [--only path1,path2] [--skip path1,path2] [--settle 1200] [--no-restore]
//
// Values that change on their own (clocks, battery current noise...) are measured
// for a few seconds first and reported separately, so diffs show real reactions.
// Some controls are never touched (cab change, couplers, failures, crash reset).
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
const opt = (flag, fallback) => { const i = args.indexOf(flag); return i >= 0 ? args.splice(i, 2)[1] : fallback; };
const has = (flag) => { const i = args.indexOf(flag); if (i >= 0) args.splice(i, 1); return i >= 0; };
const url = opt("--url", "ws://127.0.0.1:31275/api/v1/stream");
const only = opt("--only", null)?.split(",");
const skip = new Set(opt("--skip", "").split(",").filter(Boolean)); // e.g. keep start-up controls untouched
const settleMs = Number(opt("--settle", "1200"));
const restore = !has("--no-restore");
const label = args[0] ?? "sweep";

const NEVER_TOUCH = /change_cabin|driver_coupler|failure_|reset_crash|quit|error_code|traindata_|passengers_multipler|wire_ice|friction_factor/i;
const EPS = 1e-3;

const ws = new WebSocket(url);
const state = {};
let nextId = 1;
const pending = new Map();
const call = (msg) => new Promise((resolve) => { const id = nextId++; pending.set(id, resolve); ws.send(JSON.stringify({ ...msg, id })); });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  if (msg.op === "values") Object.assign(state, msg.values);
  if (msg.values && msg.ok) Object.assign(state, msg.values);
};

ws.onopen = async () => {
  try { await run(); } catch (e) { console.error(e); }
  ws.close();
};

async function run() {
  const veh = await call({ op: "vehicle" });
  if (!veh.ok) throw new Error(veh.error);
  const schema = veh.vehicle;
  await call({ op: "subscribe", paths: ["*"], maxHz: 60 });

  // 1. Measure values that move on their own.
  console.log("measuring background noise for 3 s...");
  const base = { ...state };
  const noisy = new Set();
  const t0 = Date.now();
  while (Date.now() - t0 < 3000) {
    await sleep(100);
    for (const [k, v] of Object.entries(state)) if (Math.abs(v - base[k]) > EPS) noisy.add(k);
  }

  // 2. One target per bound path (both cabs often share a field).
  const byPath = new Map();
  for (const c of schema.controls) {
    if (!c.path || c.kind === "decor" || NEVER_TOUCH.test(c.path)) continue;
    if (only && !only.includes(c.path)) continue;
    if (skip.has(c.path)) continue;
    if (!byPath.has(c.path)) byPath.set(c.path, c);
  }

  const results = [];
  const total = byPath.size;
  let n = 0;
  for (const [path, control] of byPath) {
    n++;
    const original = state[path];
    const positions = (control.positions ?? []).filter((p) => p.value != null);
    const targets = positions.length
      ? positions.map((p) => ({ position: p.index, value: p.value, label: p.label || undefined }))
      : [{ value: original === 1 ? 0 : 1 }];
    const steps = [];
    process.stdout.write(`[${n}/${total}] ${path} (${control.kind}, ${targets.length} targets) `);

    for (const target of targets) {
      if (Math.abs(target.value - original) < EPS) continue;
      const before = { ...state };
      const reply = target.position != null
        ? await call({ op: "setControl", control: control.id, position: target.position })
        : await call({ op: "set", path, value: target.value });
      await sleep(settleMs);
      const changes = {};
      for (const [k, v] of Object.entries(state)) {
        if (k === path || noisy.has(k)) continue;
        if (Math.abs(v - (before[k] ?? v)) > EPS) changes[k] = [round(before[k]), round(v)];
      }
      steps.push({ ...target, ok: reply.ok, error: reply.error, readback: round(state[path]), changes });
      process.stdout.write(reply.ok ? "." : "x");
    }

    if (restore && original != null && Math.abs(state[path] - original) > EPS) {
      await call({ op: "set", path, value: original });
      await sleep(Math.min(settleMs, 800));
    }
    results.push({ path, controlId: control.id, type: control.type, kind: control.kind, original: round(original), positions, steps });
    console.log("");
  }

  const dir = join(dirname(fileURLToPath(import.meta.url)), "sweeps");
  mkdirSync(dir, { recursive: true });
  const name = `${schema.vehicle.name.replace(/[^A-Za-z0-9_.-]/g, "_")}-${label}.json`;
  const file = join(dir, name);
  writeFileSync(file, JSON.stringify({ vehicle: schema.vehicle, settleMs, noisy: [...noisy].sort(), initialState: base, results }, null, 1));
  const reacting = results.filter((r) => r.steps.some((s) => Object.keys(s.changes).length)).length;
  console.log(`\n${results.length} controls swept, ${reacting} caused other values to change -> ${file}`);
}

function round(v) { return v == null ? v : Math.round(v * 1000) / 1000; }
