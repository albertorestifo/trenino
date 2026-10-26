//! Consent-gated Sentry error reporting.
//!
//! Mirrors the documented Elixir contract (`docs/feature-reference/
//! desktop-and-operations.md`): telemetry is enabled only when a DSN is
//! configured, and every event is dropped unless error-reporting consent is
//! enabled. Only error-level logs and panics are captured — no game or
//! hardware telemetry. The DSN defaults to the project DSN and can be
//! overridden with `SENTRY_DSN` (an empty value disables telemetry).

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// Default project DSN; `SENTRY_DSN` overrides, an empty override disables.
const DEFAULT_DSN: &str = "https://510e0af9a9ad5c2e59ae5a1503a6923e@o4512323050995712.ingest.de.sentry.io/4512323054993488";

/// Shared consent flag consulted by the `before_send` gate.
#[derive(Clone)]
pub(crate) struct TelemetryGate(Arc<AtomicBool>);

impl TelemetryGate {
    /// Unset or declined consent keeps the gate closed.
    pub(crate) fn from_consent(consent: Option<bool>) -> Self {
        Self(Arc::new(AtomicBool::new(consent == Some(true))))
    }

    /// Update after a consent change; events flow only while enabled.
    pub(crate) fn set_consent(&self, enabled: bool) {
        self.0.store(enabled, Ordering::Release);
    }

    /// Whether events may be sent right now.
    pub(crate) fn allow(&self) -> bool {
        self.0.load(Ordering::Acquire)
    }
}

/// Resolve the effective DSN: `SENTRY_DSN` overrides the project default;
/// empty/whitespace disables telemetry entirely.
pub(crate) fn resolve_dsn() -> Option<String> {
    match std::env::var("SENTRY_DSN") {
        Ok(value) => {
            let trimmed = value.trim();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.to_owned())
            }
        }
        Err(_) => Some(DEFAULT_DSN.to_owned()),
    }
}

// SDK 0.49.3's default NoopLogger has an unimplemented flush method. Keep
// errors available locally and provide a safe flush destination instead.
struct LocalErrorLogger;

impl log::Log for LocalErrorLogger {
    fn enabled(&self, metadata: &log::Metadata<'_>) -> bool {
        metadata.level() == log::Level::Error
    }

    fn log(&self, record: &log::Record<'_>) {
        if self.enabled(record.metadata()) {
            eprintln!("{}: {}", record.target(), record.args());
        }
    }

    fn flush(&self) {}
}

/// Initialize Sentry. Returns the client guard (keep alive for the process
/// lifetime). Invalid DSNs log a warning and disable
/// telemetry instead of failing startup. Error-level logs and panics are
/// captured by the crate's default integrations; `before_send` drops every
/// event while consent is not enabled.
pub(crate) fn init(dsn: &str, gate: TelemetryGate) -> Option<sentry::ClientInitGuard> {
    let parsed = match dsn.parse::<sentry::types::Dsn>() {
        Ok(dsn) => dsn,
        Err(error) => {
            log::warn!("Sentry DSN is invalid; error reporting stays disabled: {error}");
            return None;
        }
    };
    let mut options = sentry::ClientOptions::default();
    options.dsn = Some(parsed);
    options.release = sentry::release_name!();
    options.send_default_pii = false;
    options.shutdown_timeout = std::time::Duration::from_secs(2);
    options.before_send = Some(Arc::new(move |event| gate.allow().then_some(event)));
    // The SDK does not install a `log` subscriber automatically. Install once;
    // lower levels are ignored, including breadcrumbs collected before consent.
    static LOGGER: std::sync::Once = std::sync::Once::new();
    LOGGER.call_once(|| {
        let logger = sentry::integrations::log::SentryLogger::with_dest(LocalErrorLogger).filter(
            |metadata| {
                if metadata.level() == log::Level::Error {
                    sentry::integrations::log::LogFilter::Exception
                } else {
                    sentry::integrations::log::LogFilter::Ignore
                }
            },
        );
        if log::set_boxed_logger(Box::new(logger)).is_ok() {
            log::set_max_level(log::LevelFilter::Error);
        } else {
            eprintln!("Error-log reporting unavailable: a logger is already installed.");
        }
    });
    let guard = sentry::init(options);
    if guard.is_enabled() {
        Some(guard)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Exercise the production SDK options with an in-memory transport. No test
    // events or panic reports reach the project endpoint.
    fn capture(gate: TelemetryGate, f: impl FnOnce()) -> Vec<sentry::protocol::Event<'static>> {
        let hub = Arc::new(sentry::Hub::new(None, Default::default()));
        let mut events = Vec::new();
        sentry::Hub::run(hub, || {
            let guard = init("https://public@sentry.invalid/1", gate).unwrap();
            events = sentry::test::with_captured_events_options(f, guard.options().clone());
        });
        events
    }

    #[test]
    fn sdk_drops_events_without_explicit_consent() {
        for consent in [None, Some(false)] {
            assert!(capture(TelemetryGate::from_consent(consent), || {
                sentry::capture_message("declined", sentry::Level::Error);
            })
            .is_empty());
        }
    }

    #[test]
    fn sdk_applies_consent_changes_without_restart() {
        let gate = TelemetryGate::from_consent(None);
        let events = capture(gate.clone(), || {
            sentry::capture_message("unset", sentry::Level::Error);
            gate.set_consent(true);
            sentry::capture_message("accepted", sentry::Level::Error);
            gate.set_consent(false);
            sentry::capture_message("revoked", sentry::Level::Error);
            gate.set_consent(true);
            sentry::capture_message("accepted again", sentry::Level::Error);
        });
        let messages: Vec<_> = events
            .iter()
            .map(|event| event.message.as_deref())
            .collect();
        assert_eq!(messages, [Some("accepted"), Some("accepted again")]);
        assert!(events
            .iter()
            .all(|event| event.release.is_some() && event.user.is_none()));
    }

    #[test]
    fn error_logs_are_reported_without_lower_level_breadcrumbs() {
        let events = capture(TelemetryGate::from_consent(Some(true)), || {
            log::info!("not collected");
            log::warn!("not collected either");
            log::error!("report this error");
        });
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].level, sentry::Level::Error);
        assert!(events[0].breadcrumbs.is_empty());
    }

    #[test]
    fn panic_reports_obey_consent() {
        for enabled in [false, true] {
            let events = capture(TelemetryGate::from_consent(Some(enabled)), || {
                let _ = std::panic::catch_unwind(|| panic!("consent test panic"));
            });
            assert_eq!(events.len(), usize::from(enabled));
            if enabled {
                assert_eq!(
                    events[0].exception[0].value.as_deref(),
                    Some("consent test panic")
                );
            }
        }
    }

    #[test]
    fn logger_flush_does_not_panic() {
        capture(TelemetryGate::from_consent(Some(false)), || {
            assert!(std::panic::catch_unwind(|| log::logger().flush()).is_ok());
        });
    }

    #[test]
    fn invalid_dsn_does_not_panic_or_enable_reporting() {
        assert!(init("invalid", TelemetryGate::from_consent(Some(true))).is_none());
    }
}
