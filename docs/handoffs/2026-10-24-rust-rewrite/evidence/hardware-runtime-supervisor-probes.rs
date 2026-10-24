#![allow(dead_code)]
#[path = "../../../crates/trenino-runtime/src/hardware/mod.rs"] mod hardware;
#[path = "../../../crates/trenino-runtime/src/routing.rs"] mod routing;
use std::{io, collections::VecDeque, sync::{Arc, mpsc, atomic::{AtomicBool, AtomicUsize, Ordering}}, time::Duration};
use hardware::{HardwareRuntime, PortEvent, discovery::DiscoveryTiming, transport::{SerialIo, SerialTransport}};
use trenino_core::{ConfigId, EntityId, hardware::protocol::{Message, FrameDecoder, encode_message, decode_message}};

struct FakeTransport { block: Arc<AtomicBool>, entered: Arc<AtomicBool>, drops: Arc<AtomicUsize>, coalesced: bool }
struct FakePort { queue: VecDeque<Vec<u8>>, block: Arc<AtomicBool>, entered: Arc<AtomicBool>, drops: Arc<AtomicUsize>, discovered: bool, coalesced: bool }
impl Drop for FakePort { fn drop(&mut self) { self.drops.fetch_add(1, Ordering::SeqCst); } }
impl SerialTransport for FakeTransport {
 fn enumerate(&self)->io::Result<Vec<String>> { Ok(vec!["FAKE".into()]) }
 fn open(&self,_:&str,_:u32,_:Duration)->io::Result<Box<dyn SerialIo>> { Ok(Box::new(FakePort { queue:VecDeque::new(),block:self.block.clone(), entered:self.entered.clone(),drops:self.drops.clone(),discovered:false,coalesced:self.coalesced })) }
}
fn frame(m: Message)->Vec<u8> {FrameDecoder::encode_frame(&encode_message(&m).unwrap())}
impl SerialIo for FakePort {
 fn read(&mut self,b:&mut [u8])->io::Result<usize> {
  if let Some(v)=self.queue.pop_front() { b[..v.len()].copy_from_slice(&v); self.discovered=true; return Ok(v.len()) }
  if self.discovered { self.entered.store(true,Ordering::SeqCst); while self.block.load(Ordering::SeqCst) { std::thread::sleep(Duration::from_millis(1)); } }
  Err(io::ErrorKind::TimedOut.into())
 }
 fn write_all(&mut self,b:&[u8])->io::Result<()> {if let Message::IdentityRequest{request_id}=decode_message(&FrameDecoder::default().push(b).remove(0).unwrap()).unwrap() { let mut v=frame(Message::IdentityResponse{request_id,major:1,minor:0,patch:0,config_id:1}); if self.coalesced { v.extend(frame(Message::InputValue{pin:2,value:1})); } self.queue.push_back(v); } Ok(()) }
 fn flush(&mut self)->io::Result<()> {Ok(())}
}
fn runtime(block:bool,coalesced:bool)->(hardware::DiscoveryHandle,mpsc::Receiver<PortEvent>,Arc<FakeTransport>) {
 let t=Arc::new(FakeTransport{block:Arc::new(AtomicBool::new(block)),entered:Arc::new(AtomicBool::new(false)),drops:Arc::new(AtomicUsize::new(0)),coalesced});
 let r=Arc::new(HardwareRuntime::new(t.clone(),DiscoveryTiming{settle:Duration::ZERO,read_timeout:Duration::from_millis(2),attempts:1}).with_policy(Duration::from_secs(60),Duration::from_secs(30),Duration::from_millis(20)));
 let (tx,rx)=mpsc::channel();let h=r.start(move|e|{let _=tx.send(e);});h.scan_now().unwrap();assert!(matches!(rx.recv_timeout(Duration::from_secs(2)).unwrap(),PortEvent::Discovered{..}));(h,rx,t)
}
#[test] fn probe_shutdown_reports_success_while_port_still_open() {
 let (h,rx,t)=runtime(true,false);for _ in 0..1000 { if t.entered.load(Ordering::SeqCst){break} std::thread::sleep(Duration::from_millis(1)); } assert!(t.entered.load(Ordering::SeqCst));
 let result=h.shutdown();let still_live=t.drops.load(Ordering::SeqCst)==0;t.block.store(false,Ordering::SeqCst);
 for _ in 0..1000 {if t.drops.load(Ordering::SeqCst)>0 {break} std::thread::sleep(Duration::from_millis(1));}
 assert!(result.is_ok());assert!(still_live);assert!(rx.try_iter().any(|e|matches!(e,PortEvent::Failed{reason,..} if reason.contains("cleanup deadline"))));assert_eq!(t.drops.load(Ordering::SeqCst),1);
}
#[test] fn probe_discovery_silently_loses_coalesced_input() { let (h,rx,_)=runtime(false,true);assert!(rx.recv_timeout(Duration::from_millis(50)).is_err());h.shutdown().unwrap(); }
#[test] fn probe_invalidated_resolver_can_be_resurrected() {let r=routing::InputResolver::default();let id=routing::InputIdentity{device_id:EntityId(1),input_id:EntityId(2)};let c=ConfigId::new(1).unwrap();assert!(r.replace_port("FAKE",5,c,[(2,id)]));assert!(r.invalidate_port("FAKE",5));assert!(r.replace_port("FAKE",5,c,[(2,id)]));assert_eq!(r.resolve("FAKE",5,c,2),Some(id));}
#[test] fn probe_second_handoff_overwrites_first_reservation() {let(h,rx,_)=runtime(false,false);let first=h.handoff_port("FAKE",Duration::from_secs(1)).unwrap();let second=h.handoff_port("FAKE",Duration::from_secs(1)).unwrap();assert_ne!(first.generation,second.generation);assert!(h.release_handoff(first,Duration::from_secs(1)).is_err());h.release_handoff(second,Duration::from_secs(1)).unwrap();loop{if matches!(rx.recv_timeout(Duration::from_secs(1)).unwrap(),PortEvent::Discovered{..}){break}}h.shutdown().unwrap();}
#[test] fn probe_detection_uses_baseline_after_registry_source_loss() {use hardware::sessions::{HardwareSessions,InputDetectionSession,InputKind,DetectionOutcome};let registry=HardwareSessions::default();let s=registry.insert_detection(trenino_core::SessionId(7),InputDetectionSession::new(InputKind::Button,Duration::from_secs(1))).unwrap();let id=Some(routing::InputIdentity{device_id:EntityId(1),input_id:EntityId(2)});assert_eq!(s.lock().unwrap().observe("FAKE",2,0,InputKind::Button,id),DetectionOutcome::Pending);registry.source_lost("FAKE",5);assert!(matches!(s.lock().unwrap().observe("FAKE",2,1,InputKind::Button,id),DetectionOutcome::Detected{..}));}
