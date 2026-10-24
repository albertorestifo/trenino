use std::future::Future;

// The tests exercise the sequencing contract without network or installers.
pub async fn apply_update<D, S, SF, I>(
    confirmed: bool,
    download: D,
    shutdown: S,
    install: I,
) -> Result<bool, String>
where
    D: Future<Output = Result<Vec<u8>, String>>,
    S: FnOnce() -> SF,
    SF: Future<Output = Result<(), String>>,
    I: FnOnce(Vec<u8>) -> Result<(), String>,
{
    if !confirmed {
        return Ok(false);
    }
    let bytes = download.await?;
    shutdown().await?;
    install(bytes)?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::sync::Arc;
    use std::task::{Context, Poll, Wake, Waker};

    fn run<F: Future>(future: F) -> F::Output {
        struct Noop;
        impl Wake for Noop {
            fn wake(self: Arc<Self>) {}
        }
        let waker = Waker::from(Arc::new(Noop));
        let mut context = Context::from_waker(&waker);
        let mut future = std::pin::pin!(future);
        match future.as_mut().poll(&mut context) {
            Poll::Ready(value) => value,
            Poll::Pending => panic!("test futures must be immediately ready"),
        }
    }

    #[test]
    fn cancel_does_not_download_stop_or_install() {
        assert_eq!(
            run(apply_update(
                false,
                async { panic!("download") },
                || async { panic!("shutdown") },
                |_| panic!("install")
            )),
            Ok(false)
        );
    }

    #[test]
    fn bad_download_or_signature_preserves_running_backend() {
        let result = run(apply_update(
            true,
            async { Err("invalid signature".into()) },
            || async { panic!("shutdown") },
            |_| panic!("install"),
        ));
        assert_eq!(result, Err("invalid signature".into()));
    }

    #[test]
    fn shutdown_failure_prevents_install() {
        let result = run(apply_update(
            true,
            async { Ok(vec![1]) },
            || async { Err("backend still running".into()) },
            |_| panic!("install"),
        ));
        assert_eq!(result, Err("backend still running".into()));
    }

    #[test]
    fn verified_download_precedes_shutdown_and_install() {
        let events = RefCell::new(Vec::new());
        let result = run(apply_update(
            true,
            async {
                events.borrow_mut().push("download");
                Ok(vec![1, 2])
            },
            || async {
                events.borrow_mut().push("shutdown");
                Ok(())
            },
            |bytes| {
                assert_eq!(bytes, vec![1, 2]);
                events.borrow_mut().push("install");
                Ok(())
            },
        ));
        assert_eq!(result, Ok(true));
        assert_eq!(*events.borrow(), vec!["download", "shutdown", "install"]);
    }

    #[test]
    fn installation_failure_is_not_success() {
        let result = run(apply_update(
            true,
            async { Ok(vec![1]) },
            || async { Ok(()) },
            |_| Err("installer failed".into()),
        ));
        assert_eq!(result, Err("installer failed".into()));
    }
}
