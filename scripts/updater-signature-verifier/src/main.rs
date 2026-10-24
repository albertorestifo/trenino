use base64::{engine::general_purpose::STANDARD, Engine};
use minisign_verify::{PublicKey, Signature};
use std::{env, error::Error, fs, process::ExitCode};

// Tauri wraps the complete Minisign public key and signature in base64.
fn verify(public_key: &str, payload: &str, signature: &str) -> Result<(), Box<dyn Error>> {
    let public_key = String::from_utf8(STANDARD.decode(public_key.trim())?)?;
    let signature = String::from_utf8(STANDARD.decode(fs::read_to_string(signature)?.trim())?)?;
    PublicKey::decode(&public_key)?.verify(
        &fs::read(payload)?,
        &Signature::decode(&signature)?,
        true,
    )?;
    Ok(())
}

fn main() -> ExitCode {
    let args: Vec<_> = env::args().collect();
    if args.len() != 4 {
        eprintln!("Usage: updater-signature-verifier <public-key-base64> <payload> <signature>");
        return ExitCode::FAILURE;
    }
    match verify(&args[1], &args[2], &args[3]) {
        Ok(()) => ExitCode::SUCCESS,
        Err(_) => {
            eprintln!("Updater fixture signature verification failed.");
            ExitCode::FAILURE
        }
    }
}
