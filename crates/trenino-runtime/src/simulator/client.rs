use reqwest::{
    header::{HeaderMap, HeaderName, HeaderValue},
    Client, Method, StatusCode, Url,
};
use serde_json::Value;
use std::{fmt, time::Duration};
use trenino_core::{
    rounding::round_elixir,
    simulator::{Endpoint, SimValue},
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TimeoutProfile {
    Normal,
    Fast,
}
impl TimeoutProfile {
    pub fn request_deadline(self) -> Duration {
        match self {
            Self::Normal => Duration::from_secs(10),
            Self::Fast => Duration::from_secs(1),
        }
    }
    pub fn pool_wait_budget(self) -> Duration {
        match self {
            Self::Normal => Duration::from_secs(5),
            Self::Fast => Duration::from_millis(500),
        }
    }
    fn retries(self) -> usize {
        match self {
            Self::Normal => 2,
            Self::Fast => 0,
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum SimulatorError {
    InvalidUrl(String),
    InvalidKey,
    InvalidPath,
    HttpStatus { status: u16, body: Value },
    Transport(String),
    InvalidJson(String),
    InvalidValue,
}
impl fmt::Display for SimulatorError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}
impl std::error::Error for SimulatorError {}

#[derive(Clone)]
pub struct SimulatorClient {
    base_url: Url,
    api_key: String,
    http: Client,
    profile: TimeoutProfile,
}
impl SimulatorClient {
    pub fn new(base_url: &str, api_key: &str) -> Result<Self, SimulatorError> {
        Self::with_profile(base_url, api_key, TimeoutProfile::Normal)
    }
    pub fn with_fast_timeouts(&self) -> Result<Self, SimulatorError> {
        Self::create(self.base_url.as_str(), &self.api_key, TimeoutProfile::Fast)
    }
    pub fn with_profile(
        base_url: &str,
        api_key: &str,
        profile: TimeoutProfile,
    ) -> Result<Self, SimulatorError> {
        Self::create(base_url, api_key, profile)
    }
    fn create(
        base_url: &str,
        api_key: &str,
        profile: TimeoutProfile,
    ) -> Result<Self, SimulatorError> {
        let base_url =
            Url::parse(base_url).map_err(|e| SimulatorError::InvalidUrl(e.to_string()))?;
        let mut headers = HeaderMap::new();
        headers.insert(
            HeaderName::from_static("dtgcommkey"),
            HeaderValue::from_str(api_key).map_err(|_| SimulatorError::InvalidKey)?,
        );
        let http = Client::builder()
            .default_headers(headers)
            .connect_timeout(profile.request_deadline())
            .timeout(profile.request_deadline())
            .redirect(reqwest::redirect::Policy::none())
            .pool_max_idle_per_host(8)
            .build()
            .map_err(|e| SimulatorError::Transport(e.to_string()))?;
        Ok(Self {
            base_url,
            api_key: api_key.to_owned(),
            http,
            profile,
        })
    }
    pub fn profile(&self) -> TimeoutProfile {
        self.profile
    }
    pub fn queue_wait_budget(&self) -> Duration {
        self.profile.pool_wait_budget()
    }
    pub async fn info(&self) -> Result<Value, SimulatorError> {
        self.request(Method::GET, "/info", &[], None, true).await
    }
    pub async fn list(&self, path: Option<&str>) -> Result<Value, SimulatorError> {
        let path = match path {
            Some(path) => operation_path("/list", path)?,
            None => "/list".into(),
        };
        self.request(Method::GET, &path, &[], None, true).await
    }
    pub async fn get(&self, path: &str) -> Result<Value, SimulatorError> {
        let path = operation_path("/get", path)?;
        self.request(Method::GET, &path, &[], None, true).await
    }
    pub async fn get_int(&self, path: &str) -> Result<i64, SimulatorError> {
        let response = self.get(path).await?;
        let value = first_value(&response)?;
        match value {
            Value::Number(n) => {
                if let Some(value) = n.as_i64() {
                    return Ok(value);
                }
                if let Some(value) = n.as_u64() {
                    return i64::try_from(value).map_err(|_| SimulatorError::InvalidValue);
                }
                let value = n.as_f64().ok_or(SimulatorError::InvalidValue)?;
                let truncated = value.trunc();
                if !truncated.is_finite()
                    || truncated < i64::MIN as f64
                    || truncated >= 9_223_372_036_854_775_808.0
                {
                    Err(SimulatorError::InvalidValue)
                } else {
                    Ok(truncated as i64)
                }
            }
            Value::String(s) => s.parse().map_err(|_| SimulatorError::InvalidValue),
            _ => Err(SimulatorError::InvalidValue),
        }
    }
    pub async fn get_float(&self, path: &str) -> Result<f64, SimulatorError> {
        let response = self.get(path).await?;
        let value = first_value(&response)?;
        let n = match value {
            Value::Number(n) => n.as_f64().ok_or(SimulatorError::InvalidValue)?,
            Value::String(s) => s.parse::<f64>().map_err(|_| SimulatorError::InvalidValue)?,
            _ => return Err(SimulatorError::InvalidValue),
        };
        if !n.is_finite() {
            return Err(SimulatorError::InvalidValue);
        }
        round_elixir(n, 2).ok_or(SimulatorError::InvalidValue)
    }
    pub async fn get_string(&self, path: &str) -> Result<String, SimulatorError> {
        let response = self.get(path).await?;
        let value = first_value(&response)?;
        match value {
            Value::String(s) => Ok(s.clone()),
            Value::Bool(_) | Value::Number(_) | Value::Null => {
                let value: SimValue = serde_json::from_value(value.clone())
                    .map_err(|_| SimulatorError::InvalidValue)?;
                Ok(value.to_legacy_string())
            }
            _ => Err(SimulatorError::InvalidValue),
        }
    }
    pub async fn set(&self, path: &str, value: &Value) -> Result<Value, SimulatorError> {
        self.request(
            Method::PATCH,
            &operation_path("/set", path)?,
            &[("Value", value_to_query(value))],
            None,
            false,
        )
        .await
    }
    pub async fn set_value(
        &self,
        endpoint: &Endpoint,
        value: &SimValue,
    ) -> Result<Value, SimulatorError> {
        if matches!(value, SimValue::Number(n) if !n.is_finite()) {
            return Err(SimulatorError::InvalidValue);
        }
        let value = match value {
            SimValue::Integer(n) => {
                serde_json::to_value(n).map_err(|_| SimulatorError::InvalidValue)?
            }
            SimValue::Number(n) => Value::from(*n),
            SimValue::Bool(b) => Value::Bool(*b),
            SimValue::String(s) => Value::String(s.clone()),
            SimValue::Null => Value::Null,
        };
        self.set(endpoint.as_str(), &value).await
    }
    pub async fn subscribe(&self, path: &str, id: i64) -> Result<Value, SimulatorError> {
        self.request(
            Method::POST,
            &operation_path("/subscription", path)?,
            &[("Subscription", id.to_string())],
            Some(""),
            false,
        )
        .await
    }
    pub async fn get_subscription(&self, id: i64) -> Result<Value, SimulatorError> {
        self.request(
            Method::GET,
            "/subscription",
            &[("Subscription", id.to_string())],
            None,
            true,
        )
        .await
    }
    pub async fn unsubscribe(&self, id: i64) -> Result<Value, SimulatorError> {
        self.request(
            Method::DELETE,
            "/subscription",
            &[("Subscription", id.to_string())],
            None,
            false,
        )
        .await
    }
    pub async fn list_subscriptions(&self) -> Result<Value, SimulatorError> {
        self.request(Method::GET, "/listsubscriptions", &[], None, true)
            .await
    }
    async fn request(
        &self,
        method: Method,
        path: &str,
        query: &[(&str, String)],
        body: Option<&str>,
        retry_safe: bool,
    ) -> Result<Value, SimulatorError> {
        let url = self
            .base_url
            .join(path)
            .map_err(|e| SimulatorError::InvalidUrl(e.to_string()))?;
        let retries = if retry_safe {
            self.profile.retries()
        } else {
            0
        };
        for attempt in 0..=retries {
            let mut request = self.http.request(method.clone(), url.clone()).query(query);
            if let Some(body) = body {
                request = request.body(body.to_owned());
            }
            match request.send().await {
                Ok(response)
                    if retry_safe
                        && attempt < retries
                        && is_transient_status(response.status()) =>
                {
                    drop(response);
                    tokio::time::sleep(Duration::from_millis(100 * (attempt as u64 + 1))).await;
                }
                Ok(response) => return parse_response(response).await,
                Err(e) if attempt < retries && (e.is_timeout() || e.is_connect()) => {
                    tokio::time::sleep(Duration::from_millis(100 * (attempt as u64 + 1))).await
                }
                Err(e) => return Err(SimulatorError::Transport(e.to_string())),
            }
        }
        unreachable!()
    }
}
async fn parse_response(response: reqwest::Response) -> Result<Value, SimulatorError> {
    let status = response.status();
    if status == StatusCode::FORBIDDEN {
        Err(SimulatorError::InvalidKey)
    } else if status != StatusCode::OK {
        let body = response
            .bytes()
            .await
            .map(|bytes| error_body(&bytes))
            .unwrap_or_else(|error| Value::String(format!("failed to read error body: {error}")));
        Err(SimulatorError::HttpStatus {
            status: status.as_u16(),
            body,
        })
    } else {
        let bytes = response
            .bytes()
            .await
            .map_err(|error| SimulatorError::Transport(error.to_string()))?;
        serde_json::from_slice(&bytes)
            .map_err(|error| SimulatorError::InvalidJson(error.to_string()))
    }
}
fn error_body(bytes: &[u8]) -> Value {
    serde_json::from_slice(bytes)
        .unwrap_or_else(|_| Value::String(String::from_utf8_lossy(bytes).into_owned()))
}
fn is_transient_status(status: StatusCode) -> bool {
    matches!(status.as_u16(), 408 | 429 | 500 | 502 | 503 | 504)
}
fn first_value(response: &Value) -> Result<&Value, SimulatorError> {
    response
        .get("Values")
        .and_then(Value::as_object)
        .and_then(|m| m.values().next())
        .ok_or(SimulatorError::InvalidValue)
}
fn value_to_query(value: &Value) -> String {
    match value {
        Value::String(s) => s.clone(),
        Value::Null => "null".into(),
        _ => value.to_string(),
    }
}
fn encode_path(path: &str) -> String {
    let mut out = String::new();
    for b in path.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~' | b'/') {
            out.push(b as char)
        } else {
            out.push_str(&format!("%{b:02X}"))
        }
    }
    out
}

fn operation_path(prefix: &str, path: &str) -> Result<String, SimulatorError> {
    if path.is_empty() || path.split('/').any(|segment| matches!(segment, "." | "..")) {
        return Err(SimulatorError::InvalidPath);
    }
    Ok(format!("{prefix}/{}", encode_path(path)))
}
