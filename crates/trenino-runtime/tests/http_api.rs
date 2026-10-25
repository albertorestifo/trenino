//! Legacy JSON API compatibility over the real loopback listener and DB worker.
use serde_json::{json, Value};
use std::sync::Arc;
use trenino_core::OperationId;
use trenino_runtime::{
    http_api::CompatibilityApi,
    mcp::{
        server::{McpServer, McpServerStatus},
        storage_ports::StoragePorts,
    },
    storage::{trains::TrainDraft, Database},
};

fn server() -> (tempfile::TempDir, Arc<Database>, McpServer, String, i64) {
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("api.db")).unwrap());
    db.allocate_epoch().unwrap();
    let train = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: "Class 66".into(),
                description: Some("Cargo".into()),
                identifiers: vec!["CL66".into()],
            },
        )
        .unwrap()
        .record;
    let ports = Arc::new(StoragePorts::new(db.clone()).into_ports());
    let server = McpServer::new(ports.clone(), None)
        .with_compatibility_api(CompatibilityApi::new(db.clone(), ports));
    let McpServerStatus::Running { address } = server.start(([127, 0, 0, 1], 0).into()).unwrap()
    else {
        panic!("listener refused")
    };
    (dir, db, server, format!("http://{address}"), train.id.0)
}
#[tokio::test]
async fn json_api_retains_numeric_ids_envelopes_and_script_crud() {
    let (_dir, _db, server, url, id) = server();
    let client = reqwest::Client::new();
    assert_eq!(
        client
            .get(format!("{url}/api/health"))
            .send()
            .await
            .unwrap()
            .json::<Value>()
            .await
            .unwrap(),
        json!({"status":"ok"})
    );
    let trains: Value = client
        .get(format!("{url}/api/trains"))
        .send()
        .await
        .unwrap()
        .json()
        .await
        .unwrap();
    assert_eq!(trains["trains"][0]["id"], id);
    assert_eq!(trains["trains"][0]["identifiers"], json!(["CL66"]));
    assert_eq!(
        client
            .get(format!("{url}/api/trains/9999"))
            .send()
            .await
            .unwrap()
            .status(),
        404
    );
    let response = client
        .post(format!("{url}/api/trains/{id}/scripts"))
        .json(&json!({"code":"print('x')"}))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), 422);
    assert_eq!(
        response.json::<Value>().await.unwrap()["errors"]["name"],
        json!(["can't be blank"])
    );
    let response=client.post(format!("{url}/api/trains/{id}/scripts")).json(&json!({"name":"Console","code":"function on_change(e) print(e.source) end","triggers":["Speed"]})).send().await.unwrap();
    assert_eq!(response.status(), 201);
    let created: Value = response.json().await.unwrap();
    let script = created["script"]["id"].as_i64().unwrap();
    assert_eq!(created["script"]["train_id"], id);
    assert!(created["script"]["inserted_at"]
        .as_str()
        .unwrap()
        .ends_with('Z'));
    assert_eq!(
        client
            .get(format!("{url}/api/trains/{id}/scripts"))
            .send()
            .await
            .unwrap()
            .json::<Value>()
            .await
            .unwrap()["scripts"][0]["id"],
        script
    );
    let changed: Value = client
        .patch(format!("{url}/api/scripts/{script}"))
        .json(&json!({"enabled":false}))
        .send()
        .await
        .unwrap()
        .json()
        .await
        .unwrap();
    assert_eq!(changed["script"]["enabled"], false);
    assert_eq!(
        client
            .delete(format!("{url}/api/scripts/{script}"))
            .send()
            .await
            .unwrap()
            .json::<Value>()
            .await
            .unwrap(),
        json!({"ok":true})
    );
    assert_eq!(
        client
            .get(format!("{url}/api/scripts/{script}"))
            .send()
            .await
            .unwrap()
            .status(),
        404
    );
    server.stop().unwrap();
}
#[tokio::test]
async fn simulator_api_preserves_missing_path_and_disconnected_errors() {
    let (_dir, _db, server, url, _id) = server();
    let client = reqwest::Client::new();
    let response = client
        .get(format!("{url}/api/simulator/value"))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), 400);
    assert_eq!(
        response.json::<Value>().await.unwrap(),
        json!({"error":"path parameter required"})
    );
    let response = client
        .get(format!("{url}/api/simulator/value?path=Speed"))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), 503);
    assert_eq!(
        response.json::<Value>().await.unwrap(),
        json!({"error":"simulator not connected"})
    );
    assert_eq!(
        client
            .get(format!("{url}/api/simulator/endpoints"))
            .send()
            .await
            .unwrap()
            .status(),
        503
    );
    assert_eq!(
        client
            .get(format!("{url}/api/outputs"))
            .send()
            .await
            .unwrap()
            .json::<Value>()
            .await
            .unwrap(),
        json!({"outputs":[]})
    );
    server.stop().unwrap();
}

#[tokio::test]
async fn script_list_surfaces_database_failure_instead_of_empty_success() {
    let (dir, _db, server, url, id) = server();
    rusqlite::Connection::open(dir.path().join("api.db"))
        .unwrap()
        .execute("DROP TABLE scripts", [])
        .unwrap();
    let response = reqwest::Client::new()
        .get(format!("{url}/api/trains/{id}/scripts"))
        .send()
        .await
        .unwrap();
    let status = response.status();
    let body: Value = response.json().await.unwrap();
    server.stop().unwrap();
    assert_eq!(
        status, 500,
        "storage failure must not say scripts vanished: {body}"
    );
}

struct HeldScripts {
    inner: Arc<dyn trenino_runtime::mcp::ports::ScriptsPort>,
    entered: Arc<std::sync::atomic::AtomicBool>,
    release: Arc<std::sync::atomic::AtomicBool>,
}
impl trenino_runtime::mcp::ports::ScriptsPort for HeldScripts {
    fn list_scripts(&self, id: i64) -> Vec<trenino_runtime::mcp::ports::ScriptRecord> {
        self.inner.list_scripts(id)
    }
    fn get_script(
        &self,
        id: i64,
    ) -> Result<trenino_runtime::mcp::ports::ScriptRecord, trenino_runtime::mcp::ports::PortError>
    {
        self.inner.get_script(id)
    }
    fn create_script(
        &self,
        id: i64,
        attrs: trenino_runtime::mcp::ports::ScriptAttrs,
    ) -> Result<trenino_runtime::mcp::ports::ScriptRecord, trenino_runtime::mcp::ports::PortError>
    {
        use std::sync::atomic::Ordering;
        self.entered.store(true, Ordering::SeqCst);
        while !self.release.load(Ordering::SeqCst) {
            std::thread::sleep(std::time::Duration::from_millis(2));
        }
        self.inner.create_script(id, attrs)
    }
    fn update_script(
        &self,
        s: &trenino_runtime::mcp::ports::ScriptRecord,
        a: trenino_runtime::mcp::ports::ScriptAttrs,
    ) -> Result<trenino_runtime::mcp::ports::ScriptRecord, trenino_runtime::mcp::ports::PortError>
    {
        self.inner.update_script(s, a)
    }
    fn delete_script(
        &self,
        s: &trenino_runtime::mcp::ports::ScriptRecord,
    ) -> Result<(), trenino_runtime::mcp::ports::PortError> {
        self.inner.delete_script(s)
    }
}
#[tokio::test]
async fn stop_refuses_acknowledgement_until_an_admitted_mutation_finishes() {
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::time::Duration;
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("jobs.db")).unwrap());
    db.allocate_epoch().unwrap();
    let train = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: "Held".into(),
                description: None,
                identifiers: vec!["HELD".into()],
            },
        )
        .unwrap()
        .record;
    let entered = Arc::new(AtomicBool::new(false));
    let release = Arc::new(AtomicBool::new(false));
    let mut ports = StoragePorts::new(db.clone()).into_ports();
    ports.scripts = Arc::new(HeldScripts {
        inner: ports.scripts.clone(),
        entered: entered.clone(),
        release: release.clone(),
    });
    let ports = Arc::new(ports);
    let server = Arc::new(
        McpServer::new(ports.clone(), None)
            .with_compatibility_api(CompatibilityApi::new(db.clone(), ports)),
    );
    let McpServerStatus::Running { address } = server.start(([127, 0, 0, 1], 0).into()).unwrap()
    else {
        panic!()
    };
    let request = tokio::spawn(async move {
        reqwest::Client::new()
            .post(format!(
                "http://{address}/api/trains/{}/scripts",
                train.id.0
            ))
            .json(&json!({"name":"Held","code":"print('held')"}))
            .send()
            .await
    });
    tokio::time::timeout(Duration::from_secs(3), async {
        while !entered.load(Ordering::SeqCst) {
            tokio::time::sleep(Duration::from_millis(2)).await;
        }
    })
    .await
    .unwrap();
    let stopping = server.clone();
    let result = tokio::task::spawn_blocking(move || stopping.stop())
        .await
        .unwrap();
    let status = server.status();
    release.store(true, Ordering::SeqCst);
    let _ = request.await;
    tokio::time::timeout(Duration::from_secs(3), async {
        while db.list_scripts(train.id).unwrap().is_empty() {
            tokio::time::sleep(Duration::from_millis(2)).await;
        }
    })
    .await
    .unwrap();
    server.stop().unwrap();
    assert!(
        result.is_err(),
        "server must report still-owned work instead of successful stop"
    );
    assert!(!matches!(status, McpServerStatus::Stopped));
}

#[test]
fn lifecycle_admission_fence_cannot_be_reopened_by_listener_retry() {
    use trenino_runtime::lifecycle::ShutdownParticipant;
    let (_dir, _db, server, _url, _id) = server();
    server.stop_admission().unwrap();
    server.stop().unwrap();
    let retry = server.start(([127, 0, 0, 1], 0).into());
    server.stop().unwrap();
    assert!(
        retry.is_err(),
        "listener retry must not reopen admission during coordinated shutdown"
    );
}
