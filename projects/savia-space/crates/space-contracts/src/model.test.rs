use super::*;
use serde_json::json;

fn uuid(n: u8) -> Uuid {
    Uuid::from_bytes([n; 16])
}

fn prepare() -> PrepareRequest {
    PrepareRequest {
        preset_id: PresetId::Resume,
        preset_version: Sha256Hex::of_bytes(b"preset"),
        prompt: "Resume las fuentes".into(),
        selection_id: uuid(1),
        selection_revision: 1,
        agent_ref: CanonicalRef { owner: RefOwner::Workspace, id: "agents/summary".into(), version: "1".into() },
        skill_refs: vec![],
        history_message_ids: vec![],
        provider_profile_id: "mock".into(),
        expected_session_revision: 3,
        idempotency_key: "turn-1".into(),
    }
}

#[test]
fn error_codes_map_to_http_status() {
    assert_eq!(ErrorCode::InvalidInput.http_status(), Some(400));
    assert_eq!(ErrorCode::OriginDenied.http_status(), Some(403));
    assert_eq!(ErrorCode::NotFound.http_status(), Some(404));
    assert_eq!(ErrorCode::ContextChanged.http_status(), Some(409));
    assert_eq!(ErrorCode::Gone.http_status(), Some(410));
    assert_eq!(ErrorCode::RateLimited.http_status(), Some(429));
    assert_eq!(ErrorCode::Unavailable.http_status(), Some(503));
    assert_eq!(ErrorCode::ProviderProtocol.http_status(), None, "only reported as a run event");
}

#[test]
fn error_code_serializes_screaming_snake() {
    assert_eq!(serde_json::to_value(ErrorCode::CancelUnconfirmed).expect("ser"), json!("CANCEL_UNCONFIRMED"));
}

#[test]
fn run_state_terminality() {
    for s in [RunState::Completed, RunState::Failed, RunState::Cancelled, RunState::Interrupted] {
        assert!(s.is_terminal(), "{s:?}");
    }
    for s in [RunState::Queued, RunState::Resolving, RunState::Running, RunState::Validating, RunState::Cancelling] {
        assert!(!s.is_terminal(), "{s:?}");
    }
}

#[test]
fn request_hash_ignores_idempotency_key_only() {
    let a = prepare();
    let mut b = prepare();
    b.idempotency_key = "other".into();
    assert_eq!(a.request_hash().expect("hash"), b.request_hash().expect("hash"));
    b.prompt.push('!');
    assert_ne!(a.request_hash().expect("hash"), b.request_hash().expect("hash"));
}

#[test]
fn run_creation_projects_back_to_prepare_request() {
    let creation = RunCreation {
        request: prepare(),
        approved_preview_id: uuid(2),
        approved_manifest_hash: Sha256Hex::of_bytes(b"m"),
        approved_payload_hash: Sha256Hex::of_bytes(b"p"),
    };
    let wire = serde_json::to_value(&creation).expect("ser");
    assert_eq!(wire["approvedPreviewId"], json!(uuid(2)));
    assert_eq!(wire["presetId"], json!("resume"), "flattened request fields");
    let back: RunCreation = serde_json::from_value(wire).expect("de");
    assert_eq!(back.request.request_hash().expect("h"), prepare().request_hash().expect("h"));
}

#[test]
fn unknown_fields_are_rejected() {
    let mut wire = serde_json::to_value(prepare()).expect("ser");
    wire["principalId"] = json!("spoofed");
    assert!(serde_json::from_value::<PrepareRequest>(wire).is_err());
}

#[test]
fn prepare_request_limits() {
    let mut p = prepare();
    assert!(p.validate().is_ok());
    p.prompt = "x".repeat(16 * 1024 + 1);
    assert!(p.validate().is_err());
    let mut p = prepare();
    p.skill_refs = vec![p.agent_ref.clone(); 5];
    assert!(p.validate().is_err());
    let mut p = prepare();
    p.history_message_ids = vec![uuid(9); 17];
    assert!(p.validate().is_err());
    let mut p = prepare();
    p.idempotency_key = "ñ".into();
    assert!(p.validate().is_err(), "keys are printable ASCII");
}

#[test]
fn events_are_tagged_by_type() {
    let ev = Event {
        protocol_version: 1,
        event_id: uuid(3),
        sequence: 7,
        session_id: uuid(4),
        run_id: Some(uuid(5)),
        occurred_at: "2026-10-02T20:00:00.000Z".into(),
        body: EventBody::RunState { state: RunState::Failed, revision: 2, reason: Some(ErrorCode::ContextChanged) },
    };
    let wire = serde_json::to_value(&ev).expect("ser");
    assert_eq!(wire["type"], "run.state");
    assert_eq!(wire["payload"]["reason"], "CONTEXT_CHANGED");
    let back: Event = serde_json::from_value(wire).expect("de");
    assert_eq!(back, ev);
}

#[test]
fn message_delta_event_round_trip() {
    let body = EventBody::MessageDelta { message_id: uuid(6), offset: 12, text: "hola".into() };
    let wire = serde_json::to_value(&body).expect("ser");
    assert_eq!(wire, json!({"type": "message.delta", "payload": {"messageId": uuid(6), "offset": 12, "text": "hola"}}));
}

#[test]
fn model_output_rejects_model_supplied_trust_fields() {
    let bad = json!({"text": "t", "citations": [{"sourceIndex": 0, "quote": "q", "verified": true}], "claims": []});
    assert!(serde_json::from_value::<ModelOutput>(bad).is_err());
}

#[test]
fn model_output_limits() {
    let ok = ModelOutput { text: "t".into(), citations: vec![], claims: vec![] };
    assert!(ok.validate().is_ok());
    let mut too_many = ok.clone();
    too_many.citations = vec![ModelCitation { source_index: 0, quote: "q".into() }; 9];
    assert!(too_many.validate().is_err());
    let mut bad_index = ok.clone();
    bad_index.citations = vec![ModelCitation { source_index: 8, quote: "q".into() }];
    assert!(bad_index.validate().is_err());
    let mut long_quote = ok;
    long_quote.citations = vec![ModelCitation { source_index: 0, quote: "x".repeat(241) }];
    assert!(long_quote.validate().is_err());
}
