//! HTTP API: loopback only, Host/Origin allowlist, cookie session, JSON errors.

use crate::config::{Config, KnowledgeKind};
use crate::knowledge::{FIXTURE_DOME, Hit, Knowledge};
use crate::presets;
use axum::Json;
use axum::Router;
use axum::extract::{Path, Query, Request, State};
use axum::http::{HeaderMap, HeaderValue, Method, StatusCode, header};
use axum::middleware::{self, Next};
use axum::response::sse::{Event as SseEvent, KeepAlive, Sse};
use axum::response::{IntoResponse, Response};
use axum::routing::{delete, get, post, put};
use futures_util::StreamExt;
use serde::Deserialize;
use serde_json::{Value, json};
use space_contracts::Sha256Hex;
use space_contracts::clock;
use space_contracts::model::{
    ErrorCode, ErrorEnvelope, Event, MessageStatus, NoteSourceRef, PrepareRequest, PresetId, Role, RunCreation,
    RunState, Span,
};
use space_core::context::{AssembleError, AssembleInput, HistoryTurn, ProfileSpec, SourceText, assemble};
use space_core::runtime::{ApiError, Runtime};
use space_store::StoreError;
use space_store::catalog::{self, CaptureRow};
use space_store::turns;
use std::collections::HashMap;
use std::convert::Infallible;
use std::sync::{Arc, Mutex};
use uuid::Uuid;

pub const COOKIE: &str = "space_session";
const IDLE_MS: i64 = 8 * 3_600_000;
const MAX_MS: i64 = 24 * 3_600_000;
pub const WEB_MAX_MS: i64 = MAX_MS;
const PAIRING_TTL_MS: i64 = 120_000;
const CANDIDATE_TTL_MS: i64 = 60_000;
const MAX_SPAN_BYTES: usize = 16 * 1024;

pub struct AppState {
    pub runtime: Runtime,
    pub config: Config,
    pub fixtures: Knowledge,
    pub vaults: Option<Arc<Knowledge>>,
    pub pairing: Mutex<HashMap<String, i64>>,
    pub candidates: Mutex<HashMap<Uuid, (Uuid, Hit, i64)>>,
}

pub type Shared = Arc<AppState>;

impl AppState {
    fn knowledge_for(&self, dome: &str) -> Option<&Knowledge> {
        if dome == FIXTURE_DOME { Some(&self.fixtures) } else { self.vaults.as_deref() }
    }

    /// Issues a one-time pairing code (called only from the private OS channel).
    pub fn issue_pairing_code(&self) -> String {
        let code = random_hex(32);
        let mut grouped = String::new();
        for (i, c) in code.chars().enumerate() {
            if i > 0 && i % 8 == 0 {
                grouped.push('-');
            }
            grouped.push(c);
        }
        if let Ok(mut m) = self.pairing.lock() {
            let now = clock::now_millis();
            m.retain(|_, exp| *exp > now);
            m.insert(Sha256Hex::of_bytes(code.as_bytes()).to_string(), now + PAIRING_TTL_MS);
        }
        grouped
    }
}

pub fn random_hex(bytes: usize) -> String {
    let mut buf = vec![0u8; bytes];
    // Without OS randomness no security token can be issued: stop rather than weaken.
    if getrandom::fill(&mut buf).is_err() {
        std::process::abort();
    }
    buf.iter().map(|b| format!("{b:02x}")).collect()
}

pub struct ApiFailure(StatusCode, ErrorEnvelope);

impl From<ApiError> for ApiFailure {
    fn from(e: ApiError) -> Self {
        fail(e.code, &e.message)
    }
}

impl IntoResponse for ApiFailure {
    fn into_response(self) -> Response {
        (self.0, Json(self.1)).into_response()
    }
}

pub fn fail(code: ErrorCode, message: &str) -> ApiFailure {
    let status = code.http_status().and_then(|s| StatusCode::from_u16(s).ok()).unwrap_or(StatusCode::BAD_GATEWAY);
    let message: String = message.chars().take(240).collect();
    ApiFailure(status, ErrorEnvelope { code, message, request_id: Uuid::now_v7(), retryable: false })
}

type ApiResult<T> = Result<T, ApiFailure>;

pub fn router(state: Shared, web_dir: Option<std::path::PathBuf>) -> Router {
    let api = Router::new()
        .route("/api/v1/health", get(health))
        .route("/api/v1/auth/session", post(login).delete(logout))
        .route("/api/v1/capabilities", get(capabilities))
        .route("/api/v1/projects", get(projects))
        .route("/api/v1/projects/{id}/catalog", get(catalog_handler))
        .route("/api/v1/projects/{id}/sessions", post(create_session).get(list_sessions))
        .route("/api/v1/projects/{id}/sources/search", post(search))
        .route("/api/v1/projects/{id}/sources/capture", post(capture))
        .route("/api/v1/sessions/{id}", delete(delete_session))
        .route("/api/v1/sessions/{id}/snapshot", get(snapshot))
        .route("/api/v1/sessions/{id}/events", get(events))
        .route("/api/v1/sessions/{id}/selection", put(put_selection))
        .route("/api/v1/sessions/{id}/prepare", post(prepare))
        .route("/api/v1/sessions/{id}/runs", post(create_run))
        .route("/api/v1/runs/{id}/cancel", post(cancel_run))
        .route("/api/v1/runs/{id}/manifest", get(manifest))
        .route("/api/v1/runs/{id}/export", get(export));
    let app = match web_dir {
        Some(dir) => api.fallback_service(tower_http::services::ServeDir::new(dir)),
        None => api,
    };
    app.layer(middleware::from_fn_with_state(state.clone(), guard)).with_state(state)
}

fn allowed_hosts(port: u16) -> [String; 2] {
    [format!("127.0.0.1:{port}"), format!("localhost:{port}")]
}

fn cookie_token(headers: &HeaderMap) -> Option<String> {
    headers.get_all(header::COOKIE).iter().filter_map(|v| v.to_str().ok()).flat_map(|v| v.split(';')).find_map(|kv| {
        let (k, v) = kv.trim().split_once('=')?;
        (k == COOKIE).then(|| v.to_owned())
    })
}

fn commit(tx: space_store::Transaction<'_>) -> Result<(), ApiError> {
    tx.commit().map_err(|e| ApiError::from(StoreError::from(e)))
}

/// An open event stream rechecks its cookie session this often and ends when it is no longer valid.
const SSE_REVALIDATE: std::time::Duration =
    if cfg!(test) { std::time::Duration::from_millis(50) } else { std::time::Duration::from_secs(5) };

async fn web_session_valid(st: &AppState, token: &str) -> bool {
    let hash = Sha256Hex::of_bytes(token.as_bytes());
    st.runtime
        .db(move |s| {
            let tx = s.begin()?;
            let ok = catalog::web_session_valid(&tx, &hash, &clock::utc_now(), IDLE_MS, MAX_MS)?;
            commit(tx)?;
            Ok(ok)
        })
        .await
        .unwrap_or(false)
}

/// Host/Origin allowlist, mutation markers and cookie session, before any body is read.
async fn guard(State(st): State<Shared>, req: Request, next: Next) -> Response {
    let headers = req.headers();
    let hosts = allowed_hosts(st.config.port);
    let host_ok = headers.get(header::HOST).and_then(|h| h.to_str().ok()).is_some_and(|h| hosts.iter().any(|a| a == h));
    let origin = headers.get(header::ORIGIN).and_then(|h| h.to_str().ok());
    let origin_ok = origin.is_none_or(|o| hosts.iter().any(|a| o == format!("http://{a}")));
    if !host_ok || !origin_ok {
        return fail(ErrorCode::OriginDenied, "origin not allowed").into_response();
    }
    let path = req.uri().path().to_owned();
    if !path.starts_with("/api/") {
        let mut resp = next.run(req).await;
        let h = resp.headers_mut();
        h.insert(
            header::CONTENT_SECURITY_POLICY,
            HeaderValue::from_static(
                "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'",
            ),
        );
        h.insert(header::X_CONTENT_TYPE_OPTIONS, HeaderValue::from_static("nosniff"));
        return resp;
    }
    let mutating = !matches!(*req.method(), Method::GET | Method::HEAD);
    if mutating && (origin.is_none() || headers.get("x-space-request").is_none_or(|v| v != "1")) {
        return fail(ErrorCode::OriginDenied, "missing same-origin request markers").into_response();
    }
    let public = path == "/api/v1/health" || (path == "/api/v1/auth/session" && req.method() == Method::POST);
    if !public {
        let Some(token) = cookie_token(headers) else {
            return fail(ErrorCode::Unauthenticated, "pairing required").into_response();
        };
        if !web_session_valid(&st, &token).await {
            return fail(ErrorCode::Unauthenticated, "session expired").into_response();
        }
    }
    next.run(req).await
}

async fn health() -> Json<Value> {
    Json(json!({"protocolVersion": 1, "status": "READY"}))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LoginBody {
    pairing_code: String,
}

async fn login(State(st): State<Shared>, Json(body): Json<LoginBody>) -> ApiResult<Response> {
    let code: String = body.pairing_code.chars().filter(|c| c.is_ascii_hexdigit()).collect::<String>().to_lowercase();
    let key = Sha256Hex::of_bytes(code.as_bytes()).to_string();
    let valid = st.pairing.lock().ok().and_then(|mut m| m.remove(&key)).is_some_and(|exp| exp > clock::now_millis());
    if !valid {
        return Err(fail(ErrorCode::Unauthenticated, "invalid or expired pairing code"));
    }
    let token = random_hex(32);
    let hash = Sha256Hex::of_bytes(token.as_bytes());
    st.runtime
        .db(move |s| {
            let tx = s.begin()?;
            catalog::insert_web_session(&tx, &hash, &clock::utc_now())?;
            commit(tx)
        })
        .await?;
    let cookie = format!("{COOKIE}={token}; HttpOnly; SameSite=Strict; Path=/");
    let mut resp = (StatusCode::CREATED, Json(json!({"ok": true}))).into_response();
    if let Ok(v) = HeaderValue::from_str(&cookie) {
        resp.headers_mut().insert(header::SET_COOKIE, v);
    }
    Ok(resp)
}

async fn logout(State(st): State<Shared>, headers: HeaderMap) -> ApiResult<Response> {
    if let Some(token) = cookie_token(&headers) {
        let hash = Sha256Hex::of_bytes(token.as_bytes());
        st.runtime
            .db(move |s| {
                let tx = s.begin()?;
                catalog::revoke_web_session(&tx, &hash)?;
                commit(tx)
            })
            .await?;
    }
    let mut resp = StatusCode::NO_CONTENT.into_response();
    resp.headers_mut().insert(
        header::SET_COOKIE,
        HeaderValue::from_static("space_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0"),
    );
    Ok(resp)
}

async fn capabilities(State(st): State<Shared>) -> Json<Value> {
    let vaults = if st.vaults.is_some() { "AVAILABLE" } else { "DISABLED" };
    Json(json!({
        "protocolVersion": 1,
        "limits": {"maxSources": 8, "maxHistoryMessages": 16, "maxPromptBytes": 16384, "maxBodyBytes": 65536},
        "capabilities": [
            {"id": "C01", "state": "AVAILABLE"}, {"id": "C02", "state": vaults}, {"id": "C03", "state": "AVAILABLE"},
            {"id": "C04", "state": "AVAILABLE"}, {"id": "C06", "state": "AVAILABLE"},
            {"id": "C12", "state": "BLOCKED", "reason": "los ficheros llegan en 0.3"},
            {"id": "C15", "state": "BLOCKED", "reason": "los efectos llegan en una versión posterior"}
        ]
    }))
}

async fn projects(State(st): State<Shared>) -> Json<Value> {
    let items: Vec<Value> = st
        .config
        .projects
        .iter()
        .map(|p| {
            let ready = p.knowledge == KnowledgeKind::Fixtures || st.vaults.is_some();
            json!({"id": p.id, "title": p.title, "state": if ready {"READY"} else {"UNAVAILABLE"},
                   "defaultAgent": p.default_agent, "defaultProfile": p.default_profile})
        })
        .collect();
    Json(json!({"items": items}))
}

fn project_of(st: &AppState, id: Uuid) -> ApiResult<&crate::config::ProjectConfig> {
    st.config.project(id).ok_or_else(|| fail(ErrorCode::NotFound, "not found"))
}

async fn catalog_handler(State(st): State<Shared>, Path(id): Path<Uuid>) -> ApiResult<Json<Value>> {
    let p = project_of(&st, id)?;
    let profiles: Vec<Value> = p
        .profile_ids
        .iter()
        .filter_map(|pid| st.config.profile(pid))
        .map(|pr| {
            json!({"id": pr.id, "kind": pr.kind, "model": pr.model, "state": "READY",
                   "contextWindow": pr.context_window, "outputReserve": pr.output_reserve})
        })
        .collect();
    let presets: Vec<Value> = [PresetId::Resume, PresetId::Compare, PresetId::DraftSpec]
        .into_iter()
        .map(|pid| {
            let pr = presets::preset(pid);
            json!({"id": pid, "version": pr.version, "minimumSources": pid.minimum_sources()})
        })
        .collect();
    let agent = presets::builtin_agent();
    Ok(Json(json!({
        "presets": presets,
        "agents": [{"ref": agent.r#ref, "title": "Agente de resumen", "bodyHash": agent.body_hash,
                    "declared": {"tools": [], "model": null}, "status": "LOADED"}],
        "skills": [],
        "profiles": profiles,
        "defaultProfile": p.default_profile,
        "domeIds": p.dome_ids,
    })))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct CreateSession {
    title: String,
    idempotency_key: String,
}

fn session_json(r: &space_store::SessionRow) -> Value {
    json!({"id": r.id, "projectId": r.project_id, "title": r.title, "revision": r.revision, "state": r.state,
           "createdAt": r.created_at, "updatedAt": r.updated_at})
}

async fn create_session(
    State(st): State<Shared>,
    Path(id): Path<Uuid>,
    Json(b): Json<CreateSession>,
) -> ApiResult<Response> {
    project_of(&st, id)?;
    if !(1..=120).contains(&b.title.len()) || !space_contracts::model::is_valid_key(&b.idempotency_key) {
        return Err(fail(ErrorCode::InvalidInput, "title 1–120 bytes and a valid idempotency key"));
    }
    let row = st.runtime.db(move |s| Ok(s.create_session(id, &b.title, &clock::utc_now())?)).await?;
    Ok((StatusCode::CREATED, Json(json!({"session": session_json(&row)}))).into_response())
}

async fn list_sessions(State(st): State<Shared>, Path(id): Path<Uuid>) -> ApiResult<Json<Value>> {
    project_of(&st, id)?;
    let rows = st
        .runtime
        .db(move |s| {
            let tx = s.begin()?;
            Ok(catalog::list_sessions(&tx, id, 50)?)
        })
        .await?;
    Ok(Json(json!({"items": rows.iter().map(session_json).collect::<Vec<_>>(), "nextCursor": null})))
}

async fn session_or_404(st: &AppState, id: Uuid) -> ApiResult<space_store::SessionRow> {
    let row = st.runtime.db(move |s| Ok(s.get_session(id)?)).await?;
    row.filter(|r| st.config.project(r.project_id).is_some()).ok_or_else(|| fail(ErrorCode::NotFound, "not found"))
}

async fn snapshot(State(st): State<Shared>, Path(id): Path<Uuid>) -> ApiResult<Json<Value>> {
    let session = session_or_404(&st, id).await?;
    let (watermark, runs, messages, selection) = st
        .runtime
        .db(move |s| {
            let tx = s.begin()?;
            let watermark: i64 = tx
                .query_row(
                    "SELECT COALESCE(MAX(sequence), 0) FROM events WHERE session_id = ?1",
                    [id.to_string()],
                    |r| r.get(0),
                )
                .map_err(StoreError::from)?;
            let runs = catalog::list_runs(&tx, id, 20)?;
            let msgs = turns::list_messages(&tx, id, watermark as u64 + 1, 50)?;
            let sel = catalog::get_selection(&tx, id)?;
            Ok((watermark as u64, runs, msgs, sel))
        })
        .await?;
    let runs: Vec<Value> = runs
        .into_iter()
        .map(|(rid, state, rev, reason, created)| {
            json!({"id": rid, "state": state, "revision": rev, "terminalReason": reason, "createdAt": created})
        })
        .collect();
    let messages: Vec<Value> = messages
        .into_iter()
        .map(|m| {
            json!({"id": m.id, "runId": m.run_id, "role": m.role, "status": m.status,
                   "createdSequence": m.created_sequence, "text": m.text,
                   "citations": serde_json::from_str::<Value>(&m.citations).unwrap_or(json!([])),
                   "validation": m.validation.as_deref().and_then(|v| serde_json::from_str::<Value>(v).ok())})
        })
        .collect();
    let selection = selection.map(|s| {
        json!({"id": s.id, "revision": s.revision,
               "sources": serde_json::from_str::<Value>(&s.refs).unwrap_or(json!([]))})
    });
    Ok(Json(json!({"session": session_json(&session), "watermark": watermark, "runs": runs,
                   "messages": messages, "selection": selection})))
}

#[derive(Deserialize)]
struct AfterQuery {
    after: Option<u64>,
}

async fn events(
    State(st): State<Shared>,
    Path(id): Path<Uuid>,
    Query(q): Query<AfterQuery>,
    headers: HeaderMap,
) -> ApiResult<Sse<impl futures_util::Stream<Item = Result<SseEvent, Infallible>>>> {
    session_or_404(&st, id).await?;
    let last_event: Option<u64> =
        headers.get("last-event-id").and_then(|v| v.to_str().ok()).and_then(|v| v.parse().ok());
    let after = last_event.or(q.after).unwrap_or(0);
    let watermark = st.runtime.db(move |s| Ok(s.watermark(id)?)).await?;
    if after > watermark {
        return Err(fail(ErrorCode::InvalidInput, "cursor is ahead of the journal"));
    }
    // Subscribe before reading the backlog, then skip anything already sent.
    let live = tokio_stream::wrappers::BroadcastStream::new(st.runtime.subscribe());
    let backlog = st.runtime.events_after(id, after).await?;
    let mut last = backlog.last().map(|e| e.sequence).unwrap_or(after);
    let first = futures_util::stream::iter(backlog.into_iter().map(to_sse));
    // A lagged receiver ends the stream: the client reconnects with Last-Event-ID (no silent gaps).
    let rest = live.take_while(|r| std::future::ready(r.is_ok())).filter_map(move |r| {
        let ev = r.ok().filter(|e| e.session_id == id && e.sequence > last);
        if let Some(e) = &ev {
            last = e.sequence;
        }
        std::future::ready(ev.map(to_sse))
    });
    // Revocation, idle or absolute expiry of the cookie session closes a stream that is already open.
    let token = cookie_token(&headers).unwrap_or_default();
    let watch = st.clone();
    let revoked = async move {
        loop {
            tokio::time::sleep(SSE_REVALIDATE).await;
            if !web_session_valid(&watch, &token).await {
                break;
            }
        }
    };
    Ok(Sse::new(first.chain(rest).take_until(Box::pin(revoked)))
        .keep_alive(KeepAlive::new().interval(std::time::Duration::from_secs(15))))
}

fn to_sse(e: Event) -> Result<SseEvent, Infallible> {
    let kind =
        serde_json::to_value(&e.body).ok().and_then(|v| v["type"].as_str().map(str::to_owned)).unwrap_or_default();
    let data = serde_json::to_string(&e).unwrap_or_default();
    Ok(SseEvent::default().id(e.sequence.to_string()).event(kind).data(data))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SearchBody {
    queries: Vec<String>,
    dome_ids: Option<Vec<String>>,
    limit: Option<usize>,
}

async fn search(State(st): State<Shared>, Path(id): Path<Uuid>, Json(b): Json<SearchBody>) -> ApiResult<Json<Value>> {
    let p = project_of(&st, id)?.clone();
    if b.queries.is_empty() || b.queries.len() > 3 || b.queries.iter().any(|q| q.is_empty() || q.len() > 512) {
        return Err(fail(ErrorCode::InvalidInput, "1–3 queries of 1–512 bytes"));
    }
    let domes: Vec<String> = b.dome_ids.unwrap_or_else(|| p.dome_ids.clone());
    if domes.iter().any(|d| !p.dome_ids.contains(d)) {
        return Err(fail(ErrorCode::NotFound, "not found"));
    }
    let limit = b.limit.unwrap_or(8).clamp(1, 8);
    let k = match p.knowledge {
        KnowledgeKind::Fixtures => &st.fixtures,
        KnowledgeKind::Vaults => {
            st.vaults.as_deref().ok_or_else(|| fail(ErrorCode::Unavailable, "Vaults not configured"))?
        }
    };
    let hits = k.search(&b.queries, &domes, limit).await.map_err(|e| fail(ErrorCode::Unavailable, &e.to_string()))?;
    let now = clock::now_millis();
    let mut out = Vec::new();
    if let Ok(mut map) = st.candidates.lock() {
        map.retain(|_, (_, _, exp)| *exp > now);
        for h in hits {
            let cid = Uuid::now_v7();
            out.push(json!({"id": cid, "domeId": h.dome_id, "resourceId": h.resource_id, "heading": h.heading,
                            "snippet": h.snippet, "indexState": if h.degraded {"DEGRADED"} else {"OK"}}));
            map.insert(cid, (id, h, now + CANDIDATE_TTL_MS));
        }
    }
    Ok(Json(json!({"candidates": out, "warnings": []})))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct CaptureBody {
    candidate_id: Uuid,
}

/// End of the span that fits in 16 KiB, in code points, and whether it covers the whole text.
fn span_end(text: &str) -> (u64, bool) {
    let mut bytes = 0;
    let mut chars = 0u64;
    for c in text.chars() {
        if bytes + c.len_utf8() > MAX_SPAN_BYTES {
            return (chars, false);
        }
        bytes += c.len_utf8();
        chars += 1;
    }
    (chars, true)
}

async fn capture(State(st): State<Shared>, Path(id): Path<Uuid>, Json(b): Json<CaptureBody>) -> ApiResult<Json<Value>> {
    project_of(&st, id)?;
    let candidate = st
        .candidates
        .lock()
        .ok()
        .and_then(|m| m.get(&b.candidate_id).cloned())
        .filter(|(pid, _, exp)| *pid == id && *exp > clock::now_millis())
        .ok_or_else(|| fail(ErrorCode::Conflict, "candidate expired; search again"))?;
    let hit = candidate.1;
    let k = st.knowledge_for(&hit.dome_id).ok_or_else(|| fail(ErrorCode::Unavailable, "knowledge unavailable"))?;
    let note = k
        .read(&hit.dome_id, &hit.resource_id)
        .await
        .map_err(|e| fail(ErrorCode::Unavailable, &e.to_string()))?
        .ok_or_else(|| fail(ErrorCode::NotFound, "not found"))?;
    let (end, full) = span_end(&note.text_base);
    let row = CaptureRow {
        id: Uuid::now_v7(),
        project_id: id,
        session_id: None,
        dome_id: note.dome_id.clone(),
        resource_id: note.resource_id.clone(),
        title: note.title.clone(),
        content_hash: note.content_hash.clone(),
        text_base: note.text_base.clone(),
        obtained_at: clock::utc_now(),
    };
    let stored = row.clone();
    st.runtime
        .db(move |s| {
            let tx = s.begin()?;
            catalog::purge_orphan_captures(&tx, &clock::format_utc_millis(clock::now_millis() - CANDIDATE_TTL_MS))?;
            catalog::insert_capture(&tx, &stored)?;
            commit(tx)
        })
        .await?;
    let shown: String = note.text_base.chars().take(end as usize).collect();
    Ok(Json(json!({
        "captureId": row.id,
        "title": note.title,
        "ref": NoteSourceRef { dome_id: note.dome_id, resource_id: note.resource_id, content_hash: note.content_hash,
                               span: Span { start: 0, end } },
        "text": shown,
        "coverage": if full {"FULL"} else {"EXCERPT"},
        "obtainedAt": row.obtained_at,
    })))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SelectionBody {
    capture_ids: Vec<Uuid>,
    expected_revision: u64,
    idempotency_key: String,
}

async fn put_selection(
    State(st): State<Shared>,
    Path(id): Path<Uuid>,
    Json(b): Json<SelectionBody>,
) -> ApiResult<Json<Value>> {
    let session = session_or_404(&st, id).await?;
    if b.capture_ids.is_empty() || b.capture_ids.len() > 8 || !space_contracts::model::is_valid_key(&b.idempotency_key)
    {
        return Err(fail(ErrorCode::InvalidInput, "1–8 sources and a valid idempotency key"));
    }
    let project = session.project_id;
    let (rev, sel) = st
        .runtime
        .db(move |s| {
            let tx = s.begin()?;
            let mut sources = Vec::new();
            for (i, cid) in b.capture_ids.iter().enumerate() {
                let c = catalog::get_capture(&tx, *cid)?
                    .filter(|c| c.project_id == project && c.session_id.is_none_or(|sid| sid == id))
                    .ok_or_else(|| ApiError::new(ErrorCode::NotFound, "capture not found"))?;
                catalog::bind_capture(&tx, c.id, id)?;
                let (end, _) = span_end(&c.text_base);
                sources.push(json!({"index": i, "captureId": c.id, "title": c.title,
                    "ref": NoteSourceRef { dome_id: c.dome_id, resource_id: c.resource_id,
                        content_hash: c.content_hash, span: Span { start: 0, end } }}));
            }
            let refs = Value::Array(sources).to_string();
            let rev = catalog::put_selection(&tx, id, b.expected_revision, &refs)?
                .ok_or_else(|| ApiError::new(ErrorCode::StaleRevision, "selection changed"))?;
            let sel = catalog::get_selection(&tx, id)?;
            commit(tx)?;
            Ok((rev, sel))
        })
        .await?;
    let sel = sel.ok_or_else(|| fail(ErrorCode::Unavailable, "selection lost"))?;
    Ok(Json(json!({"id": sel.id, "revision": rev,
                   "sources": serde_json::from_str::<Value>(&sel.refs).unwrap_or(json!([]))})))
}

fn profile_spec(st: &AppState, id: &str) -> ApiResult<ProfileSpec> {
    let pr = st.config.profile(id).ok_or_else(|| fail(ErrorCode::NotFound, "profile not found"))?;
    let revision = Sha256Hex::of_canonical(&serde_json::to_value(pr).unwrap_or_default())
        .map_err(|e| fail(ErrorCode::Unavailable, &e.to_string()))?;
    Ok(ProfileSpec {
        id: pr.id.clone(),
        revision,
        model: pr.model.clone(),
        model_digest: format!("name:{}", pr.model),
        adapter_revision: Sha256Hex::of_bytes(format!("{:?}-adapter-v1", pr.kind).as_bytes()),
        context_window: pr.context_window,
        output_reserve: pr.output_reserve,
        margin_tokens: pr.margin_tokens,
    })
}

async fn prepare(
    State(st): State<Shared>,
    Path(id): Path<Uuid>,
    Json(req): Json<PrepareRequest>,
) -> ApiResult<Response> {
    req.validate().map_err(|e| fail(ErrorCode::InvalidInput, &e.to_string()))?;
    let session = session_or_404(&st, id).await?;
    let project = project_of(&st, session.project_id)?.clone();
    if !project.profile_ids.contains(&req.provider_profile_id) {
        return Err(fail(ErrorCode::UnsupportedCapability, "profile not allowed for this project"));
    }
    let preset = presets::preset(req.preset_id);
    if preset.version != req.preset_version {
        return Err(fail(ErrorCode::ContextChanged, "preset changed; reload the catalog"));
    }
    let agent = presets::builtin_agent();
    if req.agent_ref != agent.r#ref || !req.skill_refs.is_empty() {
        return Err(fail(ErrorCode::UnsupportedCapability, "agent or skills not available"));
    }
    let history_ids = req.history_message_ids.clone();
    let (selection, captures, history) = st
        .runtime
        .db(move |s| {
            let tx = s.begin()?;
            let sel = catalog::get_selection(&tx, id)?;
            let mut caps = Vec::new();
            if let Some(sel) = &sel {
                let items: Vec<Value> = serde_json::from_str(&sel.refs).unwrap_or_default();
                for it in items {
                    let cid = it["captureId"].as_str().and_then(|c| Uuid::parse_str(c).ok()).unwrap_or_default();
                    caps.push(catalog::get_capture(&tx, cid)?);
                }
            }
            let mut history = Vec::new();
            for hid in history_ids {
                history.push(turns::get_session_message(&tx, id, hid)?);
            }
            Ok((sel, caps, history))
        })
        .await?;
    let selection = selection.ok_or_else(|| fail(ErrorCode::InvalidInput, "select sources first"))?;
    if selection.id != req.selection_id || selection.revision != req.selection_revision {
        return Err(fail(ErrorCode::StaleRevision, "selection changed"));
    }
    let mut sources = Vec::new();
    for (i, cap) in captures.into_iter().enumerate() {
        let cap = cap.ok_or_else(|| fail(ErrorCode::NotFound, "not found"))?;
        let k = st.knowledge_for(&cap.dome_id).ok_or_else(|| fail(ErrorCode::Unavailable, "knowledge unavailable"))?;
        let current =
            k.read(&cap.dome_id, &cap.resource_id).await.map_err(|e| fail(ErrorCode::Unavailable, &e.to_string()))?;
        if current.as_ref().map(|n| &n.content_hash) != Some(&cap.content_hash) {
            return Err(fail(
                ErrorCode::ContextChanged,
                "a source changed or is no longer accessible; capture it again",
            ));
        }
        let (end, _) = span_end(&cap.text_base);
        sources.push(SourceText {
            index: i as u8,
            title: cap.title.clone(),
            r#ref: NoteSourceRef {
                dome_id: cap.dome_id,
                resource_id: cap.resource_id,
                content_hash: cap.content_hash,
                span: Span { start: 0, end },
            },
            text: cap.text_base.chars().take(end as usize).collect(),
        });
    }
    let mut turns_in = Vec::new();
    for m in history {
        let m = m
            .filter(|m| m.status == MessageStatus::Final)
            .ok_or_else(|| fail(ErrorCode::ContextLimit, "history must be complete turns of this session"))?;
        turns_in.push(HistoryTurn { message_id: m.id, role: m.role, text: m.text });
    }
    if turns_in.iter().filter(|h| h.role == Role::User).count()
        != turns_in.iter().filter(|h| h.role == Role::Assistant).count()
    {
        return Err(fail(ErrorCode::ContextLimit, "history must be complete turns"));
    }
    let profile = profile_spec(&st, &req.provider_profile_id)?;
    let prepared = assemble(&AssembleInput {
        session_id: id,
        run_id: Uuid::now_v7(),
        manifest_id: Uuid::now_v7(),
        selection_revision: selection.revision,
        preset: &preset,
        agent: &agent,
        skills: &[],
        sources: &sources,
        history: &turns_in,
        prompt: &req.prompt,
        profile: &profile,
        now_millis: clock::now_millis(),
    })
    .map_err(|e| match e {
        AssembleError::TooFewSources => fail(ErrorCode::InvalidInput, "this preset needs more sources"),
        AssembleError::ContextLimit | AssembleError::TooManySources => {
            fail(ErrorCode::ContextLimit, "the context does not fit; remove sources or history")
        }
        other => fail(ErrorCode::InvalidInput, &other.to_string()),
    })?;
    let info = st.runtime.save_preview(id, &req, prepared).await?;
    Ok((
        StatusCode::CREATED,
        Json(json!({
            "id": info.preview_id, "sessionId": id, "runId": info.run_id, "requestHash": info.request_hash,
            "manifest": info.manifest, "manifestHash": info.manifest_hash, "payloadHash": info.payload_hash,
            "bodyText": info.body_text, "expiresAt": info.expires_at,
        })),
    )
        .into_response())
}

async fn create_run(State(st): State<Shared>, Path(id): Path<Uuid>, Json(c): Json<RunCreation>) -> ApiResult<Response> {
    session_or_404(&st, id).await?;
    let resp = st.runtime.admit(id, c).await?;
    Ok((StatusCode::ACCEPTED, Json(json!({"runId": resp.run_id, "state": resp.state, "requestId": Uuid::now_v7()})))
        .into_response())
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct CancelBody {
    idempotency_key: String,
}

async fn cancel_run(State(st): State<Shared>, Path(id): Path<Uuid>, Json(b): Json<CancelBody>) -> ApiResult<Response> {
    if !space_contracts::model::is_valid_key(&b.idempotency_key) {
        return Err(fail(ErrorCode::InvalidInput, "invalid idempotency key"));
    }
    let state = st.runtime.cancel(id).await?;
    let code = if state.is_terminal() { StatusCode::OK } else { StatusCode::ACCEPTED };
    Ok((code, Json(json!({"runId": id, "state": state}))).into_response())
}

async fn preview_for_run(st: &AppState, id: Uuid) -> ApiResult<turns::PreviewRow> {
    st.runtime
        .db(move |s| {
            let tx = s.begin()?;
            Ok(turns::get_preview_by_run(&tx, id)?)
        })
        .await?
        .ok_or_else(|| fail(ErrorCode::NotFound, "not found"))
}

async fn manifest(State(st): State<Shared>, Path(id): Path<Uuid>) -> ApiResult<Json<Value>> {
    let p = preview_for_run(&st, id).await?;
    let manifest: Value = serde_json::from_str(&p.manifest).unwrap_or_default();
    Ok(Json(json!({"manifest": manifest, "manifestHash": p.manifest_hash, "payloadHash": p.payload_hash})))
}

#[derive(Deserialize)]
struct ExportQuery {
    format: Option<String>,
}

fn md_escape(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;")
}

async fn export(State(st): State<Shared>, Path(id): Path<Uuid>, Query(q): Query<ExportQuery>) -> ApiResult<Response> {
    if q.format.as_deref().unwrap_or("markdown") != "markdown" {
        return Err(fail(ErrorCode::InvalidInput, "only markdown"));
    }
    let p = preview_for_run(&st, id).await?;
    if st.runtime.run_status(id).await?.map(|(s, _)| s) != Some(RunState::Completed) {
        return Err(fail(ErrorCode::Conflict, "only completed runs can be exported"));
    }
    let msg = st
        .runtime
        .messages(p.session_id)
        .await?
        .into_iter()
        .find(|m| m.run_id == Some(id) && m.role == Role::Assistant)
        .ok_or_else(|| fail(ErrorCode::NotFound, "not found"))?;
    let manifest: Value = serde_json::from_str(&p.manifest).unwrap_or_default();
    let mut md = String::new();
    md.push_str("# DRAFT — NEEDS_HUMAN_REVIEW\n\n");
    md.push_str(&format!(
        "Preset: {} · versión {}\nGenerado: {}\n\n",
        manifest["presetId"].as_str().unwrap_or(""),
        manifest["presetVersion"].as_str().unwrap_or(""),
        manifest["assembledAt"].as_str().unwrap_or("")
    ));
    md.push_str(&md_escape(&msg.text));
    md.push_str("\n\n## Citas\n\n| # | Fuente | Hash del contenido | Coincidencia | Cita |\n|---|---|---|---|---|\n");
    for (i, c) in msg.citations.iter().enumerate() {
        md.push_str(&format!(
            "| {} | {}/{} | {} | {:?} | {} |\n",
            i + 1,
            md_escape(&c.r#ref.dome_id),
            md_escape(&c.r#ref.resource_id),
            c.r#ref.content_hash,
            c.r#match,
            md_escape(&c.quote).replace('|', "\\|")
        ));
    }
    md.push_str(&format!("\nmanifestHash: {}\npayloadHash: {}\n", p.manifest_hash, p.payload_hash));
    if md.len() > 128 * 1024 {
        return Err(fail(ErrorCode::ContextLimit, "export too large"));
    }
    let mut resp = md.into_response();
    let h = resp.headers_mut();
    h.insert(header::CONTENT_TYPE, HeaderValue::from_static("text/markdown; charset=utf-8"));
    h.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    if let Ok(v) = HeaderValue::from_str(&format!("attachment; filename=\"space-run-{id}.md\"")) {
        h.insert(header::CONTENT_DISPOSITION, v);
    }
    Ok(resp)
}

async fn delete_session(State(st): State<Shared>, Path(id): Path<Uuid>) -> ApiResult<Response> {
    session_or_404(&st, id).await?;
    let active = st
        .runtime
        .db(move |s| {
            let tx = s.begin()?;
            Ok(catalog::list_runs(&tx, id, 1)?.into_iter().find(|(_, state, ..)| !state.is_terminal()).map(|r| r.0))
        })
        .await?;
    if let Some(run) = active {
        st.runtime.cancel(run).await?;
        return Err(fail(ErrorCode::Conflict, "cancelling the active run; delete again when it stops"));
    }
    st.runtime
        .db(move |s| {
            let tx = s.begin()?;
            tx.execute("DELETE FROM sessions WHERE id = ?1", [id.to_string()]).map_err(StoreError::from)?;
            commit(tx)
        })
        .await?;
    Ok(StatusCode::NO_CONTENT.into_response())
}

#[cfg(test)]
#[path = "app.test.rs"]
mod tests;
