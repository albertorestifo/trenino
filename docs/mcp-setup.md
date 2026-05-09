# AI-Powered Train Setup with Claude

Trenino includes a built-in MCP (Model Context Protocol) server that lets you use Claude to configure your trains through natural conversation. Instead of manually setting up output bindings, button mappings, and command sequences, describe what you want and let Claude handle the details.

## What Can Claude Do?

- **Explore the simulator API** to discover what controls a train has (throttle, brakes, lights, doors, etc.)
- **Detect your hardware** — Claude can ask you to press a button or move a lever, and it will automatically identify the input for you. No need to look up input IDs.
- **Set up output bindings** — "make the red LED turn on when speed exceeds 50" and Claude will find the right endpoint, pick your LED, and create the binding
- **Configure button mappings** — "this button should toggle the headlights" and Claude will create the binding with the correct mode and endpoint
- **Create command sequences** — "create a startup sequence that turns on the battery, then the pantograph, then the main breaker with delays between each"
- **Write and manage Lua scripts** — "create a script that flashes my warning LED when speed exceeds 100 km/h" and Claude will write, create, and enable the script for you
- **Set up display bindings** — "show the current speed on my 7-segment display" and Claude will find the speed endpoint, your display module, and create the binding with the right format string
- **Experiment with controls** — read and write simulator values in real-time to test what endpoints do before committing to a configuration

## Setup

### Requirements

- Trenino running on your machine (`http://localhost:4000`)
- [Claude Desktop](https://claude.ai/download) or [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

### Claude Desktop

1. Open Claude Desktop settings
2. Go to the **MCP Servers** section
3. Add a new server:

```json
{
  "trenino": {
    "type": "sse",
    "url": "http://localhost:4000/mcp/sse"
  }
}
```

4. Restart Claude Desktop
5. You should see "Trenino" listed as a connected MCP server

### Claude Code

If you're working inside the Trenino project directory, the MCP server is already configured — `.mcp.json` is included in the repo. Just make sure Trenino is running and restart Claude Code.

To use Trenino's MCP from a different directory, create a `.mcp.json` file there:

```json
{
  "mcpServers": {
    "trenino": {
      "type": "sse",
      "url": "http://localhost:4000/mcp/sse"
    }
  }
}
```

## Example Workflows

### Setting Up a Complete Train

> "I have a BR 146.2. Help me set up my buttons and LEDs."

Claude will walk you through it interactively:
1. Look up your train configuration
2. Ask you to press each button on your hardware to identify it
3. Ask you to interact with the matching control in Train Sim World to find the endpoint
4. Create the binding with the right mode and values
5. Repeat for LEDs, sequences, and other controls

### Setting Up Output Bindings (LEDs)

> "Set up my red LED to turn on when the emergency brake is active."

Claude will:
1. Look up the train configuration
2. Browse the simulator API to find the emergency brake endpoint
3. List your hardware outputs to find the red LED
4. Create an output binding with the right condition

### Creating Command Sequences

> "Create a cold start sequence for the BR 187 that turns on the battery isolator, waits 500ms, raises the pantograph, waits 1 second, then closes the main breaker."

Claude will:
1. Explore the simulator API to find the correct endpoints for each step
2. Create a sequence with the right commands, values, and delays
3. Optionally bind it to a button for you

### Experimenting with Controls

> "What controls does the current train have? Try setting the wipers to on."

Claude will browse the simulator API tree, find the wiper endpoint, and set the value — you'll see the result in real-time in the game.

### Writing Lua Scripts

> "Create a script for the BR 442 that turns on my warning LED when speed exceeds 100 km/h, and turns it off when speed drops below 95."

Claude will:
1. Look up the speed endpoint for that train (`CurrentDrivableActor.Function.HUD_GetSpeed`)
2. Find your warning LED output ID
3. Write the Lua script with hysteresis logic
4. Create and enable the script with the speed endpoint as the trigger

## Available Tools

Claude has access to 37 tools for interacting with Trenino:

| Category | Tools |
|----------|-------|
| Simulator | Browse endpoints, read values, write values |
| Trains | List trains, get full train configuration |
| Elements | List, create, delete buttons and levers |
| Devices | List devices, list inputs, list outputs; list, create, update, delete I2C modules |
| Detection | Detect hardware inputs (button/lever) |
| Output Bindings | List, create, update, delete |
| Button Bindings | Get, create, update, delete |
| Sequences | List, create, update, delete |
| Scripts | List, get, create, update, delete Lua scripts |
| Display Bindings | List, create, update, delete display bindings |

## Tips

- **Start Trenino first** — the MCP server is part of Trenino's web server. Claude can only connect when Trenino is running.
- **Have the game running** — simulator tools need Train Sim World running with the External Interface API enabled.
- **Let Claude detect your inputs** — rather than looking up input IDs manually, let Claude prompt you to press the button or move the lever you want to bind. A modal will appear in the Trenino UI.
- **Ask Claude to explore** — if you're not sure what endpoints a train has, ask Claude to browse the simulator API tree.
- **Be specific about hardware** — if you have multiple devices or outputs with similar names, mention the specific one (e.g., "the LED on pin 5 of my Arduino Mega").
