use reqwest::{redirect::Policy, Client, RequestBuilder, Url};
use std::time::Duration;

const MAX_REDIRECTS: usize = 5;

/// Firmware HTTP boundary checks the initial URL and each redirect before the
/// next request is sent.
#[derive(Clone)]
pub struct FirmwareHttpClient {
    client: Client,
    timeout: Duration,
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
        Ok(Self { client, timeout })
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
