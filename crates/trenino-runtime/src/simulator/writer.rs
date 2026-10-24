use super::client::{SimulatorClient, SimulatorError};
use std::{
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc,
    },
    time::Duration,
};
use tokio::sync::{mpsc, oneshot, watch, Mutex};
use trenino_core::simulator::{Endpoint, SimValue};

#[derive(Clone, Debug, PartialEq)]
pub struct SimulatorWrite {
    pub generation: u64,
    pub command_id: u64,
    pub endpoint: Endpoint,
    pub value: SimValue,
}
#[derive(Clone, Debug, PartialEq)]
pub enum WriteAck {
    Applied { command_id: u64 },
    Stale { command_id: u64 },
}
#[derive(Debug)]
pub enum WriterError {
    Closed,
    InvalidCapacity,
    QueueTimeout,
    GenerationWentBackwards,
    WorkerFailed,
    Simulator(SimulatorError),
}
impl From<SimulatorError> for WriterError {
    fn from(e: SimulatorError) -> Self {
        Self::Simulator(e)
    }
}
enum Message {
    Write(
        SimulatorWrite,
        oneshot::Sender<Result<WriteAck, WriterError>>,
    ),
}
enum Control {
    Advance(u64, oneshot::Sender<Result<(), WriterError>>),
}
#[derive(Clone)]
pub struct GenerationWriter {
    sender: mpsc::Sender<Message>,
    current: Arc<AtomicU64>,
    admission: Arc<Mutex<()>>,
    transition: Arc<Mutex<()>>,
    queue_wait: Duration,
    closed: Arc<AtomicBool>,
    shutdown: watch::Sender<bool>,
    ready: watch::Sender<bool>,
    control: mpsc::UnboundedSender<Control>,
    worker: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>,
}
impl GenerationWriter {
    pub fn new(
        client: SimulatorClient,
        generation: u64,
        capacity: usize,
    ) -> Result<Self, WriterError> {
        let wait = client.queue_wait_budget();
        Self::new_with_queue_wait(client, generation, capacity, wait)
    }
    pub fn new_with_queue_wait(
        client: SimulatorClient,
        generation: u64,
        capacity: usize,
        queue_wait: Duration,
    ) -> Result<Self, WriterError> {
        if capacity == 0 {
            return Err(WriterError::InvalidCapacity);
        }
        let (sender, mut receiver) = mpsc::channel(capacity);
        let current = Arc::new(AtomicU64::new(generation));
        let fence = current.clone();
        let (shutdown, mut shutdown_receiver) = watch::channel(false);
        let (ready, _) = watch::channel(false);
        let worker_ready = ready.clone();
        let (control, mut control_receiver) = mpsc::unbounded_channel();
        let worker = tokio::spawn(async move {
            loop {
                let message = tokio::select! {
                    biased;
                    changed = shutdown_receiver.changed() => {
                        if changed.is_err() || *shutdown_receiver.borrow() { break; }
                        continue;
                    }
                    control = control_receiver.recv() => {
                        match control {
                            Some(Control::Advance(generation, reply)) => {
                                if fence.load(Ordering::Acquire) == generation {
                                    worker_ready.send_replace(false);
                                    let _ = reply.send(Ok(()));
                                } else {
                                    let _ = reply.send(Err(WriterError::GenerationWentBackwards));
                                }
                            }
                            None => break,
                        }
                        continue;
                    }
                    message = receiver.recv() => message,
                };
                let Some(message) = message else { break };
                match message {
                    Message::Write(write, reply) => {
                        let result = if fence.load(Ordering::Acquire) != write.generation {
                            Ok(WriteAck::Stale {
                                command_id: write.command_id,
                            })
                        } else {
                            let sent = client.set_value(&write.endpoint, &write.value).await;
                            if fence.load(Ordering::Acquire) != write.generation {
                                Ok(WriteAck::Stale {
                                    command_id: write.command_id,
                                })
                            } else {
                                sent.map(|_| WriteAck::Applied {
                                    command_id: write.command_id,
                                })
                                .map_err(WriterError::Simulator)
                            }
                        };
                        let _ = reply.send(result);
                    }
                }
            }
        });
        Ok(Self {
            sender,
            current,
            admission: Arc::new(Mutex::new(())),
            transition: Arc::new(Mutex::new(())),
            queue_wait,
            closed: Arc::new(AtomicBool::new(false)),
            shutdown,
            ready,
            control,
            worker: Arc::new(Mutex::new(Some(worker))),
        })
    }
    pub async fn write(&self, write: SimulatorWrite) -> Result<WriteAck, WriterError> {
        let deadline = tokio::time::Instant::now() + self.queue_wait;
        let mut readiness = self.ready.subscribe();
        let receive = loop {
            let admission = tokio::time::timeout_at(deadline, self.admission.lock())
                .await
                .map_err(|_| WriterError::QueueTimeout)?;
            if self.closed.load(Ordering::Acquire) {
                return Err(WriterError::Closed);
            }
            if self.current.load(Ordering::Acquire) != write.generation {
                return Ok(WriteAck::Stale {
                    command_id: write.command_id,
                });
            }
            if *readiness.borrow() {
                drop(admission);
                tokio::time::timeout_at(deadline, readiness.changed())
                    .await
                    .map_err(|_| WriterError::QueueTimeout)?
                    .map_err(|_| WriterError::Closed)?;
                continue;
            }
            let (reply, receive) = oneshot::channel();
            tokio::time::timeout_at(
                deadline,
                self.sender.send(Message::Write(write.clone(), reply)),
            )
            .await
            .map_err(|_| WriterError::QueueTimeout)?
            .map_err(|_| WriterError::Closed)?;
            drop(admission);
            break receive;
        };
        receive.await.map_err(|_| WriterError::Closed)?
    }
    /// Invalidate old writes immediately, then await the serialized HTTP worker barrier.
    pub async fn advance_generation(&self, generation: u64) -> Result<(), WriterError> {
        let deadline = tokio::time::Instant::now() + self.queue_wait;
        let _transition = tokio::time::timeout_at(deadline, self.transition.lock())
            .await
            .map_err(|_| WriterError::QueueTimeout)?;
        if self.closed.load(Ordering::Acquire) {
            return Err(WriterError::Closed);
        }
        if generation <= self.current.load(Ordering::Acquire) {
            return Err(WriterError::GenerationWentBackwards);
        }
        self.current.store(generation, Ordering::Release);
        self.ready.send_replace(true);
        let (reply, receive) = oneshot::channel();
        if self
            .control
            .send(Control::Advance(generation, reply))
            .is_err()
        {
            self.ready.send_replace(false);
            return Err(WriterError::Closed);
        }
        receive.await.map_err(|_| WriterError::Closed)?
    }
    pub fn generation(&self) -> u64 {
        self.current.load(Ordering::Acquire)
    }

    /// Stop admission and await the owned worker. Repeated calls are safe.
    pub async fn shutdown(&self) -> Result<(), WriterError> {
        if !self.closed.swap(true, Ordering::AcqRel) {
            self.ready.send_replace(false);
            self.shutdown.send_replace(true);
        }
        let mut worker = self.worker.lock().await;
        if let Some(handle) = worker.as_mut() {
            handle.await.map_err(|_| WriterError::WorkerFailed)?;
            worker.take();
        }
        Ok(())
    }
}
