# HTTP API and MCP contract

This records the implementation at baseline `188f35e4108733358730e92ebd98f1912af5173a`, including inconsistencies useful to a rewrite. It describes local application interfaces, not the upstream Train Sim World HTTP protocol. Domain validation and runtime behavior are detailed in [hardware](hardware.md), [simulator](simulator.md), [train controls](train-profiles-and-controls.md), [scripts and sequences](scripting-and-sequences.md), and [virtual joystick](virtual-joystick.md). [Interface stories](interface-user-stories.md) give acceptance scenarios.

## Reachability and security boundaries

The router exposes browser LiveViews, JSON HTTP endpoints and SSE MCP on the same Phoenix endpoint. There is no application user/login/account system, API token check, MCP authorization middleware, or consent check in the API/MCP scopes. The simulator API key is for the app's upstream simulator connection; it is not an incoming API credential. The browser pipeline accepts HTML, fetches a signed cookie session and flash, installs the root layout, CSRF protection and secure browser headers. The API pipeline only accepts JSON. MCP routes have no pipeline declaration. Thus the first-run consent hook protects only the default LiveView session; it does not protect `/api/*`, `/mcp/*`, `/consent`, or the legacy redirect.

The endpoint parses URL-encoded, multipart and JSON bodies; JSON uses Jason. `_trenino_key` is a signed, unencrypted cookie with `same_site: Lax`. `/live` supports websocket and longpoll with session connect information. Static files come from `priv/static` for assets/fonts/images/favicon/robots. These are local operator interfaces, not a multi-tenant authorization contract. Sources: [router](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/router.ex), [endpoint](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/endpoint.ex), [web macros](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web.ex), [consent hook](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/consent_gate_hook.ex).

## JSON HTTP endpoints

Success responses below are HTTP 200 unless another status is specified. JSON map keys are strings on the wire. IDs in URL segments are converted with `String.to_integer/1`; malformed numeric IDs are not normalized to a documented 400 response and can raise. Lists do not provide pagination, filters, sorting parameters, version negotiation or cursor metadata. There are no HTTP train/element/output-binding/display-binding/sequence mutation routes or HTTP virtual-joystick routes.

| Method and route | Request | Success response | Explicit failure behavior |
| --- | --- | --- | --- |
| `GET /api/health` | None | `{status:"ok"}` after a query against the firmware releases table succeeds, even if the table is empty | 503 `{status:"unavailable",reason:"migrations_pending"}` for `Ecto.QueryError`, `database_unavailable` for `DBConnection.ConnectionError`, otherwise `unknown` |
| `POST /api/shutdown` | None | `{status:"shutting_down"}`; schedules `System.stop(0)` in a task after 100 ms | No controller-level failure mapping; this really terminates the backend |
| `GET /api/trains` | None | `{trains:[{id,name,identifiers,description}]}` | No explicit error branch |
| `GET /api/trains/:id` | Integer ID | `{train:{id,name,identifiers,description,elements:[{id,name,type}],output_bindings:[{id,name,endpoint,operator,output_id}]}}` | 404 `{error:"not found"}` |
| `GET /api/trains/:train_id/scripts` | Integer train ID (Phoenix internal parameter is `train_api_id`) | `{scripts:[ScriptHTTP]}` with full code | No parent-train lookup; missing train normally gives an empty list |
| `POST /api/trains/:train_id/scripts` | Flat JSON body with `name`, `code`; optional `enabled`, `triggers` | 201 `{script:ScriptHTTP}` and explicit `ScriptRunner.reload_scripts()` | 422 `{errors:{field:[message,...]}}` from the changeset |
| `GET /api/scripts/:id` | Integer script ID | `{script:ScriptHTTP}` | 404 `{error:"not found"}` |
| `PUT /api/scripts/:id` and `PATCH /api/scripts/:id` | Any provided subset of `name`, `enabled`, `code`, `triggers` in a flat body | `{script:ScriptHTTP}`, explicit runner reload | 404 missing script; 422 field errors |
| `DELETE /api/scripts/:id` | Integer script ID | `{ok:true}`, explicit runner reload | 404 missing script; deletion internally pattern-matches success rather than mapping a changeset error |
| `GET /api/outputs` | None | `{outputs:[{id,name,pin,device_name,device_id}]}` across saved hardware configurations | No explicit failure branch or connection filtering |
| `GET /api/simulator/endpoints` | Optional query `path`; omitted means root (`nil` passed upstream) | Upstream `SimulatorClient.list` data verbatim | 503 `{error:"simulator not connected"}` unless connected with non-nil client; 502 `{error:inspect(reason)}` on upstream failure |
| `GET /api/simulator/value` | Required query `path` | Upstream `SimulatorClient.get` data verbatim | 400 `{error:"path parameter required"}`; same 503/502 mapping |

`ScriptHTTP = {id,train_id,name,enabled,code,triggers,inserted_at,updated_at}`. Unknown script body fields are discarded. `triggers` is an array of endpoint strings. Default script state is enabled with no triggers when omitted. Train responses use the sorted `identifiers` array, never the old singular `identifier`. HTTP train detail is deliberately smaller than MCP train detail: it omits button bindings, sequences and output thresholds/enabled flags. Errors from changesets interpolate `%{...}` placeholders before returning lists.

Sources: [health/shutdown](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/health_controller.ex), [train API](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/api/train_api_controller.ex), [script API](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/api/script_controller.ex), [output API](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/api/output_api_controller.ex), [simulator proxy](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/api/simulator_api_controller.ex). Tests: [health](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/health_controller_test.exs), [train serialization](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/api/train_api_controller_test.exs), [script CRUD](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/api/script_controller_test.exs).

Generic endpoint error rendering differs from controller errors: HTML renders the status message (`Not Found`, `Internal Server Error`); JSON renders `{errors:{detail:"Not Found"}}` or the corresponding status message. There is no custom branded error-page workflow. Sources/tests: [ErrorHTML](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/error_html.ex), [ErrorJSON](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/error_json.ex), [HTML tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/error_html_test.exs), [JSON tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/error_json_test.exs).

## MCP SSE transport and JSON-RPC lifecycle

1. Connect `GET /mcp/sse`. The request process registers a random 16-byte, URL-safe Base64 session ID in `Trenino.MCP.SessionRegistry` and starts HTTP 200 chunked streaming. Headers are `content-type: text/event-stream`, `cache-control: no-cache`, `connection: keep-alive`, `access-control-allow-origin: *`.
2. The first event is `event: endpoint` with the absolute `POST /mcp/messages?session_id=...` URL as data. Preserve that URL for subsequent messages.
3. POST a JSON-RPC map to that URL. The controller removes `session_id` from merged request params and passes the rest to `Server.handle_message/1`. Both normal replies and protocol errors are sent to the SSE process as `{:mcp_response,response}`. The POST returns HTTP 202 text `accepted`; the actual JSON-RPC response arrives as an SSE `event: message` containing JSON.
4. Missing `session_id` gives HTTP 400 `{error:"session_id parameter required"}`; an unregistered session gives HTTP 404 `{error:"Session not found"}`. These do not require or create an SSE stream.
5. The stream receives responses until `:close` or a chunk write error. There is no implemented heartbeat, idle timeout, replay buffer, event ID, reconnection-resume protocol, session DELETE route, batch request processing or explicit initialization-state enforcement. Registration belongs to the connection process. Tool execution runs synchronously in the POST request; a long detection delays POST acceptance as well as the tool result.

JSON-RPC requests require `jsonrpc:"2.0"` and a `method`; `id` defaults to null and `params` to `{}`. The server still replies to notifications, including `notifications/initialized`, with null ID/result rather than suppressing the reply.

| Method | Result / error |
| --- | --- |
| `initialize` | `{protocolVersion:"2024-11-05",capabilities:{tools:{}},serverInfo:{name:"Trenino",version:<Mix project version>}}`; request params are ignored |
| `notifications/initialized` | `null` result |
| `ping` | `{}` |
| `tools/list` | `{tools:[{name,description,inputSchema}]}` for all 47 tools; no pagination |
| `tools/call` | Requires params with both `name` and `arguments`; delegates by registered name |
| Unsupported method | `{jsonrpc:"2.0",id,error:{code:-32601,message:"Method not found: <method>"}}` |
| Missing tools/call keys | Code `-32602`, message `Invalid params: name and arguments required` |
| Invalid request shape/version | Code `-32600`, message `Invalid request`, null ID |

Normal replies are `{jsonrpc:"2.0",id,result}`. Tool success becomes `result:{content:[{type:"text",text:<encoded result>}]}`: maps/lists are JSON-encoded into the text string, strings pass through, nil becomes `"ok"`. A tool returning `{:error,message}` still gives a normal JSON-RPC result, with `isError:true` and one text content block. Unknown tools use this tool-error shape with `Unknown tool: <name>`, not JSON-RPC method-not-found.

The registry discovers names by calling each module's `tools/0` and dispatches the first matching module. It does **not** validate inputSchema. Most modules pattern-match required keys, convert enum strings with `String.to_existing_atom/1`, and rely on Ecto changesets. Missing keys, unexpected types, unknown atoms or invalid JSON command strings can raise rather than return structured validation errors. VirtualJoystickTools is the exception, with explicit strict validation. Treat schemas as client guidance, not a generic server-side validator.

Sources: [MCP controller](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/controllers/mcp/mcp_controller.ex), [server](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/server.ex), [registry](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tool_registry.ex). Tests verify POST session failures and delivery, protocol results/errors, unique schemas and the exact count: [controller](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino_web/controllers/mcp/mcp_controller_test.exs), [server](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/server_test.exs), [registry](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tool_registry_test.exs). The existing [setup guide](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/docs/mcp-setup.md) describes SSE at `http://localhost:4000/mcp/sse`, Claude configuration and illustrative workflows, but its stated count of 37 omits the ten joystick tools. Source/test count is 47. Its examples do not add a simulator-detection MCP tool or train-creation tool.

## MCP argument and result notation

Below `int`, `number`, `string`, `bool`, `array` refer to JSON types. `?` means optional. No-argument tools take `{}`. All CRUD tool errors use `Validation failed: field message; ...` for handled changesets, unless specified otherwise. Lists normally return empty arrays when there are no matching child records; they are not existence checks for the parent. Database IDs (`device_id`, `input_id`, etc.) are distinct from hardware configuration IDs, ports, physical pins and matrix virtual pins.

### SimulatorTools — 3 tools

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `list_simulator_endpoints` | `path?:string` (default nil; omit/empty for root) | Upstream API tree unchanged; nodes are navigated with `/`, endpoint names appended with `.` |
| `get_simulator_value` | `path:string` | Upstream read response unchanged |
| `set_simulator_value` | `path:string,value:<untyped schema>` (description allows number/string/bool) | Writes live simulator value and returns upstream result unchanged |

Path example: `CurrentDrivableActor/AWS.Function.IsWarningSound`. All require runtime `status:connected` and a non-nil client; otherwise tool error `Simulator not connected. Ensure Train Sim World is running with External Interface enabled.` Upstream failures are `Simulator error: <inspect(reason)>`. There is no extra endpoint-write permission prompt in MCP. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/simulator_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/simulator_tools_test.exs).

### TrainTools — 2 tools

| Tool | Arguments | Result |
| --- | --- | --- |
| `list_trains` | `{}` | `{trains:[{id,name,identifiers,description}]}` |
| `get_train` | `train_id:int` | `{train:{id,name,identifiers,description,elements:[{id,name,type}],output_bindings:[OutputBinding],button_bindings:[ButtonBinding],sequences:[SequenceBrief]}}` |

`OutputBinding` here has `id,name,endpoint,operator,output_id,value_a,value_b,enabled` (no train ID). `ButtonBinding` is the full shape specified below. `SequenceBrief` has `id,name,commands:[Command]` (no train ID). Missing train is `Train not found with id <id>`. Lever configuration/notches/input mappings, scripts and display bindings are not included in `get_train`; separate tools cover scripts/displays and no lever-config CRUD MCP tools exist. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/train_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/train_tools_test.exs).

### ElementTools — 3 tools

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `list_elements` | `train_id:int` | `{elements:[{id,name,type}]}` |
| `create_element` | `train_id:int,name:string,type:string` enum `button`/`lever` | `{element:{id,name,type}}`; creates the logical control only, no hardware binding |
| `delete_element` | `id:int` | `{deleted:true,id}`; deletes element and associated binding/configuration through the domain |

Missing deletion target: `Element not found with id <id>`. Blank names/invalid existing-atom enum values are changeset errors; arbitrary enum strings can fail at atom conversion. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/element_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/element_tools_test.exs).

### DeviceTools — 7 tools

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `list_devices` | `{}` | `{devices:[{id,name}]}` of **saved configurations**. Despite its description, no connection status or connected-only filter is returned |
| `list_device_inputs` | `device_id:int` | `{inputs:[{id,name,pin,input_type}]}`; does not return calibration, device/config ID, sensitivity or debounce |
| `list_hardware_outputs` | `{}` | `{outputs:[{id,name,pin,device_name,device_id}]}` across configurations |
| `list_i2c_modules` | `{}` | `{i2c_modules:[I2CModule]}` across configurations |
| `create_i2c_module` | `device_id:int,module_chip:string` enum `ht16k33`, `i2c_address:string`; `name?:string,brightness?:int` described 0–15, `num_digits?:int` enum 4/8 | `{i2c_module:I2CModule}`; address accepts decimal `112` or hex `0x70` |
| `update_i2c_module` | `id:int`; optional `name:string,brightness:int,num_digits:int` (same advertised bounds) | `{i2c_module:I2CModule}`; cannot update chip/address/display options through this tool |
| `delete_i2c_module` | `id:int` | `{deleted:true,id}` |

`I2CModule = {id,device_id,device_name,name,module_chip,i2c_address,i2c_address_display,brightness,num_digits,display_type,has_dot,align_right,min_value}`. Result uses flattened nested `params` values. Domain defaults are brightness 8, digits 4, fourteen_segment, has_dot false, align_right true, min_value 0.0; name optional/max100, address integer0–255 unique per device, minimum nullable. Address parser accepts decimal or lowercase `0x` prefix; formatted display is e.g. `112 (0x70)` with uppercase hex digits. Address parse failure: `Invalid i2c_address: use decimal (112) or hex (0x70)`. Missing update/delete target: `I2C module not found with id <id>`. Module saves modify stored configuration, not the physical device by themselves; normal apply/runtime workflows still matter.

**Implemented defect:** create/update pass `brightness` and `num_digits` at the top level while the I2C changeset only consumes nested required `params`; the context does not normalize them. The tool also discards any supplied `params`. Therefore the documented create call lacks required embedded params and can fail validation instead of creating a module; updating an existing module can change its name but ignores advertised brightness/digits changes. The normal UI supplies nested params and is the working creation path. The success serializer is documented above as implemented, not as proof this broken create path reaches it. See [hardware](hardware.md). [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/device_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/device_tools_test.exs). The tests cover saved device/input/output listing, not I2C CRUD.

### OutputBindingTools — 4 tools

`OutputBinding = {id,train_id,name,output_id,endpoint,operator,value_a,value_b,enabled}`. Operator enum is exactly `gt,gte,lt,lte,between,eq_true,eq_false`.

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `list_output_bindings` | `train_id:int` | `{output_bindings:[OutputBinding]}` |
| `create_output_binding` | `train_id:int,name:string,output_id:int,endpoint:string,operator:string`; optional `value_a:number,value_b:number,enabled:bool` (default true) | `{output_binding:OutputBinding}`, reloads OutputController bindings |
| `update_output_binding` | `id:int`, any optional create field except train_id | Same result, reloads controller |
| `delete_output_binding` | `id:int` | `{deleted:true,id}`, reloads controller |

Numeric operators require a threshold; `between` also requires the upper threshold; booleans need neither. The MCP surface does not expose `output_type` (the UI supports LED). Missing target: `Output binding not found with id <id>`. Updates pass only supplied attributes; mode-specific clearing/validation comes from the domain. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/output_binding_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/output_binding_tools_test.exs).

### ButtonBindingTools — 4 tools

`ButtonBinding = {id,element_id,input_id,mode,endpoint,on_value,off_value,enabled,hardware_type,keystroke,repeat_interval_ms,on_sequence_id,off_sequence_id}`. Mode enum `simple,momentary,sequence,keystroke`; hardware enum `momentary,latching`. Defaults advertised/used by domain: on 1.0, off 0.0, repeat 100 ms, hardware momentary, enabled true.

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `get_button_binding` | `element_id:int` | `{button_binding:ButtonBinding}` |
| `create_button_binding` | Required `element_id:int,input_id:int,mode:string`; optional `endpoint:string,on_value:number,off_value:number,keystroke:string,on_sequence_id:int,off_sequence_id:int,repeat_interval_ms:int,hardware_type:string` | `{button_binding:ButtonBinding}`, reloads ButtonController |
| `update_button_binding` | Required `element_id:int`; optional all binding configuration fields above except input_id, plus `enabled:bool` | Same result and reload; cannot move to another input through this tool |
| `delete_button_binding` | `element_id:int` | `{deleted:true,element_id}`, reloads controller |

Simple sends on/off on press/release; momentary repeats while held (interval 100–5000 ms); sequence needs a press and/or release sequence (release described for latching controls); keystroke needs a key combination such as `W`/`CTRL+S`. The tool's create schema omits enabled but the executor's whitelist accepts it if sent. A joystick destination conflict on create/enable is a readable tool error: `This input is assigned to the virtual joystick. Remove that mapping before enabling this binding.` There is no replace flag in this direction. Missing target: `No button binding found for element <id>`. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/button_binding_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/button_binding_tools_test.exs).

### SequenceTools — 4 tools

`Sequence = {id,name,train_id,commands:[Command]}`; `Command = {id,position,endpoint,value,delay_ms}`. Input commands are ordered `{endpoint:string,value:number,delay_ms?:int}`; delay defaults 0 and domain range is 0–60000 ms. Position is generated from zero-based input array order, ignoring any supplied position.

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `list_sequences` | `train_id:int` | `{sequences:[Sequence]}` |
| `create_sequence` | `train_id:int,name:string,commands:array<command>` | `{sequence:Sequence}`; executor also accepts omitted commands; empty array creates empty sequence |
| `update_sequence` | `id:int`; optional `name:string,commands:array<command>` | `{sequence:Sequence}`; supplied commands replace **all** existing commands, including clearing with `[]` |
| `delete_sequence` | `id:int` | `{deleted:true,id}`; domain removes button references |

The builder additionally accepts commands as a JSON-encoded string, despite array schema; invalid JSON raises. Missing target: `Sequence not found with id <id>`. Command-save failures are `Failed to set commands: <inspect(reason)>`. Creation and command replacement are separate context calls: a command failure can leave the named sequence behind; name update can persist before a later command failure. No explicit runtime controller reload appears in this module. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/sequence_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/sequence_tools_test.exs).

### ScriptTools — 5 tools

`ScriptSummary = {id,train_id,name,enabled,triggers}`; `Script = ScriptSummary + code`. Unlike HTTP, MCP does not return timestamps.

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `list_scripts` | `train_id:int` | `{scripts:[ScriptSummary]}` without code |
| `get_script` | `id:int` | `{script:Script}` |
| `create_script` | `train_id:int,name:string,code:string`; optional `triggers:array<string>,enabled:bool` | `{script:Script}`; default triggers `[]`, enabled true |
| `update_script` | `id:int`; optional `name,code,triggers,enabled` with same types | `{script:Script}`; omitted/null fields are skipped, false is preserved |
| `delete_script` | `id:int` | `{deleted:true,id}` |

Missing target: `Script not found with id <id>`. Descriptions require Lua `on_change(event)` and simulator endpoint triggers; actual syntax/runtime validation belongs to [scripting](scripting-and-sequences.md). These executors only call the train context: they do **not** explicitly reload ScriptRunner, unlike HTTP and UI saves. A rewrite must decide whether to preserve or remedy that observable propagation gap. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/script_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/script_tools_test.exs).

### DetectionTools — 1 tool

`detect_hardware_input` requires `prompt:string`; optional `input_type:string` enum `button,analog,any`, default any. The executor also accepts an undocumented `timeout_ms` argument, default 60000, used by tests. Unknown input_type strings fall back to any. It generates an 8-byte lowercase hex detection ID, broadcasts `{:detection_request,%{id,type:hardware,prompt}}` on `mcp:detection`, starts InputDetectionSession owned by the request, and blocks receiving its result. Success is `{detected:true,input:{input_id,pin,input_type,name,device_id,device_name,value}}`; timeout is a successful result `{detected:false,reason:"timeout"}`. Both broadcast `{:detection_complete,id}`. Session snapshots saved inputs/connected config-to-port associations at startup, records each port+pin's first event as a fixed baseline, detects any button change or analog absolute change strictly greater than 50, ignores unknown pins and does not refresh that snapshot. It subscribes directly to input PubSub, without itself ensuring ConfigurationManager listening; caller death stops the session. Domain details are in [hardware](hardware.md).

Connected default-session LiveViews show a global modal with the prompt, MCP badge and listening state; it has no cancellation button. Consent page is not subscribed. Completion clears the modal regardless of ID. Calls must be sequential (explicit tool description); no runtime serialization in the tool prevents parallel calls, so overlapping requests can overwrite/clear one another's UI. There is no registered simulator-control-detection MCP tool; simulator control detection belongs to UI wizards. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/detection_tools.ex), [hook](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino_web/live/mcp_detection_hook.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/detection_tools_test.exs).

### DisplayBindingTools — 4 tools

`DisplayBinding = {id,train_id,i2c_module_id,name,endpoint,format_string,enabled}`.

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `list_display_bindings` | `train_id:int` | `{display_bindings:[DisplayBinding]}` |
| `create_display_binding` | `train_id:int,i2c_module_id:int,endpoint:string,format_string:string`; optional `name:string,enabled:bool` | `{display_binding:DisplayBinding}`, reloads DisplayController |
| `update_display_binding` | `id:int`; optional `name,i2c_module_id,endpoint,format_string,enabled` | Same result/reload |
| `delete_display_binding` | `id:int` | `{deleted:true,id}`, reloads controller |

Format tokens are `{value}` and `{value:.Nf}`; supported decimal precision is 0–10 through the formatter/domain. The name is optional in MCP schema, while the UI requires a nonblank name. Missing target: `Display binding not found with id <id>`. [Source](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/display_binding_tools.ex), [tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/display_binding_tools_test.exs). Tests cover tool count and empty list only, not full display CRUD.

### VirtualJoystickTools — 10 tools

All schemas reject additional properties and all executors validate the argument object, required fields and types without raising. `device_index` may only be integer 1 (1.0 rejected). Axis names: `x,y,z,rx,ry,rz,slider_1,slider_2`. Button targets are integers 1–32.

| Tool | Arguments | Result and effects |
| --- | --- | --- |
| `get_virtual_joystick_status` | `{}` | `{status:<runtime status string>,reason:null or Reason}` |
| `list_virtual_joystick_mappings` | `{}` | `{status:"ok",mappings:[Mapping]}` |
| `map_virtual_joystick_axis` | `input_id:int,axis:string`; optional `device_index:int=1,inverted:bool=false,replace:bool=false` | `{status:"ok",reason:null,mapping:Mapping}`; creates or updates by input, reloads mappings |
| `map_virtual_joystick_button` | `input_id:int,button:int`; optional `device_index:int=1,replace:bool=false` | Same success shape/reload |
| `delete_virtual_joystick_mapping` | `id:int` | `{status:"ok",reason:null,deleted:true,id}` |
| `enable_virtual_joystick` | `{}` | Begins enable, returns lifecycle acceptance |
| `disable_virtual_joystick` | `{}` | Begins disable, returns lifecycle acceptance |
| `retry_virtual_joystick` | `{}` | Retries setup/connection |
| `cleanup_virtual_joystick` | `{}` | Calls `remove_leftover` to remove a leftover device |
| `check_virtual_joystick_installation` | `{}` | Calls `repair` to recheck after user driver/configuration repair; tool is **not** named `repair_virtual_joystick` |

`Mapping = {id,input_id,device_index,target_type:"axis"|"button",axis:string|null,button:int|null,inverted:bool}`. Existing simulator/API destinations cause `{status:"error",reason:{code:"destination_conflict"}}`; `replace:true` explicitly moves the input's destination through domain logic. Missing input/mapping is reason `not_found`. Analog inputs must target axes; buttons must target buttons; target uniqueness and remaining validations use Ecto.

All these failures are returned as `{:ok,map}` and encoded into the ordinary content text **without MCP `isError:true`**. Consumers must decode `status:"error"` themselves. Argument validation uses `{status:"error",reason:{code:"validation_failed",errors:[{field,message}]}}`; Ecto validation uses an errors map of field-to-message-lists instead of that array. Reasons are `{code:<atom string>}`, tuples add `details:inspect(details)`, unknown runtime failures become `{code:"runtime_error",details:inspect(reason)}`.

Lifecycle success means `{status:"accepted",reason:null}` and is asynchronous; poll status for completion. With no Manager, status is `unsupported`/null on non-Windows, or `runtime_unavailable` with `manager_unavailable` reason on Windows. Lifecycle commands then give error reason `unsupported`/`runtime_unavailable`. Normal Manager states/reasons and OS elevation/repair are covered in [virtual joystick](virtual-joystick.md). Sources/tests: [tools](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/mcp/tools/virtual_joystick_tools.ex), [strict schemas, mapping conflicts and async acceptance tests](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/test/trenino/mcp/tools/virtual_joystick_tools_test.exs).

## Rewrite-facing interface limitations

The source promises no incoming authorization, no uniform generic request validation, no stable typed error envelope across HTTP/MCP/joystick tools, and no generic realtime notification contract for external clients. HTTP has inconsistent validation versus missing-record handling; MCP mostly exposes serialized database state, while the UI additionally coordinates live sessions and controller reloads. Do not infer HTTP or MCP functionality merely from available domain functions or comments. No hardware scan/apply/calibration/firmware flashing MCP tools, train-profile create/update/delete MCP tools, lever configuration tools, script run/log tools, sequence-run tools, MCP resource/prompt capabilities, or MCP streaming tool progress are registered at this baseline.
