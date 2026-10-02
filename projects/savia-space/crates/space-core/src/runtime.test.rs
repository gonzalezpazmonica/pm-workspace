use super::*;
use crate::context::{AssetText, PresetText, ProfileSpec, SourceText, assemble};
use crate::provider::MockProvider;
use space_contracts::model::{CanonicalRef, NoteSourceRef, PrepareRequest, PresetId, RefOwner, Span};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

struct Counting {
    inner: MockProvider,
    calls: Arc<AtomicUsize>,
    last_body: Arc<std::sync::Mutex<Vec<u8>>>,
}

impl Provider for Counting {
    fn dispatch(&self, body: Vec<u8>, cancel: watch::Receiver<bool>) -> mpsc::Receiver<ProviderEvent> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        if let Ok(mut b) = self.last_body.lock() {
            *b = body.clone();
        }
        self.inner.dispatch(body, cancel)
    }
}

struct Flag(std::sync::atomic::AtomicBool);
impl Revalidator for Flag {
    fn still_valid<'a>(&'a self, _refs: &'a [NoteSourceRef]) -> BoxFuture<'a, bool> {
        let v = self.0.load(Ordering::SeqCst);
        Box::pin(async move { v })
    }
}

struct Harness {
    _dir: tempfile::TempDir,
    rt: Runtime,
    calls: Arc<AtomicUsize>,
    last_body: Arc<std::sync::Mutex<Vec<u8>>>,
    valid: Arc<Flag>,
    session: Uuid,
}

async fn harness(delay_ms: u64) -> Harness {
    let dir = tempfile::tempdir().expect("tmp");
    let mut store = Store::open(&dir.path().join("space.db")).expect("open");
    let session = store.create_session(Uuid::now_v7(), "S", "2026-10-02T21:00:00.000Z").expect("s").id;
    let calls = Arc::new(AtomicUsize::new(0));
    let last_body = Arc::new(std::sync::Mutex::new(Vec::new()));
    let provider = Counting {
        inner: MockProvider { chunk_delay: Duration::from_millis(delay_ms) },
        calls: calls.clone(),
        last_body: last_body.clone(),
    };
    let valid = Arc::new(Flag(std::sync::atomic::AtomicBool::new(true)));
    let rt = Runtime::new(
        store,
        Arc::new(provider),
        valid.clone(),
        RuntimeOptions {
            principal: "local".into(),
            epoch: 1,
            slots: 2,
            queue_timeout: Duration::from_secs(5),
            cancel_timeout: Duration::from_millis(500),
        },
    );
    Harness { _dir: dir, rt, calls, last_body, valid, session }
}

fn sources() -> Vec<SourceText> {
    ["El cielo es azul y despejado.", "La hierba crece en primavera."]
        .iter()
        .enumerate()
        .map(|(i, t)| SourceText {
            index: i as u8,
            title: format!("Nota {i}"),
            r#ref: NoteSourceRef {
                dome_id: "fixtures".into(),
                resource_id: format!("n1/nota-{i}.md"),
                content_hash: Sha256Hex::of_bytes(t.as_bytes()),
                span: Span { start: 0, end: t.chars().count() as u64 },
            },
            text: (*t).into(),
        })
        .collect()
}

fn request(prompt: &str, key: &str) -> PrepareRequest {
    PrepareRequest {
        preset_id: PresetId::Resume,
        preset_version: Sha256Hex::of_bytes(b"preset"),
        prompt: prompt.into(),
        selection_id: Uuid::from_bytes([1; 16]),
        selection_revision: 1,
        agent_ref: CanonicalRef { owner: RefOwner::Workspace, id: "agents/summary".into(), version: "1".into() },
        skill_refs: vec![],
        history_message_ids: vec![],
        provider_profile_id: "mock".into(),
        expected_session_revision: 1,
        idempotency_key: key.into(),
    }
}

async fn prepare(h: &Harness, prompt: &str, key: &str, now_ms: i64) -> (PrepareRequest, PreviewInfo) {
    let req = request(prompt, key);
    let run_id = Uuid::now_v7();
    let preset =
        PresetText { id: PresetId::Resume, version: req.preset_version.clone(), instructions: "Resume.".into() };
    let agent = AssetText {
        r#ref: req.agent_ref.clone(),
        body: "Agente.".into(),
        body_hash: Sha256Hex::of_bytes(b"Agente."),
        control_hash: Sha256Hex::of_bytes(b"c"),
    };
    let profile = ProfileSpec {
        id: "mock".into(),
        revision: Sha256Hex::of_bytes(b"profile"),
        model: "fixture-v1".into(),
        model_digest: "sha256:fixture".into(),
        adapter_revision: Sha256Hex::of_bytes(b"adapter"),
        context_window: 8192,
        output_reserve: 1024,
        margin_tokens: 256,
    };
    let srcs = sources();
    let prepared = assemble(&crate::context::AssembleInput {
        session_id: h.session,
        run_id,
        manifest_id: Uuid::now_v7(),
        selection_revision: 1,
        preset: &preset,
        agent: &agent,
        skills: &[],
        sources: &srcs,
        history: &[],
        prompt: &req.prompt,
        profile: &profile,
        now_millis: now_ms,
    })
    .expect("assemble");
    let info = h.rt.save_preview(h.session, &req, prepared).await.expect("preview");
    (req, info)
}

fn creation(req: PrepareRequest, info: &PreviewInfo) -> RunCreation {
    RunCreation {
        request: req,
        approved_preview_id: info.preview_id,
        approved_manifest_hash: info.manifest_hash.clone(),
        approved_payload_hash: info.payload_hash.clone(),
    }
}

async fn wait_terminal(rt: &Runtime, run: Uuid) -> (RunState, Option<ErrorCode>) {
    for _ in 0..400 {
        if let Some((s, r)) = rt.run_status(run).await.expect("status")
            && s.is_terminal()
        {
            return (s, r);
        }
        tokio::time::sleep(Duration::from_millis(10)).await;
    }
    panic!("run {run} did not finish");
}

#[tokio::test]
async fn happy_path_completes_with_verified_citations_and_exact_bytes() {
    let h = harness(0).await;
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis()).await;
    let resp = h.rt.admit(h.session, creation(req, &info)).await.expect("admit");
    assert_eq!(resp.state, RunState::Queued);
    assert_eq!(wait_terminal(&h.rt, resp.run_id).await, (RunState::Completed, None));
    assert_eq!(h.calls.load(Ordering::SeqCst), 1);
    let sent = h.last_body.lock().expect("lock").clone();
    assert_eq!(Sha256Hex::of_bytes(&sent), info.payload_hash, "bytes sent = bytes approved");
    let msgs = h.rt.messages(h.session).await.expect("msgs");
    let assistant = msgs.iter().find(|m| m.role == Role::Assistant).expect("assistant");
    assert_eq!(assistant.status, MessageStatus::Final);
    assert!(!assistant.citations.is_empty() && assistant.citations.iter().all(|c| c.verified));
}

#[tokio::test]
async fn idempotent_replay_returns_same_run_and_never_dispatches_twice() {
    let h = harness(0).await;
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis()).await;
    let a = h.rt.admit(h.session, creation(req.clone(), &info)).await.expect("first");
    let b = h.rt.admit(h.session, creation(req, &info)).await.expect("replay with stale revision");
    assert_eq!(a.run_id, b.run_id);
    wait_terminal(&h.rt, a.run_id).await;
    assert_eq!(h.calls.load(Ordering::SeqCst), 1);
}

#[tokio::test]
async fn same_key_different_request_conflicts() {
    let h = harness(0).await;
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis()).await;
    h.rt.admit(h.session, creation(req.clone(), &info)).await.expect("first");
    let mut other = req;
    other.prompt = "Otra cosa".into();
    let err = h.rt.admit(h.session, creation(other, &info)).await.expect_err("conflict");
    assert_eq!(err.code, ErrorCode::Conflict);
}

#[tokio::test]
async fn expired_or_tampered_preview_is_rejected_without_dispatch() {
    let h = harness(0).await;
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis() - 120_000).await;
    let err = h.rt.admit(h.session, creation(req, &info)).await.expect_err("expired");
    assert_eq!(err.code, ErrorCode::ContextChanged);
    let (req, info) = prepare(&h, "Resume", "k2", clock::now_millis()).await;
    let mut c = creation(req, &info);
    c.approved_payload_hash = Sha256Hex::of_bytes(b"something else");
    assert_eq!(h.rt.admit(h.session, c).await.expect_err("tampered").code, ErrorCode::ContextChanged);
    assert_eq!(h.calls.load(Ordering::SeqCst), 0);
}

#[tokio::test]
async fn preview_cannot_be_consumed_twice_by_different_keys() {
    let h = harness(50).await;
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis()).await;
    h.rt.admit(h.session, creation(req.clone(), &info)).await.expect("first");
    let mut again = req;
    again.idempotency_key = "k2".into();
    let err = h.rt.admit(h.session, creation(again, &info)).await.expect_err("consumed");
    assert!(matches!(err.code, ErrorCode::ContextChanged | ErrorCode::StaleRevision | ErrorCode::Conflict));
}

#[tokio::test]
async fn context_change_before_dispatch_fails_without_sending() {
    let h = harness(0).await;
    h.valid.0.store(false, Ordering::SeqCst);
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis()).await;
    let r = h.rt.admit(h.session, creation(req, &info)).await.expect("admit");
    assert_eq!(wait_terminal(&h.rt, r.run_id).await, (RunState::Failed, Some(ErrorCode::ContextChanged)));
    assert_eq!(h.calls.load(Ordering::SeqCst), 0);
}

#[tokio::test]
async fn provider_failure_modes_map_to_terminal_codes() {
    for (tag, code) in [
        ("#fixture:length", ErrorCode::OutputLimit),
        ("#fixture:eof", ErrorCode::ProviderProtocol),
        ("#fixture:tool-call", ErrorCode::UnsupportedCapability),
        ("#fixture:error", ErrorCode::ProviderFailed),
        ("#fixture:quote-mismatch", ErrorCode::ValidationFailed),
    ] {
        let h = harness(0).await;
        let (req, info) = prepare(&h, tag, "k", clock::now_millis()).await;
        let r = h.rt.admit(h.session, creation(req, &info)).await.expect("admit");
        assert_eq!(wait_terminal(&h.rt, r.run_id).await, (RunState::Failed, Some(code)), "{tag}");
    }
}

#[tokio::test]
async fn cancel_wins_and_late_output_never_completes() {
    let h = harness(30).await;
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis()).await;
    let r = h.rt.admit(h.session, creation(req, &info)).await.expect("admit");
    tokio::time::sleep(Duration::from_millis(60)).await;
    h.rt.cancel(r.run_id).await.expect("cancel");
    let (state, _) = wait_terminal(&h.rt, r.run_id).await;
    assert_eq!(state, RunState::Cancelled);
    let msgs = h.rt.messages(h.session).await.expect("msgs");
    assert!(msgs.iter().all(|m| m.status != MessageStatus::Final || m.role == Role::User));
}

#[tokio::test]
async fn events_are_gapless_and_end_with_terminal_state() {
    let h = harness(0).await;
    let mut rx = h.rt.subscribe();
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis()).await;
    let r = h.rt.admit(h.session, creation(req, &info)).await.expect("admit");
    wait_terminal(&h.rt, r.run_id).await;
    let stored = h.rt.events_after(h.session, 0).await.expect("events");
    let seqs: Vec<u64> = stored.iter().map(|e| e.sequence).collect();
    assert_eq!(seqs, (1..=seqs.len() as u64).collect::<Vec<_>>());
    assert!(matches!(stored.last().map(|e| &e.body), Some(EventBody::RunState { state: RunState::Completed, .. })));
    let mut live = Vec::new();
    while let Ok(ev) = rx.try_recv() {
        live.push(ev.sequence);
    }
    assert_eq!(live, seqs, "broadcast mirrors the journal");
}

#[tokio::test]
async fn recovery_interrupts_ambiguous_runs_and_validates_complete_output() {
    let h = harness(0).await;
    let (req, info) = prepare(&h, "Resume", "k1", clock::now_millis()).await;
    let r = h.rt.admit(h.session, creation(req, &info)).await.expect("admit");
    wait_terminal(&h.rt, r.run_id).await;
    // Simulate two crashed runs: one mid-dispatch, one with complete output not yet validated.
    let (dispatched, complete) = (Uuid::now_v7(), Uuid::now_v7());
    let raw = h.rt.raw_output(r.run_id).await.expect("raw").expect("stored");
    h.rt.inject_crashed_run(h.session, dispatched, "DISPATCH_INTENT", None, info.preview_id).await;
    h.rt.inject_crashed_run(h.session, complete, "OUTPUT_COMPLETE", Some(raw), info.preview_id).await;
    let calls_before = h.calls.load(Ordering::SeqCst);
    h.rt.recover().await.expect("recover");
    assert_eq!(
        h.rt.run_status(dispatched).await.expect("s"),
        Some((RunState::Interrupted, Some(ErrorCode::Interrupted)))
    );
    assert_eq!(h.rt.run_status(complete).await.expect("s"), Some((RunState::Completed, None)));
    assert_eq!(h.calls.load(Ordering::SeqCst), calls_before, "recovery never calls the provider");
}
