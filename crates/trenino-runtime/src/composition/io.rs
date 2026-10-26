//! Bounded sync/async boundary. Synchronous Lua/controller/MCP calls never enter
//! an existing Tokio runtime; an owned IO reactor executes cancellable requests.
use crate::mcp::ports::SimulatorPort;
use crate::simulator::{
    client::SimulatorClient, connection::SimulatorStatus, connection_owner::StatusSnapshot,
};
use crate::train::{
    output_controller::{SimulatorConnectionView, SimulatorSubscriptions},
    script::{ScriptValue, SimulatorSetPort},
};
use serde_json::Value;
use std::{
    future::Future,
    pin::Pin,
    sync::{mpsc, Arc, Mutex},
    time::{Duration, Instant},
};
use tokio::sync::mpsc as async_mpsc;
const DEADLINE: Duration = Duration::from_secs(3);
type Work = Pin<Box<dyn Future<Output = ()> + Send>>;
struct Request {
    deadline: Instant,
    work: Work,
}
#[derive(Clone)]
pub struct IoBridge {
    sender: async_mpsc::Sender<Request>,
    stop: tokio::sync::watch::Sender<bool>,
    host: Arc<Mutex<Option<std::thread::JoinHandle<()>>>>,
}
impl IoBridge {
    pub fn start() -> Self {
        let (sender, mut receiver) = async_mpsc::channel::<Request>(64);
        let (stop, mut stopped) = tokio::sync::watch::channel(false);
        let host = std::thread::Builder::new().name("trenino-io".into()).spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread().enable_all().build().expect("IO runtime");
            rt.block_on(async move { loop { tokio::select! {
                biased;
                _ = stopped.changed() => break,
                request = receiver.recv() => { let Some(request) = request else { break }; if request.deadline <= Instant::now() { continue; }
                    tokio::select! { biased; _ = stopped.changed() => break,
                        _ = tokio::time::timeout_at(request.deadline.into(), request.work) => {} }
                }
            } } });
        }).expect("IO host");
        Self {
            sender,
            stop,
            host: Arc::new(Mutex::new(Some(host))),
        }
    }
    pub fn call<T: Send + 'static>(
        &self,
        work: impl Future<Output = Result<T, String>> + Send + 'static,
    ) -> Result<T, String> {
        if *self.stop.borrow() {
            return Err("IO host stopped".into());
        }
        let (reply, response) = mpsc::sync_channel(1);
        self.sender
            .try_send(Request {
                deadline: Instant::now() + DEADLINE,
                work: Box::pin(async move {
                    let result = work.await;
                    let _ = reply.send(result);
                }),
            })
            .map_err(|_| "IO queue unavailable".to_string())?;
        response
            .recv_timeout(DEADLINE + Duration::from_millis(100))
            .map_err(|_| "IO deadline exceeded".to_string())?
    }
    pub fn shutdown(&self) {
        let _ = self.stop.send(true);
        if let Some(host) = self.host.lock().expect("IO host").take() {
            let _ = host.join();
        }
    }
}
#[derive(Clone)]
pub struct LiveSimulator {
    pub io: IoBridge,
    pub status: tokio::sync::watch::Receiver<StatusSnapshot>,
}
impl LiveSimulator {
    fn client(&self) -> Result<Arc<SimulatorClient>, String> {
        if self.status.has_changed().is_err() {
            return Err("simulator disconnected".into());
        }
        {
            let status = self.status.borrow();
            if status.status == SimulatorStatus::Connected {
                status.client.clone()
            } else {
                None
            }
        }
        .ok_or_else(|| "simulator disconnected".into())
    }
}
fn accepted_client_is_current(status: &StatusSnapshot, accepted: &Arc<SimulatorClient>) -> bool {
    status.status == SimulatorStatus::Connected
        && status
            .client
            .as_ref()
            .is_some_and(|client| Arc::ptr_eq(client, accepted))
}
async fn run_while_accepted<T>(
    mut status: tokio::sync::watch::Receiver<StatusSnapshot>,
    accepted: Arc<SimulatorClient>,
    work: impl Future<Output = Result<T, String>>,
) -> Result<T, String> {
    if status.has_changed().is_err()
        || !accepted_client_is_current(&status.borrow_and_update(), &accepted)
    {
        return Err("simulator disconnected or replaced".into());
    }
    tokio::pin!(work);
    loop {
        tokio::select! {
            biased;
            changed = status.changed() => {
                if changed.is_err()
                    || !accepted_client_is_current(&status.borrow_and_update(), &accepted)
                {
                    return Err("simulator disconnected or replaced".into());
                }
            }
            result = &mut work => {
                if status.has_changed().is_err()
                    || !accepted_client_is_current(&status.borrow_and_update(), &accepted)
                {
                    return Err("simulator disconnected or replaced".into());
                }
                return result;
            }
        }
    }
}
fn call_while_accepted<T: Send + 'static>(
    io: &IoBridge,
    status: &tokio::sync::watch::Receiver<StatusSnapshot>,
    accepted: Arc<SimulatorClient>,
    work: impl Future<Output = Result<T, String>> + Send + 'static,
) -> Result<T, String> {
    io.call(run_while_accepted(status.clone(), accepted, work))
}
impl SimulatorConnectionView for LiveSimulator {
    fn connected_client(&self) -> Option<Arc<dyn SimulatorSubscriptions>> {
        self.client().ok().map(|client| {
            Arc::new(Subscriptions {
                io: self.io.clone(),
                status: self.status.clone(),
                client,
            }) as _
        })
    }
}
struct Subscriptions {
    io: IoBridge,
    status: tokio::sync::watch::Receiver<StatusSnapshot>,
    client: Arc<SimulatorClient>,
}
impl SimulatorSubscriptions for Subscriptions {
    fn subscribe(&self, endpoint: &str, id: i64) -> Result<(), String> {
        let client = self.client.clone();
        let accepted = client.clone();
        let endpoint = endpoint.to_owned();
        call_while_accepted(&self.io, &self.status, accepted, async move {
            client
                .subscribe(&endpoint, id)
                .await
                .map(|_| ())
                .map_err(|e| e.to_string())
        })
    }
    fn get_subscription(&self, id: i64) -> Result<Value, String> {
        let client = self.client.clone();
        let accepted = client.clone();
        call_while_accepted(&self.io, &self.status, accepted, async move {
            client.get_subscription(id).await.map_err(|e| e.to_string())
        })
    }
    fn unsubscribe(&self, id: i64) -> Result<(), String> {
        let client = self.client.clone();
        self.io.call(async move {
            client
                .unsubscribe(id)
                .await
                .map(|_| ())
                .map_err(|e| e.to_string())
        })
    }
}
impl SimulatorPort for LiveSimulator {
    fn is_connected(&self) -> bool {
        self.client().is_ok()
    }
    fn list_endpoints(&self, path: Option<&str>) -> Result<Value, String> {
        let client = self.client()?;
        let accepted = client.clone();
        let path = path.map(str::to_owned);
        call_while_accepted(&self.io, &self.status, accepted, async move {
            client
                .list(path.as_deref())
                .await
                .map_err(|e| e.to_string())
        })
    }
    fn get_value(&self, path: &str) -> Result<Value, String> {
        let client = self.client()?;
        let accepted = client.clone();
        let path = path.to_owned();
        call_while_accepted(&self.io, &self.status, accepted, async move {
            client.get(&path).await.map_err(|e| e.to_string())
        })
    }
    fn set_value(&self, path: &str, value: &Value) -> Result<Value, String> {
        let client = self.client()?;
        let accepted = client.clone();
        let path = path.to_owned();
        let value = value.clone();
        call_while_accepted(&self.io, &self.status, accepted, async move {
            client.set(&path, &value).await.map_err(|e| e.to_string())
        })
    }
}
impl SimulatorSetPort for LiveSimulator {
    fn set(&self, path: &str, value: &ScriptValue) -> Result<(), String> {
        let value = match value {
            ScriptValue::Nil => Value::Null,
            ScriptValue::Boolean(v) => Value::from(*v),
            ScriptValue::Integer(v) => Value::from(*v),
            ScriptValue::Float(v) if v.is_finite() => Value::from(*v),
            ScriptValue::String(v) => Value::from(v.clone()),
            _ => return Err("non-transmissible Lua value".into()),
        };
        self.set_value(path, &value).map(|_| ())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::simulator::connection::SimulatorStatus;
    use std::{
        io::{BufRead, BufReader, Write},
        net::{TcpListener, TcpStream},
        sync::atomic::{AtomicBool, Ordering},
        thread,
    };

    struct TestServer {
        url: String,
        requests: Arc<Mutex<Vec<String>>>,
        hold_get: Arc<AtomicBool>,
        stop: Arc<AtomicBool>,
        host: Option<thread::JoinHandle<()>>,
    }
    impl TestServer {
        fn start() -> Self {
            let listener = TcpListener::bind("127.0.0.1:0").unwrap();
            listener.set_nonblocking(true).unwrap();
            let url = format!("http://{}", listener.local_addr().unwrap());
            let requests = Arc::new(Mutex::new(Vec::new()));
            let hold_get = Arc::new(AtomicBool::new(false));
            let stop = Arc::new(AtomicBool::new(false));
            let recorded = requests.clone();
            let held = hold_get.clone();
            let stopping = stop.clone();
            let host = thread::spawn(move || {
                let mut children = Vec::new();
                while !stopping.load(Ordering::Acquire) {
                    match listener.accept() {
                        Ok((stream, _)) => {
                            let requests = recorded.clone();
                            let hold_get = held.clone();
                            children.push(thread::spawn(move || serve(stream, requests, hold_get)));
                        }
                        Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                            thread::sleep(Duration::from_millis(1));
                        }
                        Err(e) => panic!("test server accept: {e}"),
                    }
                }
                for child in children {
                    child.join().unwrap();
                }
            });
            Self {
                url,
                requests,
                hold_get,
                stop,
                host: Some(host),
            }
        }
        fn client(&self) -> Arc<SimulatorClient> {
            Arc::new(SimulatorClient::new(&self.url, "test").unwrap())
        }
        fn requests(&self) -> Vec<String> {
            self.requests.lock().unwrap().clone()
        }
    }
    impl Drop for TestServer {
        fn drop(&mut self) {
            self.hold_get.store(false, Ordering::Release);
            self.stop.store(true, Ordering::Release);
            self.host.take().unwrap().join().unwrap();
        }
    }
    fn serve(mut stream: TcpStream, requests: Arc<Mutex<Vec<String>>>, hold_get: Arc<AtomicBool>) {
        // macOS can inherit the listener's nonblocking mode on accepted sockets.
        // This fixture uses blocking BufRead below, so normalize it explicitly.
        stream.set_nonblocking(false).unwrap();
        let mut reader = BufReader::new(stream.try_clone().unwrap());
        let mut first = String::new();
        reader.read_line(&mut first).unwrap();
        let mut line = String::new();
        loop {
            line.clear();
            if reader.read_line(&mut line).unwrap() == 0 || line == "\r\n" {
                break;
            }
        }
        requests.lock().unwrap().push(first.clone());
        if first.starts_with("GET /get/") {
            while hold_get.load(Ordering::Acquire) {
                thread::sleep(Duration::from_millis(1));
            }
        }
        let body = br#"{"Result":"Success","Values":{"InputValue":1}}"#;
        let _ = write!(
            stream,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            body.len()
        );
        let _ = stream.write_all(body);
    }
    fn accepted(client: Arc<SimulatorClient>) -> StatusSnapshot {
        StatusSnapshot {
            status: SimulatorStatus::Connected,
            last_error: None,
            info: None,
            health_failures: 0,
            client: Some(client),
        }
    }
    fn wait_for(predicate: impl Fn() -> bool) {
        let deadline = Instant::now() + Duration::from_secs(2);
        while !predicate() {
            assert!(Instant::now() < deadline, "condition did not become true");
            thread::sleep(Duration::from_millis(1));
        }
    }
    fn queued_write_after_change(replace_same_url: bool) {
        let server = TestServer::start();
        let client = server.client();
        let (status, receiver) = tokio::sync::watch::channel(accepted(client.clone()));
        let io = IoBridge::start();
        let live = LiveSimulator {
            io: io.clone(),
            status: receiver,
        };
        let (entered, entry) = mpsc::channel();
        let (release, blocked) = tokio::sync::oneshot::channel::<()>();
        let blocking_io = io.clone();
        let blocker = thread::spawn(move || {
            blocking_io.call(async move {
                entered.send(()).unwrap();
                blocked.await.unwrap();
                Ok(())
            })
        });
        entry.recv_timeout(Duration::from_secs(1)).unwrap();
        let writer = thread::spawn(move || live.set_value("Horn.InputValue", &Value::from(1)));
        wait_for(|| io.sender.capacity() == 63);
        assert!(server.requests().is_empty(), "queued write has not started");
        if replace_same_url {
            let new_client = server.client();
            assert!(!Arc::ptr_eq(&client, &new_client));
            status.send_modify(|s| *s = accepted(new_client));
        } else {
            status.send_modify(|s| {
                s.status = SimulatorStatus::Disconnected;
                s.client = None;
            });
        }
        release.send(()).unwrap();
        blocker.join().unwrap().unwrap();
        let result = writer.join().unwrap();
        io.shutdown();
        assert!(result.is_err(), "stale queued write returned {result:?}");
        assert!(
            server.requests().is_empty(),
            "stale write reached HTTP server"
        );
    }
    #[test]
    fn queued_write_does_not_start_after_disconnect() {
        queued_write_after_change(false);
    }
    #[test]
    fn queued_write_does_not_start_after_same_url_client_replacement() {
        queued_write_after_change(true);
    }
    #[test]
    fn in_flight_read_is_cancelled_when_accepted_client_disconnects() {
        let server = TestServer::start();
        server.hold_get.store(true, Ordering::Release);
        let (status, receiver) = tokio::sync::watch::channel(accepted(server.client()));
        let io = IoBridge::start();
        let live = LiveSimulator {
            io: io.clone(),
            status: receiver,
        };
        let (result, completed) = mpsc::channel();
        let reader = thread::spawn(move || {
            result.send(live.get_value("Throttle.InputValue")).unwrap();
        });
        wait_for(|| {
            server
                .requests()
                .iter()
                .any(|r| r.starts_with("GET /get/Throttle.InputValue"))
        });
        status.send_modify(|s| {
            s.status = SimulatorStatus::Disconnected;
            s.client = None;
        });
        let outcome = completed.recv_timeout(Duration::from_secs(1));
        server.hold_get.store(false, Ordering::Release);
        reader.join().unwrap();
        io.shutdown();
        assert!(
            outcome.unwrap().is_err(),
            "read must reject stale result before held HTTP response is released"
        );
    }
    #[test]
    fn old_subscription_can_unsubscribe_after_disconnect_but_cannot_read_or_subscribe() {
        let server = TestServer::start();
        let (status, receiver) = tokio::sync::watch::channel(accepted(server.client()));
        let io = IoBridge::start();
        let live = LiveSimulator {
            io: io.clone(),
            status: receiver,
        };
        let old = live.connected_client().unwrap();
        status.send_modify(|s| {
            s.status = SimulatorStatus::Disconnected;
            s.client = None;
        });
        assert!(old.subscribe("Throttle.InputValue", 99).is_err());
        assert!(old.get_subscription(99).is_err());
        old.unsubscribe(99).unwrap();
        io.shutdown();
        let requests = server.requests();
        assert_eq!(requests.len(), 1, "only cleanup may use the old client");
        assert!(requests[0].starts_with("DELETE /subscription"));
    }
    #[test]
    fn expired_queued_request_is_not_polled_and_shutdown_stays_bounded() {
        let io = IoBridge::start();
        let (entered, entry) = mpsc::channel();
        let (release, blocked) = tokio::sync::oneshot::channel::<()>();
        let blocking_io = io.clone();
        let blocker = thread::spawn(move || {
            blocking_io.call(async move {
                entered.send(()).unwrap();
                blocked.await.unwrap();
                Ok(())
            })
        });
        entry.recv_timeout(Duration::from_secs(1)).unwrap();
        let polled = Arc::new(AtomicBool::new(false));
        let flag = polled.clone();
        assert!(io
            .sender
            .try_send(Request {
                deadline: Instant::now() + Duration::from_millis(20),
                work: Box::pin(async move {
                    flag.store(true, Ordering::Release);
                }),
            })
            .is_ok());
        thread::sleep(Duration::from_millis(40));
        release.send(()).unwrap();
        blocker.join().unwrap().unwrap();
        let start = Instant::now();
        io.shutdown();
        assert!(start.elapsed() < Duration::from_secs(1));
        assert!(!polled.load(Ordering::Acquire));
    }
}
