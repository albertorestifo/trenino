//! Legacy MCP SSE transport: a port of `Trenino.MCP.Server` (JSON-RPC 2.0
//! dispatch) and `TreninoWeb.MCP.MCPController` (`GET /mcp/sse` +
//! `POST /mcp/messages?session_id=...`).
//!
//! POST responses are always `202 accepted` (or `400`/`404` for session
//! problems); JSON-RPC replies — successes and errors alike — travel back over
//! the caller's SSE stream as `message` events, exactly like the Phoenix
//! controller. Binding failures are reported as a degraded, retryable status
//! instead of aborting startup, and the server participates in ordered
//! shutdown.
//!
//! Auth: the Elixir transport is unauthenticated (local desktop app). This
//! port keeps that default but supports an optional settings-backed API key
//! gate: when a key is configured, both endpoints require
//! `Authorization: Bearer <key>`.

use crate::lifecycle::ShutdownParticipant;
use crate::mcp::ports::Ports;
use crate::mcp::tools;
use axum::body::{Body, Bytes};
use axum::extract::{Query, State};
use axum::http::{header, HeaderMap, StatusCode};
use axum::response::Response;
use axum::routing::{get, post};
use axum::Router;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::convert::Infallible;
use std::net::{SocketAddr, TcpListener as StdTcpListener};
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll};
use std::thread::JoinHandle;
use std::time::Duration;
use tokio::sync::mpsc::{self, UnboundedSender};
use tokio_stream::wrappers::UnboundedReceiverStream;
use tokio_stream::{iter as stream_iter, StreamExt};

pub const SERVER_NAME: &str = "Trenino";
pub const SERVER_VERSION: &str = env!("CARGO_PKG_VERSION");
pub const PROTOCOL_VERSION: &str = "2024-11-05";

const SHUTDOWN_GRACE: Duration = Duration::from_secs(1);

/// Outcome of `handle_message`: both variants are pushed to the SSE stream
/// and answered with 202 (`{:reply, response}` / `{:error, response}`).
#[derive(Debug, Clone, PartialEq)]
pub enum MessageOutcome {
    Reply(Value),
    Error(Value),
}

impl MessageOutcome {
    pub fn into_value(self) -> Value {
        match self {
            MessageOutcome::Reply(value) | MessageOutcome::Error(value) => value,
        }
    }
}

fn jsonrpc_response(id: Value, result: Value) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "result": result})
}

fn jsonrpc_error(id: Value, code: i64, message: String) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})
}

/// `Trenino.MCP.Server.handle_message/1`.
pub fn handle_message(message: &Value, ports: &Ports) -> MessageOutcome {
    let invalid = || MessageOutcome::Error(jsonrpc_error(Value::Null, -32600, "Invalid request".into()));
    let Some(fields) = message.as_object() else {
        return invalid();
    };
    if fields.get("jsonrpc").and_then(Value::as_str) != Some("2.0") {
        return invalid();
    }
    let Some(method) = fields.get("method").and_then(Value::as_str) else {
        return invalid();
    };
    let id = fields.get("id").cloned().unwrap_or(Value::Null);
    let params = fields
        .get("params")
        .filter(|params| params.is_object())
        .cloned()
        .unwrap_or_else(|| json!({}));

    match method {
        "initialize" => MessageOutcome::Reply(jsonrpc_response(
            id,
            json!({
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION}
            }),
        )),
        "notifications/initialized" => MessageOutcome::Reply(jsonrpc_response(id, Value::Null)),
        "tools/list" => {
            let definitions = tools::list_tools()
                .into_iter()
                .map(|tool| {
                    json!({
                        "name": tool.name,
                        "description": tool.description,
                        "inputSchema": tool.input_schema,
                    })
                })
                .collect::<Vec<_>>();
            MessageOutcome::Reply(jsonrpc_response(id, json!({"tools": definitions})))
        }
        "tools/call" => {
            let Some(name) = params.get("name") else {
                return MessageOutcome::Error(jsonrpc_error(
                    id,
                    -32602,
                    "Invalid params: name and arguments required".into(),
                ));
            };
            if params.get("arguments").is_none() {
                return MessageOutcome::Error(jsonrpc_error(
                    id,
                    -32602,
                    "Invalid params: name and arguments required".into(),
                ));
            }
            let arguments = params.get("arguments").cloned().unwrap_or_else(|| json!({}));
            let name_text = term_string(name);
            match tools::call_tool(ports, &name_text, &arguments) {
                Ok(result) => MessageOutcome::Reply(jsonrpc_response(
                    id,
                    json!({"content": [{"type": "text", "text": encode_result(result)}]}),
                )),
                Err(message_text) => MessageOutcome::Reply(jsonrpc_response(
                    id,
                    json!({
                        "content": [{"type": "text", "text": message_text}],
                        "isError": true
                    }),
                )),
            }
        }
        "ping" => MessageOutcome::Reply(jsonrpc_response(id, json!({}))),
        other => MessageOutcome::Error(jsonrpc_error(
            id,
            -32601,
            format!("Method not found: {other}"),
        )),
    }
}

/// `encode_result/1`: nil becomes "ok", binaries pass through, everything
/// else is JSON-encoded.
fn encode_result(result: Value) -> String {
    match result {
        Value::Null => "ok".to_string(),
        Value::String(text) => text,
        other => other.to_string(),
    }
}

/// Elixir `"#{name}"` interpolation for non-string `name` values.
fn term_string(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        other => other.to_string(),
    }
}

// ---------------------------------------------------------------------------
// HTTP transport
// ---------------------------------------------------------------------------

/// Source of the optional API key gate (settings-backed in the app).
pub trait ApiKeySource: Send + Sync {
    fn api_key(&self) -> Option<String>;
}

struct SessionRegistry {
    sessions: Mutex<HashMap<String, UnboundedSender<Value>>>,
}

impl SessionRegistry {
    fn new() -> Self {
        Self {
            sessions: Mutex::new(HashMap::new()),
        }
    }

    fn register(&self, session_id: &str, sender: UnboundedSender<Value>) {
        if let Ok(mut sessions) = self.sessions.lock() {
            sessions.insert(session_id.to_string(), sender);
        }
    }

    fn sender(&self, session_id: &str) -> Option<UnboundedSender<Value>> {
        self.sessions.lock().ok()?.get(session_id).cloned()
    }

    fn remove(&self, session_id: &str) {
        if let Ok(mut sessions) = self.sessions.lock() {
            sessions.remove(session_id);
        }
    }

    fn clear(&self) {
        if let Ok(mut sessions) = self.sessions.lock() {
            sessions.clear();
        }
    }
}

#[derive(Clone)]
struct HttpState {
    ports: Arc<Ports>,
    auth: Option<Arc<dyn ApiKeySource>>,
    sessions: Arc<SessionRegistry>,
    admit: Arc<AtomicBool>,
}

/// SSE body stream: registry cleanup runs when the client disconnects
/// (the stream is dropped) or the server stops.
struct SessionStream {
    registry: Arc<SessionRegistry>,
    session_id: String,
    rx: UnboundedReceiverStream<Value>,
}

impl tokio_stream::Stream for SessionStream {
    type Item = Result<Bytes, Infallible>;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        Pin::new(&mut self.rx)
            .poll_next(cx)
            .map(|option| option.map(sse_message_frame))
    }
}

impl Drop for SessionStream {
    fn drop(&mut self) {
        self.registry.remove(&self.session_id);
    }
}

fn sse_message_frame(message: Value) -> Result<Bytes, Infallible> {
    Ok(Bytes::from(format!(
        "event: message\ndata: {}\n\n",
        message
    )))
}

fn sse_endpoint_frame(messages_url: &str) -> Result<Bytes, Infallible> {
    Ok(Bytes::from(format!(
        "event: endpoint\ndata: {messages_url}\n\n"
    )))
}

async fn sse_endpoint(State(state): State<HttpState>, headers: HeaderMap) -> Response {
    if !state.admit.load(Ordering::Acquire) {
        return error_response(StatusCode::SERVICE_UNAVAILABLE, "Shutting down");
    }
    if !authorized(&state, &headers) {
        return error_response(StatusCode::UNAUTHORIZED, "Unauthorized");
    }

    let session_id = generate_session_id();
    let (sender, receiver) = mpsc::unbounded_channel();
    state.sessions.register(&session_id, sender);

    let host = headers
        .get(header::HOST)
        .and_then(|value| value.to_str().ok())
        .map(str::to_owned)
        .unwrap_or_else(|| "127.0.0.1".to_owned());
    let messages_url = format!("http://{host}/mcp/messages?session_id={session_id}");

    let endpoint_event = sse_endpoint_frame(&messages_url);
    let stream = stream_iter(std::iter::once(endpoint_event)).chain(SessionStream {
        registry: state.sessions.clone(),
        session_id,
        rx: UnboundedReceiverStream::new(receiver),
    });

    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, "text/event-stream")
        .header(header::CACHE_CONTROL, "no-cache")
        .header(header::CONNECTION, "keep-alive")
        .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
        .body(Body::from_stream(stream))
        .unwrap()
}

async fn messages_endpoint(
    State(state): State<HttpState>,
    headers: HeaderMap,
    Query(params): Query<HashMap<String, String>>,
    body: Bytes,
) -> Response {
    if !state.admit.load(Ordering::Acquire) {
        return error_response(StatusCode::SERVICE_UNAVAILABLE, "Shutting down");
    }
    if !authorized(&state, &headers) {
        return error_response(StatusCode::UNAUTHORIZED, "Unauthorized");
    }
    // Phoenix parses the JSON body before the controller runs; a malformed
    // body never reaches the session lookup.
    let message: Value = match serde_json::from_slice(&body) {
        Ok(message) => message,
        Err(_) => return error_response(StatusCode::BAD_REQUEST, "Bad request"),
    };
    let Some(session_id) = params.get("session_id") else {
        return error_response(StatusCode::BAD_REQUEST, "session_id parameter required");
    };
    let Some(sender) = state.sessions.sender(session_id) else {
        return error_response(StatusCode::NOT_FOUND, "Session not found");
    };

    let ports = state.ports.clone();
    let outcome = match tokio::task::spawn_blocking(move || handle_message(&message, &ports)).await
    {
        Ok(outcome) => outcome,
        Err(join_error) => MessageOutcome::Error(jsonrpc_error(
            Value::Null,
            -32603,
            format!("Internal error: {join_error}"),
        )),
    };
    // A session that disconnected between lookup and send is dropped, the
    // same way `send/2` to a dead Phoenix process is a no-op.
    let _ = sender.send(outcome.into_value());

    Response::builder()
        .status(StatusCode::ACCEPTED)
        .body(Body::from("accepted"))
        .unwrap()
}

fn error_response(status: StatusCode, message: &str) -> Response {
    Response::builder()
        .status(status)
        .header(header::CONTENT_TYPE, "application/json")
        .body(Body::from(json!({"error": message}).to_string()))
        .unwrap()
}

fn authorized(state: &HttpState, headers: &HeaderMap) -> bool {
    let Some(source) = &state.auth else {
        return true;
    };
    let Some(configured) = source
        .api_key()
        .map(|key| key.trim().to_owned())
        .filter(|key| !key.is_empty())
    else {
        return true;
    };
    headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .is_some_and(|token| token == configured)
}

fn generate_session_id() -> String {
    let mut bytes = [0_u8; 16];
    getrandom::fill(&mut bytes).expect("system randomness is available");
    base64_url_nopad(&bytes)
}

fn base64_url_nopad(data: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    let mut encoded = String::with_capacity(data.len().div_ceil(3) * 4);
    for chunk in data.chunks(3) {
        let mut buffer = [0_u8; 3];
        buffer[..chunk.len()].copy_from_slice(chunk);
        let triple = ((buffer[0] as u32) << 16) | ((buffer[1] as u32) << 8) | buffer[2] as u32;
        encoded.push(ALPHABET[(triple >> 18) as usize & 0x3f] as char);
        encoded.push(ALPHABET[(triple >> 12) as usize & 0x3f] as char);
        if chunk.len() > 1 {
            encoded.push(ALPHABET[(triple >> 6) as usize & 0x3f] as char);
        }
        if chunk.len() > 2 {
            encoded.push(ALPHABET[triple as usize & 0x3f] as char);
        }
    }
    encoded
}

// ---------------------------------------------------------------------------
// Server lifecycle
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum McpServerStatus {
    Stopped,
    Running { address: SocketAddr },
    /// Bind failure or busy port: the app stays up, retry via `start`.
    Degraded { reason: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum McpStartError {
    AlreadyRunning,
    WorkerStart(String),
}

struct RunningServer {
    shutdown: tokio::sync::oneshot::Sender<()>,
    thread: JoinHandle<()>,
}

/// The MCP HTTP server. Owns a dedicated worker thread and runtime so
/// lifecycle control stays synchronous for the shutdown coordinator.
pub struct McpServer {
    ports: Arc<Ports>,
    auth: Option<Arc<dyn ApiKeySource>>,
    sessions: Arc<SessionRegistry>,
    admit: Arc<AtomicBool>,
    running: Mutex<Option<RunningServer>>,
    status: Mutex<McpServerStatus>,
}

impl McpServer {
    pub fn new(ports: Arc<Ports>, auth: Option<Arc<dyn ApiKeySource>>) -> Self {
        Self {
            ports,
            auth,
            sessions: Arc::new(SessionRegistry::new()),
            admit: Arc::new(AtomicBool::new(true)),
            running: Mutex::new(None),
            status: Mutex::new(McpServerStatus::Stopped),
        }
    }

    /// Bind and start serving. A bind failure (including a busy port) returns
    /// `Degraded` — never an error — so app startup is unaffected and the
    /// caller can retry.
    pub fn start(&self, address: SocketAddr) -> Result<McpServerStatus, McpStartError> {
        let mut running = self
            .running
            .lock()
            .map_err(|_| McpStartError::WorkerStart("server state is unavailable".into()))?;
        if running.is_some() {
            return Err(McpStartError::AlreadyRunning);
        }

        let listener = match bind_listener(address) {
            Ok(listener) => listener,
            Err(error) => {
                let status = McpServerStatus::Degraded {
                    reason: format!("bind {address} failed: {error}"),
                };
                self.store_status(status.clone());
                return Ok(status);
            }
        };
        let bound = match listener.local_addr() {
            Ok(bound) => bound,
            Err(error) => {
                let status = McpServerStatus::Degraded {
                    reason: format!("bound {address} has no local address: {error}"),
                };
                self.store_status(status.clone());
                return Ok(status);
            }
        };

        let _ = listener.set_nonblocking(true);
        let state = HttpState {
            ports: self.ports.clone(),
            auth: self.auth.clone(),
            sessions: self.sessions.clone(),
            admit: self.admit.clone(),
        };
        let app = Router::new()
            .route("/mcp/sse", get(sse_endpoint))
            .route("/mcp/messages", post(messages_endpoint))
            .with_state(state);
        let (shutdown, shutdown_rx) = tokio::sync::oneshot::channel::<()>();
        let thread = std::thread::Builder::new()
            .name("mcp-server".into())
            .spawn(move || serve(listener, app, shutdown_rx))
            .map_err(|error| McpStartError::WorkerStart(error.to_string()))?;

        *running = Some(RunningServer { shutdown, thread });
        self.admit.store(true, Ordering::Release);
        self.sessions.clear();
        let status = McpServerStatus::Running { address: bound };
        self.store_status(status.clone());
        Ok(status)
    }

    pub fn status(&self) -> McpServerStatus {
        self.status
            .lock()
            .map(|status| status.clone())
            .unwrap_or(McpServerStatus::Stopped)
    }

    pub fn stop(&self) -> Result<(), String> {
        let running = self
            .running
            .lock()
            .map_err(|_| "server state is unavailable".to_string())?
            .take();
        let Some(server) = running else {
            self.store_status(McpServerStatus::Stopped);
            self.sessions.clear();
            return Ok(());
        };
        self.admit.store(false, Ordering::Release);
        // Dropping senders ends every SSE stream; the worker cancels the
        // listener and any blocking tool calls within the grace window.
        self.sessions.clear();
        let _ = server.shutdown.send(());
        server
            .thread
            .join()
            .map_err(|_| "MCP server worker panicked".to_string())?;
        self.store_status(McpServerStatus::Stopped);
        Ok(())
    }

    fn store_status(&self, status: McpServerStatus) {
        if let Ok(mut current) = self.status.lock() {
            *current = status;
        }
    }
}

fn serve(listener: StdTcpListener, app: Router, shutdown_rx: tokio::sync::oneshot::Receiver<()>) {
    let Ok(runtime) = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    else {
        return;
    };
    runtime.block_on(async move {
        let Ok(listener) = tokio::net::TcpListener::from_std(listener) else {
            return;
        };
        let server = axum::serve(listener, app);
        tokio::select! {
            _ = server => {}
            _ = shutdown_rx => {}
        }
    });
    runtime.shutdown_timeout(SHUTDOWN_GRACE);
}

impl ShutdownParticipant for McpServer {
    fn stop_admission(&self) -> Result<(), String> {
        self.admit.store(false, Ordering::Release);
        Ok(())
    }

    fn cancel_and_join_producers(&self) -> Result<(), String> {
        Ok(())
    }

    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        Ok(())
    }

    fn close_ports_and_network(&self) -> Result<(), String> {
        self.stop()
    }
}

/// Bind with `SO_REUSEADDR` so a restart (after stop or crash) can rebind a
/// port whose old connections sit in TIME_WAIT, while an active listener
/// still refuses the bind.
fn bind_listener(address: SocketAddr) -> std::io::Result<StdTcpListener> {
    let socket = socket2::Socket::new(
        socket2::Domain::for_address(address),
        socket2::Type::STREAM,
        None,
    )?;
    socket.set_reuse_address(true)?;
    socket.bind(&address.into())?;
    socket.listen(1024)?;
    Ok(socket.into())
}
