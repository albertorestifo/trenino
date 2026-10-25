# User-story catalogue

All stories describe the implemented baseline `188f35e4108733358730e92ebd98f1912af5173a`, not requirements inferred from the rewrite branch. Each linked story gives preconditions, behavior, acceptance/error cases and source/test evidence. Test citations indicate reviewed tests; see [verification](verification.md) for commands actually run.

**125 stories** across hardware, firmware, simulator, train control, automation, UI, APIs, desktop operations and virtual joystick.

## Hardware and firmware

| Story | Scenario |
|---|---|
| [HW-001](hardware-user-stories.md#hw-001) | Create and retrieve a reusable panel configuration |
| [HW-002](hardware-user-stories.md#hw-002) | Define physical analog and button inputs |
| [HW-003](hardware-user-stories.md#hw-003) | Scan and identify a USB controller |
| [HW-004](hardware-user-stories.md#hw-004) | Disconnect, diagnose, and retry a port |
| [HW-005](hardware-user-stories.md#hw-005) | Apply a complete configuration and await confirmation |
| [HW-006](hardware-user-stories.md#hw-006) | Inspect live raw control values |
| [HW-007](hardware-user-stories.md#hw-007) | Create a button matrix with virtual input identities |
| [HW-008](hardware-user-stories.md#hw-008) | Edit or remove a matrix while understanding binding loss |
| [HW-009](hardware-user-stories.md#hw-009) | Calibrate an analog lever through endpoint and sweep samples |
| [HW-010](hardware-user-stories.md#hw-010) | Normalize simple, inverted, and wrapped travel |
| [HW-011](hardware-user-stories.md#hw-011) | Identify an input by moving or pressing it |
| [HW-012](hardware-user-stories.md#hw-012) | Register and toggle a digital indicator output |
| [HW-013](hardware-user-stories.md#hw-013) | Add an HT16K33 display and configure rendering |
| [HW-014](hardware-user-stories.md#hw-014) | Render text/numbers and send display updates |
| [HW-015](hardware-user-stories.md#hw-015) | Delete a configuration without removing a live panel association |
| [HW-016](hardware-user-stories.md#hw-016) | Preserve protocol interoperability through malformed traffic |
| [FW-001](hardware-user-stories.md#fw-001) | Refresh the release catalogue from firmware manifests |
| [FW-002](hardware-user-stories.md#fw-002) | Select a manifest-supported device environment |
| [FW-003](hardware-user-stories.md#fw-003) | Restrict firmware choices to compatible app versions |
| [FW-004](hardware-user-stories.md#fw-004) | Download and reuse the local firmware cache |
| [FW-005](hardware-user-stories.md#fw-005) | Flash a board before Trenino firmware is installed |
| [FW-006](hardware-user-stories.md#fw-006) | Enter a 1200-bps bootloader and follow a changed COM port |
| [FW-007](hardware-user-stories.md#fw-007) | Recover automatically from common bootloader/port failures |
| [FW-008](hardware-user-stories.md#fw-008) | Observe progress, detailed failure, and upload history |
| [FW-009](hardware-user-stories.md#fw-009) | Cancel or time out an upload and release serial ownership |
| [FW-010](hardware-user-stories.md#fw-010) | Receive useful updates only when connected hardware needs them |
| [FW-011](hardware-user-stories.md#fw-011) | Resolve the packaged uploader on supported platforms |

## Simulator, train controls and automation

| Story | Scenario |
|---|---|
| [SIM-001](train-user-stories.md#sim-001) | Connect to the game's external interface |
| [SIM-002](train-user-stories.md#sim-002) | Tolerate a brief health-check failure |
| [SIM-003](train-user-stories.md#sim-003) | Reconfigure, manually retry, or disconnect |
| [SIM-004](train-user-stories.md#sim-004) | Read, write and subscribe to arbitrary game endpoints |
| [SIM-005](train-user-stories.md#sim-005) | Obtain a name-based control suggestion |
| [SIM-006](train-user-stories.md#sim-006) | Identify an endpoint by moving its game control |
| [SIM-007](train-user-stories.md#sim-007) | Empirically analyze a lever's game ranges |
| [AUTO-001](train-user-stories.md#auto-001) | Select the driven vehicle rather than freight wagons |
| [AUTO-002](train-user-stories.md#auto-002) | Share a profile across equivalent simulator variants |
| [AUTO-003](train-user-stories.md#auto-003) | Report ambiguous profiles instead of picking one |
| [AUTO-004](train-user-stories.md#auto-004) | Handle an unknown vehicle |
| [AUTO-005](train-user-stories.md#auto-005) | Keep a profile through a connection grace period |
| [AUTO-006](train-user-stories.md#auto-006) | Force refresh after editing a profile |
| [TR-001](train-user-stories.md#tr-001) | Create, find, edit and delete a profile |
| [TR-002](train-user-stories.md#tr-002) | Add or remove a cab element |
| [TR-003](train-user-stories.md#tr-003) | Configure lever endpoints manually or from analysis |
| [TR-004](train-user-stories.md#tr-004) | Edit gate/linear notches and their coordinate systems |
| [TR-005](train-user-stories.md#tr-005) | Bind, disable, enable or unbind a lever input |
| [TR-006](train-user-stories.md#tr-006) | Resolve a train-binding versus vJoy destination conflict |
| [TR-007](train-user-stories.md#tr-007) | Run legacy automatic notch calibration |
| [TR-008](train-user-stories.md#tr-008) | Map actual physical travel to each notch |
| [TR-009](train-user-stories.md#tr-009) | Distribute and inspect hardware notch coverage |
| [TR-010](train-user-stories.md#tr-010) | Drive gates, linears and inverted controls |
| [TR-011](train-user-stories.md#tr-011) | Keep lever movement responsive during slow HTTP |
| [TR-012](train-user-stories.md#tr-012) | Create/edit/disable/delete a simple button binding |
| [TR-013](train-user-stories.md#tr-013) | Hold a repeating game button |
| [TR-014](train-user-stories.md#tr-014) | Hold a keyboard key or modifier combination |
| [TR-015](train-user-stories.md#tr-015) | Maintain a reusable ordered command sequence |
| [TR-016](train-user-stories.md#tr-016) | Trigger/cancel a sequence from momentary hardware |
| [TR-017](train-user-stories.md#tr-017) | Run separate on/off sequences from a latching switch |
| [TR-018](train-user-stories.md#tr-018) | Maintain an LED condition binding |
| [TR-019](train-user-stories.md#tr-019) | Mirror game conditions to LEDs while driving |
| [TR-020](train-user-stories.md#tr-020) | Maintain a formatted display binding |
| [TR-021](train-user-stories.md#tr-021) | Display simulator text and recover after reconnect |
| [TR-022](train-user-stories.md#tr-022) | Create/edit/toggle/delete a train Lua script |
| [TR-023](train-user-stories.md#tr-023) | React to a changing simulator trigger |
| [TR-024](train-user-stories.md#tr-024) | Run manually and build a self-scheduling loop |
| [TR-025](train-user-stories.md#tr-025) | Use Lua to write simulator values and hardware outputs |
| [TR-026](train-user-stories.md#tr-026) | Diagnose Lua failure and protect callback responsiveness |

## UI and external interfaces

| Story | Scenario |
|---|---|
| [UI-001](interface-user-stories.md#ui-001) | Make the first-run reporting choice |
| [UI-002](interface-user-stories.md#ui-002) | Discover and manage connected hardware from navigation |
| [UI-003](interface-user-stories.md#ui-003) | Understand simulator and software update status |
| [UI-004](interface-user-stories.md#ui-004) | Create and revisit a hardware profile |
| [UI-005](interface-user-stories.md#ui-005) | Add physical analog and button inputs |
| [UI-006](interface-user-stories.md#ui-006) | Apply a profile and watch live input values |
| [UI-007](interface-user-stories.md#ui-007) | Calibrate analog travel |
| [UI-008](interface-user-stories.md#ui-008) | Create and validate a matrix, then test its wiring |
| [UI-009](interface-user-stories.md#ui-009) | Configure and test physical outputs |
| [UI-010](interface-user-stories.md#ui-010) | Add an I2C display with retained form settings |
| [UI-011](interface-user-stories.md#ui-011) | Delete an inactive hardware configuration |
| [UI-012](interface-user-stories.md#ui-012) | Create a train from the detected identity |
| [UI-013](interface-user-stories.md#ui-013) | Maintain train profile details and logical controls |
| [UI-014](interface-user-stories.md#ui-014) | Find an endpoint by browsing or simulator interaction |
| [UI-015](interface-user-stories.md#ui-015) | Bind a physical button to simulator values |
| [UI-016](interface-user-stories.md#ui-016) | Bind a button to a sequence or keyboard combination |
| [UI-017](interface-user-stories.md#ui-017) | Set up a calibrated analog lever |
| [UI-018](interface-user-stories.md#ui-018) | Reconfigure a lever without silently skipping dependencies |
| [UI-019](interface-user-stories.md#ui-019) | Drive an LED from a simulator condition |
| [UI-020](interface-user-stories.md#ui-020) | Display a simulator number and edit formatting offline |
| [UI-021](interface-user-stories.md#ui-021) | Build, edit and test a command sequence |
| [UI-022](interface-user-stories.md#ui-022) | Author and run a Lua script with console feedback |
| [UI-023](interface-user-stories.md#ui-023) | Install firmware on an identified port |
| [UI-024](interface-user-stories.md#ui-024) | Configure offline virtual joystick mappings |
| [UI-025](interface-user-stories.md#ui-025) | Move a simulator input to joystick destination explicitly |
| [UI-026](interface-user-stories.md#ui-026) | Activate, deactivate and recover joystick runtime |
| [UI-027](interface-user-stories.md#ui-027) | Save and test simulator settings |
| [UI-028](interface-user-stories.md#ui-028) | Receive an AI-directed hardware detection prompt |
| [UI-029](interface-user-stories.md#ui-029) | Preserve client theme and understand transient feedback |
| [API-001](interface-user-stories.md#api-001) | Determine readiness and shut down the desktop backend |
| [API-002](interface-user-stories.md#api-002) | Read train profiles and output IDs by HTTP |
| [API-003](interface-user-stories.md#api-003) | Manage scripts through HTTP |
| [API-004](interface-user-stories.md#api-004) | Proxy simulator browsing/readback over HTTP |
| [API-005](interface-user-stories.md#api-005) | Establish and use an MCP SSE session |
| [API-006](interface-user-stories.md#api-006) | Handle protocol and tool errors correctly |
| [API-007](interface-user-stories.md#api-007) | Explore and manipulate live simulator controls through MCP |
| [API-008](interface-user-stories.md#api-008) | Inspect train/element/hardware configuration before binding |
| [API-009](interface-user-stories.md#api-009) | Detect a hardware input instead of asking for its ID |
| [API-010](interface-user-stories.md#api-010) | Create logical controls and button destinations |
| [API-011](interface-user-stories.md#api-011) | Create output and display rules |
| [API-012](interface-user-stories.md#api-012) | Manage ordered command sequences |
| [API-013](interface-user-stories.md#api-013) | Manage Lua source through MCP |
| [API-014](interface-user-stories.md#api-014) | Map and manage joystick through strict MCP tools |

## Desktop and virtual joystick

| Story | Scenario |
|---|---|
| [PLAT-001](platform-user-stories.md#plat-001) | Launch a self-contained desktop app |
| [PLAT-002](platform-user-stories.md#plat-002) | Choose error-reporting consent |
| [PLAT-003](platform-user-stories.md#plat-003) | Use discovered or manual simulator credentials |
| [PLAT-004](platform-user-stories.md#plat-004) | Retain configuration across restarts and upgrades |
| [PLAT-005](platform-user-stories.md#plat-005) | Install a stable update without replacing a running backend |
| [PLAT-006](platform-user-stories.md#plat-006) | Discover new versions in a browser/direct build |
| [PLAT-007](platform-user-stories.md#plat-007) | Close the app and release runtime resources |
| [PLAT-008](platform-user-stories.md#plat-008) | Install/uninstall alongside shared vJoy consumers |
| [VJ-001](platform-user-stories.md#vj-001) | Enable one joystick without running the game |
| [VJ-002](platform-user-stories.md#vj-002) | Map a calibrated lever to an axis |
| [VJ-003](platform-user-stories.md#vj-003) | Map a button or matrix cell to a joystick button |
| [VJ-004](platform-user-stories.md#vj-004) | Switch an input destination with explicit replacement |
| [VJ-005](platform-user-stories.md#vj-005) | Disconnect and reconnect hardware while driving |
| [VJ-006](platform-user-stories.md#vj-006) | Recover a failed feeder without unbounded retries |
| [VJ-007](platform-user-stories.md#vj-007) | Disable or clean up a leftover joystick |
| [VJ-008](platform-user-stories.md#vj-008) | Return a useful unsupported state on other platforms |
