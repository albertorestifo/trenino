use std::io::{self, BufReader};
use virtual_joystick::{protocol::serve, vjoy::NativeVJoy, vjoy_interface_path};
fn main() {
    let interface_path = match vjoy_interface_path(std::env::args_os()) {
        Ok(path) => path,
        Err(message) => {
            eprintln!("{message}");
            std::process::exit(2);
        }
    };
    let vjoy = match NativeVJoy::load(&interface_path) {
        Ok(vjoy) => vjoy,
        Err(error) => {
            eprintln!("failed to initialize vJoy: {error:?}");
            std::process::exit(1);
        }
    };
    if let Err(error) = serve(
        BufReader::new(io::stdin().lock()),
        &mut io::stdout().lock(),
        vjoy,
    ) {
        eprintln!("server error: {error}");
        std::process::exit(1);
    }
}
