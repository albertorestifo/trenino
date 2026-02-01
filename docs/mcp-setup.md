# AI-Powered Train Setup with Claude

Trenino includes a built-in MCP (Model Context Protocol) server that lets you use Claude to configure your train controls through natural conversation. Instead of manually creating output bindings, button mappings, and command sequences one by one, you can describe what you want and let Claude handle the details.

## What Can Claude Do?

With the MCP integration, Claude can:

- **Explore the simulator API** to understand what controls a train has (throttle, brakes, lights, doors, etc.)
- **Set up output bindings** — tell Claude "make the red LED turn on when speed exceeds 50" and it will find the right simulator endpoint, pick your LED output, and create the binding
- **Configure button mappings** — describe what a button should do ("this button should toggle the headlights") and Claude will set up the binding with the correct mode and endpoint
- **Create command sequences** — ask for complex multi-step actions ("create a startup sequence that turns on the battery, then the pantograph, then the main breaker with delays between each step")
- **Experiment with controls** — Claude can read and write simulator values in real-time to test what endpoints do before configuring bindings

## Setup

### Requirements

- Trenino running on your machine (the Phoenix server at `http://localhost:4000`)
- [Claude Desktop](https://claude.ai/download) or [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

### Claude Desktop

1. Open Claude Desktop settings
2. Go to the **MCP Servers** section
3. Add a new server with the following configuration:

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

1. In your project directory (or any directory), create or edit `.mcp.json`:

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

2. Restart Claude Code. Trenino will appear as an available MCP server.

## Example Workflows

### Setting Up Output Bindings (LEDs)

> "I have a train called BR 146.2. Set up my red LED to turn on when the emergency brake is active."

Claude will:
1. Look up the train configuration
2. Browse the simulator API to find the emergency brake endpoint
3. List your hardware outputs to find the red LED
4. Create an output binding with the right condition

### Configuring Button Mappings

> "Bind button 3 on my Arduino to the horn. It should sound while I hold the button."

Claude will:
1. Find the hardware input for button 3
2. Browse the simulator to find the horn endpoint
3. Create a momentary-mode button binding that repeats while held

### Creating Command Sequences

> "Create a cold start sequence for the BR 187 that turns on the battery isolator, waits 500ms, raises the pantograph, waits 1 second, then closes the main breaker."

Claude will:
1. Explore the simulator API to find the correct endpoints for each step
2. Create a sequence with the right commands, values, and delays
3. Optionally bind it to a button for you

### Experimenting with Controls

> "What controls does the current train have? Try setting the wipers to on."

Claude will browse the simulator API tree, find the wiper endpoint, and set the value — letting you see the result in real-time in the game.

## Available Tools

Claude has access to 20 tools for interacting with Trenino:

| Category | Tools |
|----------|-------|
| Simulator | Browse endpoints, read values, write values |
| Trains | List trains, get train configuration |
| Devices | List devices, list inputs, list outputs |
| Output Bindings | List, create, update, delete |
| Button Bindings | Get, create, update, delete |
| Sequences | List, create, update, delete |

## Tips

- **Start Trenino first** — the MCP server is part of Trenino's web server. Claude can only connect when Trenino is running.
- **Have the game running** — simulator tools require Train Sim World to be running with the External Interface API enabled. Claude will tell you if the simulator isn't connected.
- **Be specific about hardware** — if you have multiple devices or outputs with similar names, mention the specific one you want (e.g., "the LED on pin 5 of my Arduino Mega").
- **Ask Claude to explore first** — if you're not sure what endpoints a train has, ask Claude to browse the simulator API tree. It can discover controls you might not know about.
