//! JSON compatibility routes retained from `TreninoWeb.Api.*Controller`.
//! Same DB owner/domain ports as MCP; IDs stay JSON numbers on this external
//! protocol. Desktop IPC continues to serialize entity IDs as strings.
use crate::{
    mcp::ports::{PortError, Ports, ScriptAttrs, ScriptRecord},
    storage::Database,
};
use axum::{
    body::Bytes,
    extract::{Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use serde_json::{json, Map, Value};
use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::Duration,
};

#[derive(Clone)]
pub struct CompatibilityApi {
    db: Arc<Database>,
    ports: Arc<Ports>,
    shutdown: Option<Arc<dyn Fn() + Send + Sync>>,
}
#[derive(Clone)]
struct ApiState {
    api: CompatibilityApi,
    admit: Arc<AtomicBool>,
    jobs: Arc<crate::mcp::jobs::JobDrain>,
}
impl CompatibilityApi {
    pub fn new(db: Arc<Database>, ports: Arc<Ports>) -> Self {
        Self {
            db,
            ports,
            shutdown: None,
        }
    }
    /// Callback requests the desktop's coordinated exit; never bypass cleanup.
    pub fn with_shutdown(mut self, shutdown: Arc<dyn Fn() + Send + Sync>) -> Self {
        self.shutdown = Some(shutdown);
        self
    }
    pub(crate) fn router(
        &self,
        admit: Arc<AtomicBool>,
        jobs: Arc<crate::mcp::jobs::JobDrain>,
    ) -> Router {
        Router::new()
            .route("/api/health", get(health))
            .route("/api/shutdown", post(shutdown))
            .route("/api/trains", get(trains))
            .route("/api/trains/{id}", get(train))
            .route("/api/trains/{id}/scripts", get(scripts).post(create_script))
            .route(
                "/api/scripts/{id}",
                get(script)
                    .put(update_script)
                    .patch(update_script)
                    .delete(delete_script),
            )
            .route("/api/outputs", get(outputs))
            .route("/api/simulator/endpoints", get(endpoints))
            .route("/api/simulator/value", get(value))
            .with_state(ApiState {
                api: self.clone(),
                admit,
                jobs,
            })
    }
}
fn response(status: StatusCode, value: Value) -> Response {
    (status, Json(value)).into_response()
}
fn error(error: PortError) -> Response {
    match error {
        PortError::NotFound => response(StatusCode::NOT_FOUND, json!({"error":"not found"})),
        PortError::Validation(errors) => response(
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"errors":errors.into_iter().map(|(field,messages)|(field,json!(messages))).collect::<Map<String,Value>>()}),
        ),
        _ => response(
            StatusCode::INTERNAL_SERVER_ERROR,
            json!({"error":"operation failed"}),
        ),
    }
}
async fn work(
    state: ApiState,
    operation: impl FnOnce(CompatibilityApi) -> Response + Send + 'static,
) -> Response {
    if !state.admit.load(Ordering::Acquire) {
        return response(
            StatusCode::SERVICE_UNAVAILABLE,
            json!({"error":"application shutting down"}),
        );
    }
    let Some(job) = state.jobs.admit() else {
        return response(
            StatusCode::SERVICE_UNAVAILABLE,
            json!({"error":"application shutting down"}),
        );
    };
    match tokio::task::spawn_blocking(move || {
        let _job = job;
        operation(state.api)
    })
    .await
    {
        Ok(response) => response,
        Err(_) => response(
            StatusCode::INTERNAL_SERVER_ERROR,
            json!({"error":"operation failed"}),
        ),
    }
}
async fn health(State(state): State<ApiState>) -> Response {
    work(state, |api| match api.db.list_firmware_releases() {
        Ok(_) => response(StatusCode::OK, json!({"status":"ok"})),
        Err(_) => response(
            StatusCode::SERVICE_UNAVAILABLE,
            json!({"status":"unavailable","reason":"database_unavailable"}),
        ),
    })
    .await
}
async fn shutdown(State(state): State<ApiState>) -> Response {
    let Some(shutdown) = state.api.shutdown else {
        return response(
            StatusCode::SERVICE_UNAVAILABLE,
            json!({"error":"shutdown unavailable"}),
        );
    };
    if !state.admit.load(Ordering::Acquire) {
        return response(
            StatusCode::SERVICE_UNAVAILABLE,
            json!({"error":"application shutting down"}),
        );
    }
    // This task is confined to the server runtime. Closing the listener's
    // runtime cancels it; the callback must use the native exit coordinator.
    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_millis(100)).await;
        shutdown();
    });
    response(StatusCode::OK, json!({"status":"shutting_down"}))
}
async fn trains(State(state): State<ApiState>) -> Response {
    work(state,|api|match api.ports.trains.list_trains() {
        Ok(trains)=>response(StatusCode::OK,json!({"trains":trains.into_iter().map(|t|json!({"id":t.id,"name":t.name,"identifiers":t.identifiers,"description":t.description})).collect::<Vec<_>>()})),
        Err(e)=>error(e),
    }).await
}
async fn train(State(state): State<ApiState>, Path(id): Path<i64>) -> Response {
    work(state,move|api|match api.ports.trains.get_train(id){
        Ok(t)=>response(StatusCode::OK,json!({"train":{"id":t.train.id,"name":t.train.name,"identifiers":t.train.identifiers,"description":t.train.description,
            "elements":t.elements.into_iter().map(|e|json!({"id":e.id,"name":e.name,"type":e.element_type})).collect::<Vec<_>>(),
            "output_bindings":t.output_bindings.into_iter().map(|b|json!({"id":b.id,"name":b.name,"endpoint":b.endpoint,"operator":b.operator,"output_id":b.output_id})).collect::<Vec<_>>()}})),
        Err(e)=>error(e),
    }).await
}
fn script_json(api: &CompatibilityApi, s: ScriptRecord) -> Result<Value, PortError> {
    let times = api
        .db
        .script_timestamps(trenino_core::EntityId(s.id))
        .map_err(|e| PortError::Failed(e.to_string()))?
        .ok_or(PortError::NotFound)?;
    Ok(
        json!({"id":s.id,"train_id":s.train_id,"name":s.name,"enabled":s.enabled,"code":s.code,"triggers":s.triggers,"inserted_at":timestamp(times.0),"updated_at":timestamp(times.1)}),
    )
}
fn timestamp(value: String) -> String {
    let value = value.replacen(' ', "T", 1);
    if value.ends_with('Z') {
        value
    } else if let Some(utc) = value.strip_suffix("+00:00") {
        format!("{utc}Z")
    } else {
        format!("{value}Z")
    }
}
async fn scripts(State(state): State<ApiState>, Path(id): Path<i64>) -> Response {
    work(state,move|api|{
        let scripts=match api.db.list_scripts(trenino_core::EntityId(id)) {
            Ok(scripts)=>scripts,Err(_)=>return response(StatusCode::INTERNAL_SERVER_ERROR,json!({"error":"operation failed"})),
        };
        let rows=scripts.into_iter().map(|s| {
            let (inserted,updated)=api.db.script_timestamps(s.id).map_err(|_|PortError::Failed("script timestamps unavailable".into()))?.ok_or(PortError::NotFound)?;
            Ok(json!({"id":s.id.0,"train_id":s.train_id.0,"name":s.name,"enabled":s.enabled,"code":s.code,"triggers":s.triggers,"inserted_at":timestamp(inserted),"updated_at":timestamp(updated)}))
        }).collect::<Result<Vec<_>,PortError>>();
        match rows {Ok(rows)=>response(StatusCode::OK,json!({"scripts":rows})),Err(e)=>error(e)}
    }).await
}
async fn script(State(state): State<ApiState>, Path(id): Path<i64>) -> Response {
    work(state, move |api| {
        match api
            .ports
            .scripts
            .get_script(id)
            .and_then(|s| script_json(&api, s))
        {
            Ok(script) => response(StatusCode::OK, json!({"script":script})),
            Err(e) => error(e),
        }
    })
    .await
}
fn attrs(body: &Bytes) -> Result<ScriptAttrs, Box<Response>> {
    let value: Value = serde_json::from_slice(body).map_err(|_| {
        Box::new(response(
            StatusCode::BAD_REQUEST,
            json!({"error":"invalid JSON"}),
        ))
    })?;
    let object = value.as_object().ok_or_else(|| {
        Box::new(response(
            StatusCode::BAD_REQUEST,
            json!({"error":"expected JSON object"}),
        ))
    })?;
    let invalid = |field: &str, message: &str| {
        Box::new(error(PortError::Validation(vec![(
            field.into(),
            vec![message.into()],
        )])))
    };
    let text = |field: &str| -> Result<Option<String>, Box<Response>> {
        match object.get(field) {
            None => Ok(None),
            Some(Value::String(s)) => Ok(Some(s.clone())),
            Some(Value::Null) => Err(invalid(field, "can't be blank")),
            Some(_) => Err(invalid(field, "is invalid")),
        }
    };
    let enabled = match object.get("enabled") {
        None => None,
        Some(Value::Bool(v)) => Some(*v),
        Some(Value::String(v)) if v == "true" || v == "false" => Some(v == "true"),
        Some(Value::Number(v)) if v.as_i64() == Some(0) || v.as_i64() == Some(1) => {
            Some(v.as_i64() == Some(1))
        }
        Some(_) => return Err(invalid("enabled", "is invalid")),
    };
    let triggers = match object.get("triggers") {
        None => None,
        Some(Value::Array(items)) => Some(
            items
                .iter()
                .map(|v| v.as_str().map(str::to_owned))
                .collect::<Option<Vec<_>>>()
                .ok_or_else(|| invalid("triggers", "must be a list of endpoint path strings"))?,
        ),
        Some(_) => return Err(invalid("triggers", "must be a list")),
    };
    Ok(ScriptAttrs {
        name: text("name")?,
        code: text("code")?,
        enabled,
        triggers,
    })
}
async fn create_script(
    State(state): State<ApiState>,
    Path(id): Path<i64>,
    body: Bytes,
) -> Response {
    let attrs = match attrs(&body) {
        Ok(a) => a,
        Err(e) => return *e,
    };
    let required = [
        ("name", attrs.name.as_deref()),
        ("code", attrs.code.as_deref()),
    ]
    .into_iter()
    .filter(|(_, value)| value.is_none_or(|value| value.trim().is_empty()))
    .map(|(field, _)| (field.to_string(), vec!["can't be blank".to_string()]))
    .collect::<Vec<_>>();
    if !required.is_empty() {
        return error(PortError::Validation(required));
    }
    work(state, move |api| {
        if matches!(api.ports.trains.get_train(id), Err(PortError::NotFound)) {
            return error(PortError::Validation(vec![(
                "train_id".into(),
                vec!["does not exist".into()],
            )]));
        }
        match api
            .ports
            .scripts
            .create_script(id, attrs)
            .and_then(|s| script_json(&api, s))
        {
            Ok(script) => response(StatusCode::CREATED, json!({"script":script})),
            Err(e) => error(e),
        }
    })
    .await
}
async fn update_script(
    State(state): State<ApiState>,
    Path(id): Path<i64>,
    body: Bytes,
) -> Response {
    let attrs = match attrs(&body) {
        Ok(a) => a,
        Err(e) => return *e,
    };
    work(state, move |api| {
        match api
            .ports
            .scripts
            .get_script(id)
            .and_then(|s| api.ports.scripts.update_script(&s, attrs))
            .and_then(|s| script_json(&api, s))
        {
            Ok(script) => response(StatusCode::OK, json!({"script":script})),
            Err(e) => error(e),
        }
    })
    .await
}
async fn delete_script(State(state): State<ApiState>, Path(id): Path<i64>) -> Response {
    work(state, move |api| {
        match api
            .ports
            .scripts
            .get_script(id)
            .and_then(|s| api.ports.scripts.delete_script(&s))
        {
            Ok(()) => response(StatusCode::OK, json!({"ok":true})),
            Err(e) => error(e),
        }
    })
    .await
}
async fn outputs(State(state): State<ApiState>) -> Response {
    work(state,|api|match api.db.hardware_snapshot(){Ok((hw,_))=>response(StatusCode::OK,json!({"outputs":hw.outputs.iter().map(|output|json!({"id":output.id.0,"name":output.name,"pin":output.pin,"device_id":output.device_id.0,"device_name":hw.devices.iter().find(|d|d.id==output.device_id).and_then(|d|d.name.as_ref())})).collect::<Vec<_>>()})),Err(_)=>response(StatusCode::INTERNAL_SERVER_ERROR,json!({"error":"operation failed"}))}).await
}
async fn simulator(state: ApiState, path: Option<String>, list: bool) -> Response {
    if !list && path.is_none() {
        return response(
            StatusCode::BAD_REQUEST,
            json!({"error":"path parameter required"}),
        );
    }
    work(state, move |api| {
        if !api.ports.simulator.is_connected() {
            return response(
                StatusCode::SERVICE_UNAVAILABLE,
                json!({"error":"simulator not connected"}),
            );
        }
        let result = if list {
            api.ports.simulator.list_endpoints(path.as_deref())
        } else {
            api.ports
                .simulator
                .get_value(path.as_deref().expect("path checked"))
        };
        match result {
            Ok(value) => response(StatusCode::OK, value),
            Err(reason) => response(StatusCode::BAD_GATEWAY, json!({"error":reason})),
        }
    })
    .await
}
async fn endpoints(
    State(state): State<ApiState>,
    Query(query): Query<HashMap<String, String>>,
) -> Response {
    simulator(state, query.get("path").cloned(), true).await
}
async fn value(
    State(state): State<ApiState>,
    Query(query): Query<HashMap<String, String>>,
) -> Response {
    simulator(state, query.get("path").cloned(), false).await
}
