use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use tauri::{
    menu::{MenuBuilder, SubmenuBuilder},
    Manager,
};
use tauri_plugin_dialog::{DialogExt, MessageDialogButtons, MessageDialogKind};
use tauri_plugin_updater::UpdaterExt;

static BUSY: AtomicBool = AtomicBool::new(false);

pub fn setup(app: &mut tauri::App) -> tauri::Result<()> {
    app.handle()
        .plugin(tauri_plugin_updater::Builder::new().build())?;
    app.handle().plugin(tauri_plugin_dialog::init())?;
    let help = SubmenuBuilder::new(app, "Help")
        .text("check_updates", "Check for Updates…")
        .build()?;
    app.set_menu(MenuBuilder::new(app).item(&help).build()?)?;
    app.on_menu_event(|app, event| {
        if event.id().as_ref() != "check_updates" || BUSY.swap(true, Ordering::SeqCst) {
            return;
        }
        let app = app.clone();
        tauri::async_runtime::spawn(async move {
            if let Err(error) = check(&app).await {
                app.dialog().message(format!(
                    "The update was not completed: {error}\n\nIf Trenino stopped responding, close and reopen it. You can retry from Help → Check for Updates."
                )).title("Trenino update failed").kind(MessageDialogKind::Error).blocking_show();
            }
            BUSY.store(false, Ordering::SeqCst);
        });
    });
    Ok(())
}

async fn check(app: &tauri::AppHandle) -> Result<(), String> {
    if app.state::<crate::BackendExited>().0.load(Ordering::SeqCst) {
        return Err("The backend has stopped. Restart Trenino before trying again.".into());
    }
    let update = app
        .updater_builder()
        .timeout(Duration::from_secs(120))
        .build()
        .map_err(|e| e.to_string())?
        .check()
        .await
        .map_err(|e| e.to_string())?;
    let Some(update) = update else {
        app.dialog()
            .message("You are using the latest stable version.")
            .title("Trenino updates")
            .blocking_show();
        return Ok(());
    };
    let confirmed = app.dialog().message(format!(
        "Trenino {} is available. Download and install it now?\n\nStop simulator control and wait for any firmware flashing to finish first. Trenino will close during installation.", update.version
    )).title("Update Trenino")
        .buttons(MessageDialogButtons::OkCancelCustom("Install update".into(), "Later".into()))
        .blocking_show();
    let installed = crate::update_flow::apply_update(
        confirmed,
        async {
            update
                .download(|_, _| {}, || {})
                .await
                .map_err(|e| e.to_string())
        },
        || shutdown_backend(app),
        |bytes| update.install(bytes).map_err(|e| e.to_string()),
    )
    .await?;
    if installed {
        app.restart();
    }
    Ok(())
}

async fn shutdown_backend(app: &tauri::AppHandle) -> Result<(), String> {
    reqwest::Client::new()
        .post(format!(
            "http://localhost:{}/api/shutdown",
            crate::BACKEND_PORT
        ))
        .timeout(Duration::from_secs(5))
        .send()
        .await
        .map_err(|e| format!("Could not request backend shutdown: {e}"))?
        .error_for_status()
        .map_err(|e| format!("Backend refused shutdown: {e}"))?;
    for _ in 0..150 {
        if app.state::<crate::BackendExited>().0.load(Ordering::SeqCst) {
            return Ok(());
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }
    Err("Backend did not exit within 15 seconds; installation was cancelled.".into())
}
