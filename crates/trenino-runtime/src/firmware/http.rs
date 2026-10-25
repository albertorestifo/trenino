use reqwest::{redirect::Policy, Client, RequestBuilder, Url};
use std::time::Duration;

const MAX_REDIRECTS: usize = 5;

/// Firmware HTTP boundary checks the initial URL and each redirect before the
/// next request is sent.
#[derive(Clone)]
pub struct FirmwareHttpClient {
    client: Client,
    timeout: Duration,
    /// Optional GitHub token for higher rate limits, porting
    /// `downloader.ex github_headers/0`'s optional
    /// `Application.get_env(:trenino, :github_token)` header.
    github_token: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HttpUrlError {
    Rejected,
}

impl FirmwareHttpClient {
    pub fn new(timeout: Duration) -> Result<Self, reqwest::Error> {
        let client = Client::builder()
            .timeout(timeout)
            .redirect(Policy::custom(|attempt| {
                if attempt.previous().len() >= MAX_REDIRECTS {
                    attempt.error("firmware redirect limit exceeded")
                } else if permitted_url(attempt.url()) {
                    attempt.follow()
                } else {
                    attempt.error("firmware redirect target rejected")
                }
            }))
            .build()?;
        Ok(Self {
            client,
            timeout,
            github_token: None,
        })
    }

    /// Attach the optional token (oracle sends `authorization: token <t>`).
    pub fn with_github_token(mut self, token: Option<String>) -> Self {
        self.github_token = token;
        self
    }

    /// The oracle's request headers (`downloader.ex github_headers/0`):
    /// accept + user-agent, plus `authorization` when a token is configured.
    pub fn github_headers(&self, builder: RequestBuilder) -> RequestBuilder {
        let builder = builder
            .header("accept", "application/vnd.github.v3+json")
            .header("user-agent", "trenino/1.0");
        match &self.github_token {
            Some(token) => builder.header("authorization", format!("token {token}")),
            None => builder,
        }
    }

    pub fn get(&self, url: &Url) -> Result<RequestBuilder, HttpUrlError> {
        if !permitted_url(url) {
            return Err(HttpUrlError::Rejected);
        }
        Ok(self.client.get(url.clone()).timeout(self.timeout))
    }
}

pub(super) fn permitted_url(url: &Url) -> bool {
    if !url.username().is_empty() || url.password().is_some() {
        return false;
    }
    if url.scheme() == "https" {
        return true;
    }
    url.scheme() == "http"
        && url.host_str().is_some_and(|host| {
            host == "localhost"
                || host
                    .parse::<std::net::IpAddr>()
                    .is_ok_and(|ip| ip.is_loopback())
        })
}
