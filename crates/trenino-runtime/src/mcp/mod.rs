//! Legacy MCP server surface: JSON-RPC 2.0 dispatch, the 47-tool registry
//! and the SSE/POST HTTP transport (`GET /mcp/sse`,
//! `POST /mcp/messages?session_id=...`) with a degraded-not-fatal lifecycle.
pub mod ports;
pub mod server;
pub mod storage_ports;
pub mod tools;
