use std::io::{self, Read, Write};
use std::time::Duration;

pub trait SerialIo: Send {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize>;
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()>;
    fn flush(&mut self) -> io::Result<()>;
}

pub trait SerialTransport: Send + Sync + 'static {
    fn enumerate(&self) -> io::Result<Vec<String>>;
    fn open(&self, port: &str, baud: u32, timeout: Duration) -> io::Result<Box<dyn SerialIo>>;
}

#[derive(Default)]
pub struct NativeSerialTransport;

struct NativePort(Box<dyn serialport::SerialPort>);

impl SerialIo for NativePort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        self.0.read(buffer)
    }
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.0.write_all(bytes)
    }
    fn flush(&mut self) -> io::Result<()> {
        self.0.flush()
    }
}

impl SerialTransport for NativeSerialTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        serialport::available_ports()
            .map(|ports| ports.into_iter().map(|port| port.port_name).collect())
            .map_err(|error| io::Error::other(error.to_string()))
    }

    fn open(&self, port: &str, baud: u32, timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        serialport::new(port, baud)
            .timeout(timeout)
            .open()
            .map(|port| Box::new(NativePort(port)) as Box<dyn SerialIo>)
            .map_err(|error| io::Error::other(error.to_string()))
    }
}

pub fn is_ignored_port(port: &str) -> bool {
    let name = port.to_ascii_lowercase();
    ["bluetooth", "debug", "tone"]
        .iter()
        .any(|pattern| name.contains(pattern))
}

pub fn eligible_ports(mut ports: Vec<String>) -> Vec<String> {
    ports.retain(|port| !is_ignored_port(port));
    ports.sort();
    ports.dedup();
    ports
}
