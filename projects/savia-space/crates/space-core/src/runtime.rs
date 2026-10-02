//! Runtime: atomic admission, run state machine, provider dispatch, recovery.
//!
//! Invariants:
//! - Only the approved body bytes are sent, at most once per run.
//! - Every state change is committed to the journal before it is broadcast.
//! - A crash or reconnection never causes a new dispatch; recovery only validates output that
//!   was already complete.
//! - Once a run is `CANCELLING`, no further text is published and it cannot become `COMPLETED`.

use crate::clock::{self, parse_utc_millis};
use crate::context::{Prepared, SourceText};
use crate::decoder::TextExtractor;
use crate::provider::{Finish, Provider, ProviderEvent};
use crate::validation::{ValidationStatus, validate};
use space_contracts::Sha256Hex;
use space_contracts::model::{
    Citation, ErrorCode, Event, EventBody, Message, MessageStatus, ModelOutput, NoteSourceRef, PrepareRequest, Role,
    RunCreation, RunState,
};
use space_store::turns::{self, MessageRow, PreviewRow};
use space_store::{IdemKey, IdemOutcome, Store, StoreError, Transaction};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::sync::{Semaphore, broadcast, mpsc, watch};
use uuid::Uuid;

/// Checks that the sources behind a run are still readable with the same content.
pub trait Revalidator: Send + Sync {
    fn still_valid<'a>(&'a self, refs: &'a [NoteSourceRef]) -> BoxFuture<'a, bool>;
}

pub type BoxFuture<'a, T> = std::pin::Pin<Box<dyn std::future::Future<Output = T> + Send + 'a>>;

pub struct RuntimeOptions {
    pub principal: String,
    pub epoch: u64,
    pub slots: usize,
    pub queue_timeout: Duration,
    pub cancel_timeout: Duration,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ApiError {
    pub code: ErrorCode,
    pub message: String,
}

impl ApiError {
    pub fn new(code: ErrorCode, message: impl Into<String>) -> Self {
        Self { code, message: message.into() }
    }
}

impl From<StoreError> for ApiError {
    fn from(e: StoreError) -> Self {
        Self::new(ErrorCode::Unavailable, format!("store: {e}"))
    }
}

#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AdmitResponse {
    pub run_id: Uuid,
    pub state: RunState,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PreviewInfo {
    pub preview_id: Uuid,
    pub run_id: Uuid,
    pub request_hash: Sha256Hex,
    pub manifest_hash: Sha256Hex,
    pub payload_hash: Sha256Hex,
    pub manifest: serde_json::Value,
    pub body_text: String,
    pub expires_at: String,
}

struct Inner {
    store: Mutex<Store>,
    events: broadcast::Sender<Event>,
    provider: Arc<dyn Provider>,
    revalidator: Arc<dyn Revalidator>,
    slots: Semaphore,
    cancels: Mutex<HashMap<Uuid, watch::Sender<bool>>>,
    opts: RuntimeOptions,
}

#[derive(Clone)]
pub struct Runtime {
    inner: Arc<Inner>,
}

const DELTA_FLUSH_BYTES: usize = 1024;
const DELTA_FLUSH_MS: u64 = 50;

fn lock_store(inner: &Inner) -> std::sync::MutexGuard<'_, Store> {
    inner.store.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

impl Runtime {
    pub fn new(
        store: Store,
        provider: Arc<dyn Provider>,
        revalidator: Arc<dyn Revalidator>,
        opts: RuntimeOptions,
    ) -> Self {
        let (events, _) = broadcast::channel(1024);
        Self {
            inner: Arc::new(Inner {
                store: Mutex::new(store),
                events,
                provider,
                revalidator,
                slots: Semaphore::new(opts.slots),
                cancels: Mutex::new(HashMap::new()),
                opts,
            }),
        }
    }

    pub fn subscribe(&self) -> broadcast::Receiver<Event> {
        self.inner.events.subscribe()
    }

    /// Runs a closure with the store on a blocking thread (never across an await).
    pub async fn db<T, F>(&self, f: F) -> Result<T, ApiError>
    where
        T: Send + 'static,
        F: FnOnce(&mut Store) -> Result<T, ApiError> + Send + 'static,
    {
        let inner = self.inner.clone();
        tokio::task::spawn_blocking(move || f(&mut lock_store(&inner)))
            .await
            .map_err(|e| ApiError::new(ErrorCode::Unavailable, format!("worker: {e}")))?
    }

    fn publish(&self, events: Vec<Event>) {
        for ev in events {
            let _ = self.inner.events.send(ev);
        }
    }

    /// Persists a prepared preview. Never calls the provider.
    pub async fn save_preview(
        &self,
        session_id: Uuid,
        request: &PrepareRequest,
        prepared: Prepared,
    ) -> Result<PreviewInfo, ApiError> {
        let request_hash = request.request_hash().map_err(|e| ApiError::new(ErrorCode::InvalidInput, e.to_string()))?;
        let manifest = serde_json::to_value(&prepared.manifest)
            .map_err(|e| ApiError::new(ErrorCode::Unavailable, e.to_string()))?;
        let body_text = String::from_utf8(prepared.body.clone())
            .map_err(|_| ApiError::new(ErrorCode::Unavailable, "body is not UTF-8"))?;
        let row = PreviewRow {
            id: Uuid::now_v7(),
            session_id,
            run_id: prepared.manifest.run_id,
            request_hash: request_hash.clone(),
            manifest_hash: prepared.manifest_hash.clone(),
            payload_hash: prepared.manifest.payload_hash.clone(),
            manifest: manifest.to_string(),
            body: prepared.body,
            expires_at: prepared.manifest.expires_at.clone(),
            consumed: false,
        };
        let info = PreviewInfo {
            preview_id: row.id,
            run_id: row.run_id,
            request_hash,
            manifest_hash: row.manifest_hash.clone(),
            payload_hash: row.payload_hash.clone(),
            manifest,
            body_text,
            expires_at: row.expires_at.clone(),
        };
        self.db(move |s| {
            let tx = s.begin()?;
            if turns::count_live_previews(&tx, session_id, &clock::utc_now())? >= 10 {
                return Err(ApiError::new(ErrorCode::RateLimited, "too many live previews in this session"));
            }
            turns::insert_preview(&tx, &row)?;
            tx.commit().map_err(StoreError::from)?;
            Ok(())
        })
        .await?;
        Ok(info)
    }

    /// Atomic admission (idempotency → preview → CAS → run + messages + events).
    pub async fn admit(&self, session_id: Uuid, creation: RunCreation) -> Result<AdmitResponse, ApiError> {
        creation.request.validate().map_err(|e| ApiError::new(ErrorCode::InvalidInput, e.to_string()))?;
        let request_hash =
            creation.request.request_hash().map_err(|e| ApiError::new(ErrorCode::InvalidInput, e.to_string()))?;
        let principal = self.inner.opts.principal.clone();
        let (resp, events, fresh) = self
            .db(move |s| {
                let now = clock::utc_now();
                let tx = s.begin()?;
                let target = session_id.to_string();
                let key = IdemKey {
                    principal: &principal,
                    operation: "run.create",
                    target: Some(&target),
                    key: &creation.request.idempotency_key,
                };
                let idem_hash = Sha256Hex::of_bytes(
                    format!(
                        "{}|{}|{}|{}",
                        request_hash,
                        creation.approved_preview_id,
                        creation.approved_manifest_hash,
                        creation.approved_payload_hash
                    )
                    .as_bytes(),
                );
                match space_store::idem_lookup(&tx, &key, &idem_hash)? {
                    IdemOutcome::Replay(stored) => {
                        let resp: AdmitResponse = serde_json::from_str(&stored)
                            .map_err(|e| ApiError::new(ErrorCode::Unavailable, e.to_string()))?;
                        return Ok((resp, vec![], false));
                    }
                    IdemOutcome::Conflict => {
                        return Err(ApiError::new(
                            ErrorCode::Conflict,
                            "idempotency key reused with a different request",
                        ));
                    }
                    IdemOutcome::New => {}
                }
                let preview = turns::get_preview(&tx, creation.approved_preview_id)?
                    .filter(|p| p.session_id == session_id)
                    .ok_or_else(|| ApiError::new(ErrorCode::NotFound, "preview not found"))?;
                let expired = parse_utc_millis(&preview.expires_at)
                    .is_none_or(|exp| exp <= parse_utc_millis(&now).unwrap_or(i64::MAX));
                if preview.consumed
                    || expired
                    || preview.request_hash != request_hash
                    || preview.manifest_hash != creation.approved_manifest_hash
                    || preview.payload_hash != creation.approved_payload_hash
                {
                    return Err(ApiError::new(ErrorCode::ContextChanged, "the approved preview is no longer valid"));
                }
                if space_store::bump_session(&tx, session_id, creation.request.expected_session_revision, &now, true)?
                    .is_none()
                {
                    return Err(ApiError::new(ErrorCode::StaleRevision, "session revision changed"));
                }
                let run_id = preview.run_id;
                if let Err(e) = space_store::insert_run(&tx, run_id, session_id, RunState::Queued, &now) {
                    return Err(match e {
                        StoreError::Db(rusqlite_err) if rusqlite_err.to_string().contains("UNIQUE") => {
                            ApiError::new(ErrorCode::Conflict, "the session already has an active run")
                        }
                        other => other.into(),
                    });
                }
                if !turns::consume_preview(&tx, preview.id)? {
                    return Err(ApiError::new(ErrorCode::ContextChanged, "preview already consumed"));
                }
                let manifest: serde_json::Value = serde_json::from_str(&preview.manifest).unwrap_or_default();
                let manifest_id = manifest["id"].as_str().and_then(|s| Uuid::parse_str(s).ok());
                let mut events = Vec::new();
                for (role, text, status) in [
                    (Role::User, creation.request.prompt.as_str(), MessageStatus::Final),
                    (Role::Assistant, "", MessageStatus::Partial),
                ] {
                    let id = Uuid::now_v7();
                    let seq = s_next_sequence(&tx, session_id)?;
                    turns::insert_message(&tx, id, session_id, Some(run_id), role, status, seq, text, manifest_id)?;
                    let message = Message {
                        id,
                        session_id,
                        run_id: Some(run_id),
                        role,
                        status,
                        created_sequence: seq,
                        text: text.to_owned(),
                        citations: vec![],
                        manifest_id,
                        validation: None,
                    };
                    events.push(space_store::append_event(
                        &tx,
                        session_id,
                        Some(run_id),
                        &EventBody::MessageCreated { message },
                        &now,
                    )?);
                }
                events.push(space_store::append_event(
                    &tx,
                    session_id,
                    Some(run_id),
                    &EventBody::RunCreated { run_id, state: RunState::Queued },
                    &now,
                )?);
                let resp = AdmitResponse { run_id, state: RunState::Queued };
                let stored =
                    serde_json::to_string(&resp).map_err(|e| ApiError::new(ErrorCode::Unavailable, e.to_string()))?;
                space_store::idem_record(&tx, &key, &idem_hash, &stored, &now)?;
                tx.commit().map_err(StoreError::from)?;
                Ok((resp, events, true))
            })
            .await?;
        self.publish(events);
        if fresh {
            let (cancel_tx, cancel_rx) = watch::channel(false);
            if let Ok(mut map) = self.inner.cancels.lock() {
                map.insert(resp.run_id, cancel_tx);
            }
            let rt = self.clone();
            tokio::spawn(async move { rt.drive(session_id, resp.run_id, cancel_rx).await });
        }
        Ok(resp)
    }

    /// Requests cancellation. Returns the state after the request.
    pub async fn cancel(&self, run_id: Uuid) -> Result<RunState, ApiError> {
        let (state, events) = self
            .db(move |s| {
                let tx = s.begin()?;
                let (state, _) = space_store::run_state(&tx, run_id)?
                    .ok_or_else(|| ApiError::new(ErrorCode::NotFound, "run not found"))?;
                if state.is_terminal() || state == RunState::Cancelling {
                    return Ok((state, vec![]));
                }
                let session = session_of_run(&tx, run_id)?;
                let now = clock::utc_now();
                let rev = space_store::set_run_state(&tx, run_id, RunState::Cancelling, None, &now)?;
                let ev = space_store::append_event(
                    &tx,
                    session,
                    Some(run_id),
                    &EventBody::RunState { state: RunState::Cancelling, revision: rev, reason: None },
                    &now,
                )?;
                tx.commit().map_err(StoreError::from)?;
                Ok((RunState::Cancelling, vec![ev]))
            })
            .await?;
        self.publish(events);
        if let Ok(map) = self.inner.cancels.lock()
            && let Some(tx) = map.get(&run_id)
        {
            let _ = tx.send(true);
        }
        Ok(state)
    }

    pub async fn run_status(&self, run_id: Uuid) -> Result<Option<(RunState, Option<ErrorCode>)>, ApiError> {
        self.db(move |s| {
            let tx = s.begin()?;
            let state = space_store::run_state(&tx, run_id)?;
            let reason: Option<String> = tx
                .query_row("SELECT terminal_reason FROM runs WHERE id = ?1", [run_id.to_string()], |r| r.get(0))
                .ok()
                .flatten();
            let reason = reason.and_then(|r| serde_json::from_value(serde_json::Value::String(r)).ok());
            Ok(state.map(|(s, _)| (s, reason)))
        })
        .await
    }

    pub async fn events_after(&self, session_id: Uuid, after: u64) -> Result<Vec<Event>, ApiError> {
        self.db(move |s| Ok(s.events_after(session_id, after)?)).await
    }

    pub async fn messages(&self, session_id: Uuid) -> Result<Vec<Message>, ApiError> {
        self.db(move |s| {
            let tx = s.begin()?;
            let rows = turns::list_messages(&tx, session_id, u64::MAX, 50)?;
            Ok(rows.into_iter().map(|r| to_message(session_id, r)).collect())
        })
        .await
    }

    pub async fn raw_output(&self, run_id: Uuid) -> Result<Option<Vec<u8>>, ApiError> {
        self.db(move |s| {
            let tx = s.begin()?;
            Ok(turns::load_output(&tx, run_id)?)
        })
        .await
    }

    /// Startup recovery: no run is ever re-dispatched.
    pub async fn recover(&self) -> Result<(), ApiError> {
        let events = self
            .db(move |s| {
                let tx = s.begin()?;
                let now = clock::utc_now();
                let mut events = Vec::new();
                for (run_id, session_id) in turns::non_terminal_runs(&tx)? {
                    let attempt = turns::attempt_state(&tx, run_id)?;
                    let raw = turns::load_output(&tx, run_id)?;
                    let preview = turns::get_preview_by_run(&tx, run_id)?;
                    let outcome = match (attempt.as_deref(), raw, preview) {
                        (Some("OUTPUT_COMPLETE"), Some(raw), Some(p)) => Some(finish_validation(&raw, &p)),
                        _ => None,
                    };
                    let report = outcome.as_ref().and_then(|o| o.as_ref().ok()).map(|c| c.3.to_string());
                    let (state, reason, message_status, text, citations) = match outcome {
                        Some(Ok((true, text, cites, _))) => {
                            (RunState::Completed, None, MessageStatus::Final, Some(text), cites)
                        }
                        Some(Ok((false, text, cites, _))) => (
                            RunState::Failed,
                            Some(ErrorCode::ValidationFailed),
                            MessageStatus::Failed,
                            Some(text),
                            cites,
                        ),
                        _ => (
                            RunState::Interrupted,
                            Some(ErrorCode::Interrupted),
                            MessageStatus::Interrupted,
                            None,
                            vec![],
                        ),
                    };
                    if let Some(msg) = assistant_message(&tx, session_id, run_id)? {
                        let text = text.unwrap_or(msg.text.clone());
                        let cites = serde_json::to_string(&citations).unwrap_or_else(|_| "[]".into());
                        turns::finalize_message(&tx, msg.id, message_status, &text, &cites)?;
                        if let Some(r) = &report {
                            turns::set_message_validation(&tx, msg.id, r)?;
                        }
                        if state == RunState::Completed
                            && let Some(updated) = turns::get_message(&tx, msg.id)?
                        {
                            events.push(space_store::append_event(
                                &tx,
                                session_id,
                                Some(run_id),
                                &EventBody::MessageFinal { message: to_message(session_id, updated) },
                                &now,
                            )?);
                        }
                    }
                    if attempt.is_some() {
                        let final_attempt = if state == RunState::Interrupted { "UNKNOWN" } else { "FINISHED" };
                        turns::set_attempt_state(&tx, run_id, final_attempt, Some(&now))?;
                    }
                    let rev = space_store::set_run_state(&tx, run_id, state, reason, &now)?;
                    events.push(space_store::append_event(
                        &tx,
                        session_id,
                        Some(run_id),
                        &EventBody::RunState { state, revision: rev, reason },
                        &now,
                    )?);
                }
                tx.commit().map_err(StoreError::from)?;
                Ok(events)
            })
            .await?;
        self.publish(events);
        Ok(())
    }

    async fn transition(
        &self,
        session_id: Uuid,
        run_id: Uuid,
        expect: &'static [RunState],
        to: RunState,
        reason: Option<ErrorCode>,
    ) -> Result<bool, ApiError> {
        let events = self
            .db(move |s| {
                let tx = s.begin()?;
                let Some((state, _)) = space_store::run_state(&tx, run_id)? else { return Ok(None) };
                if !expect.contains(&state) {
                    return Ok(None);
                }
                let now = clock::utc_now();
                let rev = space_store::set_run_state(&tx, run_id, to, reason, &now)?;
                let ev = space_store::append_event(
                    &tx,
                    session_id,
                    Some(run_id),
                    &EventBody::RunState { state: to, revision: rev, reason },
                    &now,
                )?;
                tx.commit().map_err(StoreError::from)?;
                Ok(Some(vec![ev]))
            })
            .await?;
        Ok(match events {
            Some(ev) => {
                self.publish(ev);
                true
            }
            None => false,
        })
    }

    /// Terminal write for the run plus the assistant message, in one transaction.
    #[allow(clippy::too_many_arguments)]
    async fn finish(
        &self,
        session_id: Uuid,
        run_id: Uuid,
        state: RunState,
        reason: Option<ErrorCode>,
        message_status: MessageStatus,
        final_text: Option<String>,
        citations: Vec<Citation>,
    ) -> Result<(), ApiError> {
        let events = self
            .db(move |s| {
                let tx = s.begin()?;
                let now = clock::utc_now();
                let Some((current, _)) = space_store::run_state(&tx, run_id)? else { return Ok(vec![]) };
                if current.is_terminal() {
                    return Ok(vec![]);
                }
                // A cancelled run can only end as CANCELLED or INTERRUPTED.
                let (state, reason, message_status) = if current == RunState::Cancelling
                    && !matches!(state, RunState::Cancelled | RunState::Interrupted)
                {
                    (RunState::Cancelled, None, MessageStatus::Interrupted)
                } else {
                    (state, reason, message_status)
                };
                let mut events = Vec::new();
                if let Some(msg) = assistant_message(&tx, session_id, run_id)? {
                    let text = match (&final_text, state) {
                        (Some(t), RunState::Completed | RunState::Failed) => t.clone(),
                        _ => msg.text.clone(),
                    };
                    let cites = serde_json::to_string(&citations).unwrap_or_else(|_| "[]".into());
                    turns::finalize_message(&tx, msg.id, message_status, &text, &cites)?;
                    if let Some(updated) = turns::get_message(&tx, msg.id)? {
                        events.push(space_store::append_event(
                            &tx,
                            session_id,
                            Some(run_id),
                            &EventBody::MessageFinal { message: to_message(session_id, updated) },
                            &now,
                        )?);
                    }
                }
                if turns::attempt_state(&tx, run_id)?.is_some() {
                    let a = if state == RunState::Interrupted { "UNKNOWN" } else { "FINISHED" };
                    turns::set_attempt_state(&tx, run_id, a, Some(&now))?;
                }
                let rev = space_store::set_run_state(&tx, run_id, state, reason, &now)?;
                events.push(space_store::append_event(
                    &tx,
                    session_id,
                    Some(run_id),
                    &EventBody::RunState { state, revision: rev, reason },
                    &now,
                )?);
                tx.commit().map_err(StoreError::from)?;
                Ok(events)
            })
            .await?;
        self.publish(events);
        Ok(())
    }

    async fn drive(&self, session_id: Uuid, run_id: Uuid, mut cancel: watch::Receiver<bool>) {
        let result = self.drive_inner(session_id, run_id, &mut cancel).await;
        if result.is_err() {
            let _ = self
                .finish(
                    session_id,
                    run_id,
                    RunState::Interrupted,
                    Some(ErrorCode::Interrupted),
                    MessageStatus::Interrupted,
                    None,
                    vec![],
                )
                .await;
        }
        if let Ok(mut map) = self.inner.cancels.lock() {
            map.remove(&run_id);
        }
    }

    async fn drive_inner(
        &self,
        session_id: Uuid,
        run_id: Uuid,
        cancel: &mut watch::Receiver<bool>,
    ) -> Result<(), ApiError> {
        let cancelled = |c: &watch::Receiver<bool>| *c.borrow();
        // 1. Wait for a provider slot (or cancel, or queue timeout).
        let permit = tokio::select! {
            p = tokio::time::timeout(self.inner.opts.queue_timeout, self.inner.slots.acquire()) => match p {
                Ok(Ok(p)) => p,
                _ => {
                    return self.finish(session_id, run_id, RunState::Failed, Some(ErrorCode::Unavailable),
                        MessageStatus::Failed, None, vec![]).await;
                }
            },
            _ = cancel_requested(cancel) => {
                return self.finish(session_id, run_id, RunState::Cancelled, None, MessageStatus::Interrupted, None, vec![]).await;
            }
        };
        // 2. RESOLVING + revalidation.
        if !self.transition(session_id, run_id, &[RunState::Queued], RunState::Resolving, None).await? {
            return self
                .finish(session_id, run_id, RunState::Cancelled, None, MessageStatus::Interrupted, None, vec![])
                .await;
        }
        let preview = self
            .db(move |s| {
                let tx = s.begin()?;
                Ok(turns::get_preview_by_run(&tx, run_id)?)
            })
            .await?
            .ok_or_else(|| ApiError::new(ErrorCode::Unavailable, "preview missing"))?;
        let sources = sources_from_preview(&preview);
        let refs: Vec<NoteSourceRef> = sources.iter().map(|s| s.r#ref.clone()).collect();
        let intact = Sha256Hex::of_bytes(&preview.body) == preview.payload_hash;
        if !intact || !self.inner.revalidator.still_valid(&refs).await {
            return self
                .finish(
                    session_id,
                    run_id,
                    RunState::Failed,
                    Some(ErrorCode::ContextChanged),
                    MessageStatus::Failed,
                    None,
                    vec![],
                )
                .await;
        }
        if cancelled(cancel) {
            return self
                .finish(session_id, run_id, RunState::Cancelled, None, MessageStatus::Interrupted, None, vec![])
                .await;
        }
        // 3. DISPATCH_INTENT is durable before the request leaves.
        let epoch = self.inner.opts.epoch;
        let manifest: serde_json::Value = serde_json::from_str(&preview.manifest).unwrap_or_default();
        let manifest_id = manifest["id"].as_str().and_then(|s| Uuid::parse_str(s).ok()).unwrap_or_default();
        let (manifest_hash, payload_hash) = (preview.manifest_hash.clone(), preview.payload_hash.clone());
        let dispatched = self
            .db(move |s| {
                let tx = s.begin()?;
                let Some((RunState::Resolving, _)) = space_store::run_state(&tx, run_id)? else { return Ok(None) };
                let now = clock::utc_now();
                let attempt_id = Uuid::now_v7();
                turns::insert_attempt(&tx, attempt_id, run_id, "DISPATCH_INTENT", epoch, &now)?;
                let mut evs = vec![space_store::append_event(
                    &tx,
                    session_id,
                    Some(run_id),
                    &EventBody::ContextDispatched { manifest_id, manifest_hash, payload_hash, attempt_id },
                    &now,
                )?];
                let rev = space_store::set_run_state(&tx, run_id, RunState::Running, None, &now)?;
                evs.push(space_store::append_event(
                    &tx,
                    session_id,
                    Some(run_id),
                    &EventBody::RunState { state: RunState::Running, revision: rev, reason: None },
                    &now,
                )?);
                tx.commit().map_err(StoreError::from)?;
                Ok(Some(evs))
            })
            .await?;
        let Some(evs) = dispatched else {
            return self
                .finish(session_id, run_id, RunState::Cancelled, None, MessageStatus::Interrupted, None, vec![])
                .await;
        };
        self.publish(evs);
        // 4. Stream.
        let rx = self.inner.provider.dispatch(preview.body.clone(), cancel.clone());
        let outcome = self.stream(session_id, run_id, rx, cancel).await?;
        drop(permit);
        match outcome {
            StreamEnd::Complete(raw) => self.validate_and_finish(session_id, run_id, raw, &preview).await,
            StreamEnd::Fail(code) => {
                self.finish(session_id, run_id, RunState::Failed, Some(code), MessageStatus::Failed, None, vec![]).await
            }
            StreamEnd::Cancelled => {
                self.finish(session_id, run_id, RunState::Cancelled, None, MessageStatus::Interrupted, None, vec![])
                    .await
            }
            StreamEnd::CancelUnconfirmed => {
                self.finish(
                    session_id,
                    run_id,
                    RunState::Interrupted,
                    Some(ErrorCode::CancelUnconfirmed),
                    MessageStatus::Interrupted,
                    None,
                    vec![],
                )
                .await
            }
        }
    }

    async fn stream(
        &self,
        session_id: Uuid,
        run_id: Uuid,
        mut rx: mpsc::Receiver<ProviderEvent>,
        cancel: &mut watch::Receiver<bool>,
    ) -> Result<StreamEnd, ApiError> {
        let mut decoder = TextExtractor::default();
        let mut pending = String::new();
        let mut offset: u64 = 0;
        let mut last_flush = tokio::time::Instant::now();
        let mut cancel_deadline: Option<tokio::time::Instant> = None;
        loop {
            let deadline = cancel_deadline.unwrap_or_else(|| tokio::time::Instant::now() + Duration::from_secs(3600));
            let ev = tokio::select! {
                ev = rx.recv() => ev,
                _ = cancel_requested(cancel), if cancel_deadline.is_none() => {
                    cancel_deadline = Some(tokio::time::Instant::now() + self.inner.opts.cancel_timeout);
                    continue;
                }
                _ = tokio::time::sleep_until(deadline), if cancel_deadline.is_some() => {
                    return Ok(StreamEnd::CancelUnconfirmed);
                }
            };
            if cancel_deadline.is_some() {
                // Fence: after a cancel request nothing else is published.
                match ev {
                    Some(ProviderEvent::Cancelled) | None => return Ok(StreamEnd::Cancelled),
                    _ => continue,
                }
            }
            match ev {
                Some(ProviderEvent::Chunk(chunk)) => match decoder.push(&chunk) {
                    Ok(text) => {
                        pending.push_str(&text);
                        if pending.len() >= DELTA_FLUSH_BYTES
                            || last_flush.elapsed() >= Duration::from_millis(DELTA_FLUSH_MS)
                        {
                            offset = self.flush_delta(session_id, run_id, &mut pending, offset).await?;
                            last_flush = tokio::time::Instant::now();
                        }
                    }
                    Err(_) => return Ok(StreamEnd::Fail(ErrorCode::ProviderProtocol)),
                },
                Some(ProviderEvent::Done(Finish::Stop)) => {
                    self.flush_delta(session_id, run_id, &mut pending, offset).await?;
                    return Ok(StreamEnd::Complete(decoder.raw().as_bytes().to_vec()));
                }
                Some(ProviderEvent::Done(Finish::Length)) => {
                    self.flush_delta(session_id, run_id, &mut pending, offset).await?;
                    return Ok(StreamEnd::Fail(ErrorCode::OutputLimit));
                }
                Some(ProviderEvent::Done(Finish::ToolCalls)) => {
                    return Ok(StreamEnd::Fail(ErrorCode::UnsupportedCapability));
                }
                Some(ProviderEvent::Failed) => return Ok(StreamEnd::Fail(ErrorCode::ProviderFailed)),
                Some(ProviderEvent::Cancelled) => return Ok(StreamEnd::Cancelled),
                None => {
                    self.flush_delta(session_id, run_id, &mut pending, offset).await?;
                    return Ok(StreamEnd::Fail(ErrorCode::ProviderProtocol));
                }
            }
        }
    }

    /// Persists and publishes buffered public text unless the run is being cancelled.
    async fn flush_delta(
        &self,
        session_id: Uuid,
        run_id: Uuid,
        pending: &mut String,
        offset: u64,
    ) -> Result<u64, ApiError> {
        if pending.is_empty() {
            return Ok(offset);
        }
        let text = std::mem::take(pending);
        let len = text.chars().count() as u64;
        let events = self
            .db(move |s| {
                let tx = s.begin()?;
                let Some((RunState::Running, _)) = space_store::run_state(&tx, run_id)? else { return Ok(vec![]) };
                let Some(msg) = assistant_message(&tx, session_id, run_id)? else { return Ok(vec![]) };
                turns::append_message_text(&tx, msg.id, &text)?;
                let ev = space_store::append_event(
                    &tx,
                    session_id,
                    Some(run_id),
                    &EventBody::MessageDelta { message_id: msg.id, offset, text },
                    &clock::utc_now(),
                )?;
                tx.commit().map_err(StoreError::from)?;
                Ok(vec![ev])
            })
            .await?;
        self.publish(events);
        Ok(offset + len)
    }

    async fn validate_and_finish(
        &self,
        session_id: Uuid,
        run_id: Uuid,
        raw: Vec<u8>,
        preview: &PreviewRow,
    ) -> Result<(), ApiError> {
        let raw_store = raw.clone();
        let entered = self
            .db(move |s| {
                let tx = s.begin()?;
                let Some((RunState::Running, _)) = space_store::run_state(&tx, run_id)? else { return Ok(None) };
                let now = clock::utc_now();
                turns::store_output(&tx, run_id, &raw_store)?;
                turns::set_attempt_state(&tx, run_id, "OUTPUT_COMPLETE", None)?;
                let rev = space_store::set_run_state(&tx, run_id, RunState::Validating, None, &now)?;
                let ev = space_store::append_event(
                    &tx,
                    session_id,
                    Some(run_id),
                    &EventBody::RunState { state: RunState::Validating, revision: rev, reason: None },
                    &now,
                )?;
                tx.commit().map_err(StoreError::from)?;
                Ok(Some(vec![ev]))
            })
            .await?;
        let Some(evs) = entered else {
            return self
                .finish(session_id, run_id, RunState::Cancelled, None, MessageStatus::Interrupted, None, vec![])
                .await;
        };
        self.publish(evs);
        let checked = finish_validation(&raw, preview);
        if let Ok((_, _, _, report)) = &checked {
            let report = report.to_string();
            self.db(move |s| {
                let tx = s.begin()?;
                if let Some(msg) = assistant_message(&tx, session_id, run_id)? {
                    turns::set_message_validation(&tx, msg.id, &report)?;
                }
                tx.commit().map_err(StoreError::from)?;
                Ok(())
            })
            .await?;
        }
        match checked {
            Ok((true, text, cites, _)) => {
                self.finish(session_id, run_id, RunState::Completed, None, MessageStatus::Final, Some(text), cites)
                    .await
            }
            Ok((false, text, cites, _)) => {
                self.finish(
                    session_id,
                    run_id,
                    RunState::Failed,
                    Some(ErrorCode::ValidationFailed),
                    MessageStatus::Failed,
                    Some(text),
                    cites,
                )
                .await
            }
            Err(()) => {
                self.finish(
                    session_id,
                    run_id,
                    RunState::Failed,
                    Some(ErrorCode::ProviderProtocol),
                    MessageStatus::Failed,
                    None,
                    vec![],
                )
                .await
            }
        }
    }

    #[cfg(test)]
    pub(crate) async fn inject_crashed_run(
        &self,
        _session_id: Uuid,
        run_id: Uuid,
        attempt: &'static str,
        raw: Option<Vec<u8>>,
        preview_id: Uuid,
    ) {
        self.db(move |s| {
            let session = s.create_session(Uuid::now_v7(), "crash", &clock::utc_now())?.id;
            let tx = s.begin()?;
            let now = clock::utc_now();
            let mut p = turns::get_preview(&tx, preview_id)?.ok_or_else(|| ApiError::new(ErrorCode::NotFound, "p"))?;
            p.id = Uuid::now_v7();
            p.run_id = run_id;
            p.session_id = session;
            turns::insert_preview(&tx, &p)?;
            space_store::insert_run(&tx, run_id, session, RunState::Running, &now)?;
            turns::insert_message(
                &tx,
                Uuid::now_v7(),
                session,
                Some(run_id),
                Role::Assistant,
                MessageStatus::Partial,
                1,
                "",
                None,
            )?;
            turns::insert_attempt(&tx, Uuid::now_v7(), run_id, attempt, 1, &now)?;
            if let Some(raw) = raw {
                turns::store_output(&tx, run_id, &raw)?;
            }
            tx.commit().map_err(StoreError::from)?;
            Ok(())
        })
        .await
        .expect("inject");
    }
}

/// Resolves once cancellation is requested; never holds the watch guard across an await.
async fn cancel_requested(c: &mut watch::Receiver<bool>) {
    let _ = c.wait_for(|v| *v).await.map(|_| ());
}

enum StreamEnd {
    Complete(Vec<u8>),
    Fail(ErrorCode),
    Cancelled,
    CancelUnconfirmed,
}

fn s_next_sequence(tx: &Transaction<'_>, session_id: Uuid) -> Result<u64, StoreError> {
    let n: i64 = tx.query_row(
        "SELECT COALESCE(MAX(sequence), 0) + 1 FROM events WHERE session_id = ?1",
        [session_id.to_string()],
        |r| r.get(0),
    )?;
    Ok(n as u64)
}

fn session_of_run(tx: &Transaction<'_>, run_id: Uuid) -> Result<Uuid, ApiError> {
    let s: String = tx
        .query_row("SELECT session_id FROM runs WHERE id = ?1", [run_id.to_string()], |r| r.get(0))
        .map_err(|_| ApiError::new(ErrorCode::NotFound, "run not found"))?;
    Uuid::parse_str(&s).map_err(|e| ApiError::new(ErrorCode::Unavailable, e.to_string()))
}

fn assistant_message(tx: &Transaction<'_>, session_id: Uuid, run_id: Uuid) -> Result<Option<MessageRow>, StoreError> {
    let rows = turns::list_messages(tx, session_id, u64::MAX, 10_000)?;
    Ok(rows.into_iter().find(|m| m.run_id == Some(run_id) && m.role == Role::Assistant))
}

fn to_message(session_id: Uuid, r: MessageRow) -> Message {
    Message {
        id: r.id,
        session_id,
        run_id: r.run_id,
        role: r.role,
        status: r.status,
        created_sequence: r.created_sequence,
        text: r.text,
        citations: serde_json::from_str(&r.citations).unwrap_or_default(),
        manifest_id: r.manifest_id,
        validation: r.validation.and_then(|v| serde_json::from_str(&v).ok()),
    }
}

/// Rebuilds the selected sources from the stored body and manifest (no external reads).
fn sources_from_preview(p: &PreviewRow) -> Vec<SourceText> {
    let body: serde_json::Value = serde_json::from_slice(&p.body).unwrap_or_default();
    let manifest: serde_json::Value = serde_json::from_str(&p.manifest).unwrap_or_default();
    let user = body["messages"][1]["content"].as_str().unwrap_or("");
    let doc: serde_json::Value = user.find('{').and_then(|i| serde_json::from_str(&user[i..]).ok()).unwrap_or_default();
    let refs: Vec<NoteSourceRef> = manifest["entries"]
        .as_array()
        .map(|a| a.iter().filter_map(|e| serde_json::from_value(e["ref"].clone()).ok()).collect())
        .unwrap_or_default();
    doc["sources"]
        .as_array()
        .map(|a| {
            a.iter()
                .zip(refs)
                .map(|(s, r)| SourceText {
                    index: s["index"].as_u64().unwrap_or(0) as u8,
                    title: s["title"].as_str().unwrap_or("").to_owned(),
                    r#ref: r,
                    text: s["text"].as_str().unwrap_or("").to_owned(),
                })
                .collect()
        })
        .unwrap_or_default()
}

/// Strict parse + deterministic validation: `(passed, text, citations, report)`; `Err` if malformed.
type Checked = (bool, String, Vec<Citation>, serde_json::Value);

fn finish_validation(raw: &[u8], preview: &PreviewRow) -> Result<Checked, ()> {
    let value = space_contracts::json::parse_strict(raw).map_err(|_| ())?;
    let output: ModelOutput = serde_json::from_value(value).map_err(|_| ())?;
    let sources = sources_from_preview(preview);
    let v = validate(&output, &sources);
    let report = serde_json::json!({"status": v.status, "issues": v.issues, "claims": v.claims});
    Ok((v.status == ValidationStatus::Pass, v.text, v.citations, report))
}

#[cfg(test)]
#[path = "runtime.test.rs"]
mod tests;
