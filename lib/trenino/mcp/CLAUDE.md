# MCP Tools

Use `SequenceTools` as the CRUD pattern, and check `lib/trenino/train.ex` for existing context functions first.

When adding or removing a tool:

1. Update `@tool_modules` in `lib/trenino/mcp/tool_registry.ex` if the module is new or removed.
2. Update the hardcoded tool count in these tests, including the title in `tool_registry_test.exs`:
   - `test/trenino/mcp/tool_registry_test.exs`
   - `test/trenino/mcp/server_test.exs`
   - `test/trenino_web/controllers/mcp/mcp_controller_test.exs`
3. If the tool belongs to a beta feature, also update the off-state count in `test/trenino/beta_test.exs` (see the beta-features skill).
