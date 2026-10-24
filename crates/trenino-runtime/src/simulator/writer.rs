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
    Advance(u64, oneshot::Sender<Result<(), WriterError>>),
}
#[derive(Clone)]
pub struct GenerationWriter {
    sender: mpsc::Sender<Message>,
    current: Arc<AtomicU64>,
    admission: Arc<Mutex<()>>,
    queue_wait: Duration,
    closed: Arc<AtomicBool>,
    shutdown: watch::Sender<bool>,
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
        let worker = tokio::spawn(async move {
            loop {
                let message = tokio::select! {
                    biased;
                    changed = shutdown_receiver.changed() => {
                        if changed.is_err() || *shutdown_receiver.borrow() { break; }
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
                    Message::Advance(generation, reply) => {
                        let result = if fence.load(Ordering::Acquire) == generation {
                            Ok(())
                        } else {
                            Err(WriterError::GenerationWentBackwards)
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
            queue_wait,
            closed: Arc::new(AtomicBool::new(false)),
            shutdown,
            worker: Arc::new(Mutex::new(Some(worker))),
        })
    }
    pub async fn write(&self, write: SimulatorWrite) -> Result<WriteAck, WriterError> {
        let admission = self.admission.lock().await;
        if self.closed.load(Ordering::Acquire) {
            return Err(WriterError::Closed);
        }
        if self.current.load(Ordering::Acquire) != write.generation {
            return Ok(WriteAck::Stale {
                command_id: write.command_id,
            });
        }
        let (reply, receive) = oneshot::channel();
        tokio::time::timeout(
            self.queue_wait,
            self.sender.send(Message::Write(write, reply)),
        )
        .await
        .map_err(|_| WriterError::QueueTimeout)?
        .map_err(|_| WriterError::Closed)?;
        drop(admission);
        receive.await.map_err(|_| WriterError::Closed)?
    }
    /// Invalidate old writes immediately, then await the serialized HTTP worker barrier.
    pub async fn advance_generation(&self, generation: u64) -> Result<(), WriterError> {
        let _admission = self.admission.lock().await;
        if self.closed.load(Ordering::Acquire) {
            return Err(WriterError::Closed);
        }
        if generation <= self.current.load(Ordering::Acquire) {
            return Err(WriterError::GenerationWentBackwards);
        }
        self.current.store(generation, Ordering::Release);
        let (reply, receive) = oneshot::channel();
        tokio::time::timeout(
            self.queue_wait,
            self.sender.send(Message::Advance(generation, reply)),
        )
        .await
        .map_err(|_| WriterError::QueueTimeout)?
        .map_err(|_| WriterError::Closed)?;
        receive.await.map_err(|_| WriterError::Closed)?
    }
    pub fn generation(&self) -> u64 {
        self.current.load(Ordering::Acquire)
    }

    /// Stop admission and await the owned worker. Repeated calls are safe.
    pub async fn shutdown(&self) -> Result<(), WriterError> {
        let _admission = self.admission.lock().await;
        if !self.closed.swap(true, Ordering::AcqRel) {
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
