use tauri::{Manager, WebviewUrl, WebviewWindowBuilder};
use tauri_plugin_shell::ShellExt;
use tauri_plugin_shell::process::CommandChild;
use std::sync::Mutex;
use std::time::Duration;

const BACKEND_PORT: u16 = 4000;
const MAX_RETRIES: u32 = 120; // 2 minutes max wait
const RETRY_DELAY_MS: u64 = 500;

/// State to hold the backend sidecar process handle for cleanup on exit
struct BackendProcess(Mutex<Option<CommandChild>>);

/// Check if the backend is fully ready (migrations complete) by checking health endpoint
fn check_backend_ready() -> Result<bool, String> {
    let url = format!("http://localhost:{}/api/health", BACKEND_PORT);
    match reqwest::blocking::get(&url) {
        Ok(response) => {
            if response.status().is_success() {
                Ok(true)
            } else {
                // Server is up but not ready (e.g., migrations running)
                Ok(false)
            }
        }
        Err(_) => {
            // Server not yet responding
            Ok(false)
        }
    }
}

/// Wait for the backend to become fully ready
fn wait_for_backend(handle: &tauri::AppHandle) -> bool {
    // Get the splash window to update status
    let splash_window = handle.get_webview_window("splash");

    for attempt in 1..=MAX_RETRIES {
        match check_backend_ready() {
            Ok(true) => {
                println!("Backend ready after {} attempts", attempt);
                return true;
            }
            Ok(false) => {
                // Update splash screen status
                if let Some(ref window) = splash_window {
                    let status = if attempt < 10 {
                        "Starting server..."
                    } else if attempt < 30 {
                        "Running database migrations..."
                    } else {
                        "Almost ready..."
                    };
                    let _ = window.eval(&format!(
                        "document.getElementById('status').textContent = '{}'",
                        status
                    ));
                }
            }
            Err(e) => {
                eprintln!("Health check error: {}", e);
            }
        }

        println!("Waiting for backend... attempt {}/{}", attempt, MAX_RETRIES);
        std::thread::sleep(Duration::from_millis(RETRY_DELAY_MS));
    }
    false
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .manage(BackendProcess(Mutex::new(None)))
        .setup(|app| {
            let handle = app.handle().clone();

            // Create splash screen window first
            let splash_html = include_str!("../splash.html");
            let splash_url = format!("data:text/html,{}", urlencoding::encode(splash_html));

            let splash_window = WebviewWindowBuilder::new(
                &handle,
                "splash",
                WebviewUrl::External(splash_url.parse().unwrap()),
            )
            .title("Trenino")
            .inner_size(400.0, 300.0)
            .resizable(false)
            .decorations(false)
            .center()
            .build()
            .expect("Failed to create splash window");

            // Spawn the Elixir backend as a sidecar process
            let sidecar = match handle.shell().sidecar("trenino_backend") {
                Ok(cmd) => cmd,
                Err(e) => {
                    eprintln!("Failed to create sidecar command: {}", e);
                    return Err(Box::new(e));
                }
            };

            let (mut _rx, child) = match sidecar
                .env("PORT", BACKEND_PORT.to_string())
                .env("MIX_ENV", "prod")
                .env("BURRITO", "1")
                .spawn()
            {
                Ok(result) => result,
                Err(e) => {
                    eprintln!("Failed to spawn backend sidecar: {}", e);
                    return Err(Box::new(e));
                }
            };

            // Store the child process handle in app state for cleanup on exit
            let backend_state: tauri::State<BackendProcess> = app.state();
            *backend_state.0.lock().unwrap() = Some(child);

            // Wait for backend to be ready in a separate thread
            let splash_handle = splash_window;
            std::thread::spawn(move || {
                if wait_for_backend(&handle) {
                    // Create the main window once backend is ready
                    let url = format!("http://localhost:{}", BACKEND_PORT);

                    let main_window = WebviewWindowBuilder::new(
                        &handle,
                        "main",
                        WebviewUrl::External(url.parse().unwrap()),
                    )
                    .title("Trenino")
                    .inner_size(1200.0, 800.0)
                    .min_inner_size(800.0, 600.0)
                    .build()
                    .expect("Failed to create main window");

                    // Close splash and show main window
                    let _ = splash_handle.close();
                    let _ = main_window.show();
                } else {
                    eprintln!("Backend failed to start after {} attempts", MAX_RETRIES);
                    // Show error on splash screen before exiting
                    let _ = splash_handle.eval(
                        "document.getElementById('status').textContent = 'Failed to start. Please restart the app.';\
                         document.getElementById('status').style.color = '#ef4444';"
                    );
                    std::thread::sleep(Duration::from_secs(3));
                    std::process::exit(1);
                }
            });

            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("Error while building trenino")
        .run(|app_handle, event| {
            if let tauri::RunEvent::ExitRequested { .. } = event {
                // Gracefully shut down the backend by calling the shutdown endpoint
                println!("App exit requested, initiating graceful backend shutdown");

                let shutdown_url = format!("http://localhost:{}/api/shutdown", BACKEND_PORT);
                let mut shutdown_succeeded = false;

                // Send POST request to shutdown endpoint
                // This tells the Elixir backend to call System.stop(0) which
                // gracefully shuts down the Erlang VM and all child processes
                match reqwest::blocking::Client::new()
                    .post(&shutdown_url)
                    .timeout(Duration::from_secs(2))
                    .send()
                {
                    Ok(response) => {
                        if response.status().is_success() {
                            println!("Backend shutdown initiated successfully");
                            shutdown_succeeded = true;
                        } else {
                            println!("Backend shutdown returned status: {}", response.status());
                        }
                    }
                    Err(e) => {
                        // Backend might already be down or unreachable
                        println!("Could not reach backend for shutdown: {}", e);
                    }
                }

                // If graceful shutdown succeeded, give it time to complete
                // Otherwise, fall back to killing the process directly
                if shutdown_succeeded {
                    std::thread::sleep(Duration::from_millis(500));
                } else if let Some(backend_state) = app_handle.try_state::<BackendProcess>() {
                    if let Ok(mut guard) = backend_state.0.lock() {
                        if let Some(child) = guard.take() {
                            println!("Falling back to forceful process termination");
                            let _ = child.kill();
                        }
                    }
                }
            }
        });
}
