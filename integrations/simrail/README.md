# SimRail integration

SimRail has no external API. `TreninoBridge/` is a MelonLoader mod that runs inside the
game and exposes the player train's controls and readouts over HTTP + WebSocket. The
Trenino SimRail connector talks to this API.

Start with [FINDINGS.md](FINDINGS.md): how SimRail models trains, and the pitfalls each
train taught us. Per-train data lives in `profiles/`, `sweeps/` and `recordings/`.

## Installing the bridge (developer setup)

1. Install MelonLoader 0.7.3+ into the SimRail folder (`version.dll` + `MelonLoader\`).
2. In `SimRail\UserData\Loader.cfg` set:
   - `version_override = "2023.1.8f1"` (MelonLoader cannot detect SimRail's Unity version)
   - `force_il2cpp_dumper_version = "2022.1.0-pre-release.21"` (older Cpp2IL misreads the
     game binary; if switching versions, delete `MelonLoader\Dependencies\Il2CppAssemblyGenerator\Cpp2IL`
     and `Config.cfg` there so it re-downloads)
3. Start SimRail once so MelonLoader generates `MelonLoader\Il2CppAssemblies`.
4. `dotnet build -c Release` in `TreninoBridge/` (net6.0) builds and copies
   `TreninoBridge.dll` into `SimRail\Mods` (the running game locks it — quit first).
5. `dotnet build -c Release` in `TreninoInteropGuard/` copies `TreninoInteropGuard.dll`
   into `SimRail\Plugins`. **Required.** MelonLoader's Il2CppInterop (1.5.1) hooks the wrong
   function as `Class::GetDefaultFieldValue` on SimRail's Unity 2023.1 build: its "V Rising"
   signature matches 9 functions and it takes the first, which is generated game code. The game
   then dies with an `ExecutionEngineException` in `Class_GetFieldDefaultValue_Hook` on an
   IL2CPP threadpool thread, typically when trains are handed to the train server
   ([BepInEx/Il2CppInterop#284](https://github.com/BepInEx/Il2CppInterop/issues/284)). This
   happens with no mods loaded at all. The guard re-checks Il2CppInterop's pick before the
   hook is installed and swaps in the one signature hit that `il2cpp_field_static_get_value`
   actually calls; its log line says which. It must be a plugin: by the time mods load, the
   hook is in place. The bridge logs an error and reports `interopGuard: false` in `/status`
   when the guard is missing. Tests: `dotnet test TreninoInteropGuard.Tests` (checks the
   resolver against the installed `GameAssembly.dll`; rerun after a SimRail update).

Settings (`SimRail\UserData\MelonPreferences.cfg`, `[TreninoBridge]`): `Port` (31275),
`ListenOnNetwork` (true), `Token` (generated on first run, never logged).

## API v1

One port serves HTTP/1.1 and a WebSocket. Values are floats addressed by **path**
`Group.field` (e.g. `Physics_Input_EN57.maincontroller_a`). Booleans are 0/1.

### Auth
- Requests from loopback with a literal loopback `Host` (`127.0.0.1:31275`,
  `localhost:31275`, `[::1]:31275`), no `Origin` and no cross-site `Sec-Fetch-Site` are
  trusted (local apps).
- Everything else — other computers, anything a browser sends — needs the token:
  `Authorization: Bearer <token>` or `?token=<token>`. Otherwise 401.

### HTTP
| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/api/v1/status` | | `{ok, api, bridge, inTrain, generation, interopGuard}` |
| GET | `/api/v1/vehicle` | | schema (below); 409 when not in a train |
| GET | `/api/v1/values?paths=a,b.*` | | `{path: value}`; all values without `paths` |
| PUT | `/api/v1/values/{path}` | `{"value": 2}` | `{path, value, syncedControls}` |
| PUT | `/api/v1/controls/{id}` | `{"position": 3}` | same; uses the game's value for that position |
| GET | `/api/v1/dump` | | schema + all values + raw control properties (research) |

Errors: `{"error": "..."}` with 400/401/404/405/408/409/413/431/500.

Every write also updates the cab controls bound to that path (the game's own
`SetStateFromPhysics`), so keyboard/mouse input continues from the written position.

### WebSocket `/api/v1/stream`
JSON text messages. Requests may carry an `id`, echoed in the reply as
`{"id", "ok": true, ...}` or `{"id", "ok": false, "status", "error"}`.

| Client → server | Reply |
|---|---|
| `{"op":"subscribe","paths":["Physics_Input_EN57.*","Physics_Output_EN57.velocity"],"maxHz":30}` | `{"values": {...current...}}` |
| `{"op":"unsubscribe","paths":[...]}` | |
| `{"op":"get","paths":[...]}` | `{"values": {...}}` |
| `{"op":"set","path":"Group.field","value":1}` | `{"result": {path, value, syncedControls}}` |
| `{"op":"setControl","control":"<id>","position":2}` | `{"result": {...}}` |
| `{"op":"vehicle"}` | `{"vehicle": schema}` |

Server pushes:
- `{"op":"hello","api":"1","bridge":"0.2.0"}` on connect
- `{"op":"vehicle","vehicle": schema | null}` on connect and whenever the player's vehicle
  changes (re-resolve everything; old paths may not exist)
- `{"op":"values","t": unixMs,"values": {path: value}}` — only **changed** subscribed values,
  at most `maxHz` (1–120, default 30) per client. Patterns: exact path, `Group.*`, `*`.

### Vehicle schema
```jsonc
{
  "generation": 3,                       // changes whenever the player vehicle changes
  "vehicle": { "name": "4e/eu07-193", "type": "Locomotive", ... },
  "groups": [ { "name": "Physics_Input_General", "kind": "input", "fields": ["drive_handle", ...] } ],
  "controls": [
    {
      "id": "…/kran_fv4a/hamulec_zasadniczy/hamulec_zasadniczy",  // hierarchy path in the vehicle
      "type": "PhysicsInteractionLeverSmoothNotchBased",
      "kind": "lever",                   // lever | switch | button | flap | decor | other
      "path": "Physics_Input_General.main_brake",   // null when unbound
      "position": 6,                     // the control's own current position index
      "positions": [                     // notch table; empty for push buttons
        { "index": 1, "value": 7, "lower": 7.5, "upper": 6.5 },   // smooth band
        { "index": 4, "value": 5, "stable": 5 }                   // stable != index → springs back
      ],
      "button": { "pressed": 1, "released": -1 },   // push buttons only
      "actions": ["Release train brake", "Fasten train brake"] // SimRail input actions
    }
  ]
}
```
Notch tables are **per control**: the same path can have different tables in each cab.

## Research tools
- `capture-profile.ps1 [-Name X] [-BaseUrl ...]` → `profiles/<vehicle>.json` (dump, verbatim).
- `record-session.mjs [name] [--url ws://…] [--token T]` → `recordings/<vehicle>-<time>.jsonl`;
  first line schema, then the full initial state, then `{t, values}` changes (20 Hz).
- `sweep-controls.mjs [label] [--only p1,p2] [--skip p1,p2] [--settle ms] [--no-restore]` →
  `sweeps/<vehicle>-<label>.json`: steps every bound control through its positions and
  records which values react (`changes`); other inputs that moved meanwhile go to
  `concurrentInputs` (someone operating the cab). Keep hands off the cab while it runs. **Run only on a freshly loaded train** — sweeps can latch
  states (see FINDINGS). Skip trip controls (`emergency_brake_button_flag`,
  `assimilation_button`) and start-up controls when sweeping a live train.
