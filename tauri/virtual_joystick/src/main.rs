use std::io::{self, BufReader};
use virtual_joystick::{protocol::serve, vjoy::NativeVJoy};
fn main() {
    if std::env::args().nth(1).as_deref() != Some("serve") {
        eprintln!("usage: virtual_joystick serve");
        std::process::exit(2);
    }
    let vjoy = match NativeVJoy::load() {
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
