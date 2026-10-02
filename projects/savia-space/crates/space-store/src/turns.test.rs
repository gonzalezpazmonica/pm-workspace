use super::*;
use crate::store::{Store, insert_run};
use space_contracts::model::{MessageStatus, Role, RunState};

const NOW: &str = "2026-10-02T21:00:00.000Z";

fn setup() -> (tempfile::TempDir, Store, Uuid) {
    let dir = tempfile::tempdir().expect("tmp");
    let mut s = Store::open(&dir.path().join("space.db")).expect("open");
    let sid = s.create_session(Uuid::now_v7(), "S", NOW).expect("session").id;
    (dir, s, sid)
}

fn preview(session_id: Uuid) -> PreviewRow {
    PreviewRow {
        id: Uuid::now_v7(),
        session_id,
        run_id: Uuid::now_v7(),
        request_hash: Sha256Hex::of_bytes(b"req"),
        manifest_hash: Sha256Hex::of_bytes(b"man"),
        payload_hash: Sha256Hex::of_bytes(b"body"),
        manifest: "{}".into(),
        body: b"body".to_vec(),
        expires_at: "2026-10-02T21:01:00.000Z".into(),
        consumed: false,
    }
}

#[test]
fn preview_round_trip_and_single_consumption() {
    let (_d, mut s, sid) = setup();
    let p = preview(sid);
    let tx = s.begin().expect("tx");
    insert_preview(&tx, &p).expect("insert");
    assert_eq!(get_preview(&tx, p.id).expect("get"), Some(p.clone()));
    assert!(consume_preview(&tx, p.id).expect("consume"));
    assert!(!consume_preview(&tx, p.id).expect("second"), "only once");
    assert!(get_preview(&tx, p.id).expect("get").expect("row").consumed);
}

#[test]
fn messages_get_unique_created_sequence_and_update_in_place() {
    let (_d, mut s, sid) = setup();
    let tx = s.begin().expect("tx");
    let run = Uuid::now_v7();
    insert_run(&tx, run, sid, RunState::Queued, NOW).expect("run");
    let m = Uuid::now_v7();
    insert_message(&tx, m, sid, Some(run), Role::Assistant, MessageStatus::Partial, 5, "", None).expect("msg");
    assert!(
        insert_message(&tx, Uuid::now_v7(), sid, Some(run), Role::User, MessageStatus::Final, 5, "x", None).is_err(),
        "createdSequence unique per session"
    );
    finalize_message(&tx, m, MessageStatus::Final, "hola", "[]").expect("final");
    let msgs = list_messages(&tx, sid, u64::MAX, 50).expect("list");
    assert_eq!(msgs.len(), 1);
    assert_eq!(msgs[0].text, "hola");
    assert_eq!(msgs[0].created_sequence, 5, "unchanged by finalization");
}

#[test]
fn attempt_state_transitions_and_output_storage() {
    let (_d, mut s, sid) = setup();
    let tx = s.begin().expect("tx");
    let run = Uuid::now_v7();
    insert_run(&tx, run, sid, RunState::Queued, NOW).expect("run");
    let a = Uuid::now_v7();
    insert_attempt(&tx, a, run, "DISPATCH_INTENT", 1, NOW).expect("attempt");
    set_attempt_state(&tx, run, "OUTPUT_COMPLETE", Some(NOW)).expect("state");
    store_output(&tx, run, b"{}").expect("output");
    assert_eq!(attempt_state(&tx, run).expect("q").as_deref(), Some("OUTPUT_COMPLETE"));
    assert_eq!(load_output(&tx, run).expect("q"), Some(b"{}".to_vec()));
    assert!(insert_attempt(&tx, Uuid::now_v7(), run, "DISPATCH_INTENT", 1, NOW).is_err(), "one attempt per run");
}

#[test]
fn non_terminal_runs_are_listed_for_recovery() {
    let (_d, mut s, sid) = setup();
    let tx = s.begin().expect("tx");
    let r = Uuid::now_v7();
    insert_run(&tx, r, sid, RunState::Running, NOW).expect("run");
    assert_eq!(non_terminal_runs(&tx).expect("q"), vec![(r, sid)]);
}

#[test]
fn preview_is_found_by_run() {
    let (_d, mut s, sid) = setup();
    let p = preview(sid);
    let tx = s.begin().expect("tx");
    insert_preview(&tx, &p).expect("insert");
    assert_eq!(get_preview_by_run(&tx, p.run_id).expect("q").map(|x| x.id), Some(p.id));
    assert_eq!(get_preview_by_run(&tx, Uuid::now_v7()).expect("q"), None);
}

#[test]
fn validation_report_is_stored_with_the_message() {
    let (_d, mut s, sid) = setup();
    let tx = s.begin().expect("tx");
    let m = Uuid::now_v7();
    insert_message(&tx, m, sid, None, Role::Assistant, MessageStatus::Partial, 1, "", None).expect("msg");
    assert_eq!(get_message(&tx, m).expect("get").expect("row").validation, None);
    set_message_validation(&tx, m, "{\"status\":\"FAIL\"}").expect("set");
    assert_eq!(get_message(&tx, m).expect("get").expect("row").validation.as_deref(), Some("{\"status\":\"FAIL\"}"));
}

#[test]
fn session_message_lookup_never_crosses_sessions() {
    let (_d, mut s, sid) = setup();
    let tx = s.begin().expect("tx");
    let m = Uuid::now_v7();
    insert_message(&tx, m, sid, None, Role::User, MessageStatus::Final, 1, "hola", None).expect("msg");
    assert_eq!(get_session_message(&tx, sid, m).expect("get").map(|r| r.id), Some(m));
    assert_eq!(get_session_message(&tx, Uuid::now_v7(), m).expect("get"), None);
}
