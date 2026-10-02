use super::*;
use space_contracts::model::{EventBody, RunState};

const NOW: &str = "2026-10-02T21:00:00.000Z";

fn open() -> (tempfile::TempDir, Store) {
    let dir = tempfile::tempdir().expect("tmp");
    let store = Store::open(&dir.path().join("space.db")).expect("open");
    (dir, store)
}

fn new_session(store: &mut Store) -> Uuid {
    store.create_session(Uuid::now_v7(), "Proyecto", NOW).expect("session").id
}

#[test]
fn pragmas_are_safe_defaults() {
    let (_d, store) = open();
    assert_eq!(store.pragma("journal_mode"), "wal");
    assert_eq!(store.pragma("foreign_keys"), "1");
    assert_eq!(store.pragma("synchronous"), "2", "FULL");
}

#[test]
fn schema_version_is_recorded_and_reopen_is_idempotent() {
    let dir = tempfile::tempdir().expect("tmp");
    let path = dir.path().join("space.db");
    let mut s = Store::open(&path).expect("open");
    let sid = new_session(&mut s);
    drop(s);
    let s = Store::open(&path).expect("reopen");
    assert_eq!(s.schema_version(), SCHEMA_VERSION);
    assert!(s.get_session(sid).expect("query").is_some());
}

#[test]
fn newer_schema_refuses_to_open() {
    let dir = tempfile::tempdir().expect("tmp");
    let path = dir.path().join("space.db");
    let s = Store::open(&path).expect("open");
    s.conn.execute("UPDATE meta SET value='999' WHERE key='schema_version'", []).expect("bump");
    drop(s);
    assert!(matches!(Store::open(&path), Err(StoreError::SchemaTooNew(999))));
}

#[test]
fn event_sequences_are_per_session_and_gapless() {
    let (_d, mut s) = open();
    let a = new_session(&mut s);
    let b = new_session(&mut s);
    let body = EventBody::RunState { state: RunState::Queued, revision: 1, reason: None };
    let tx = s.begin().expect("tx");
    assert_eq!(append_event(&tx, a, None, &body, NOW).expect("ev").sequence, 1);
    assert_eq!(append_event(&tx, a, None, &body, NOW).expect("ev").sequence, 2);
    assert_eq!(append_event(&tx, b, None, &body, NOW).expect("ev").sequence, 1);
    tx.commit().expect("commit");
    let after = s.events_after(a, 1).expect("events");
    assert_eq!(after.iter().map(|e| e.sequence).collect::<Vec<_>>(), vec![2]);
    assert_eq!(s.watermark(a).expect("w"), 2);
}

#[test]
fn rolled_back_events_leave_no_gap() {
    let (_d, mut s) = open();
    let a = new_session(&mut s);
    let body = EventBody::RunState { state: RunState::Queued, revision: 1, reason: None };
    {
        let tx = s.begin().expect("tx");
        append_event(&tx, a, None, &body, NOW).expect("ev");
        // dropped without commit
    }
    let tx = s.begin().expect("tx");
    assert_eq!(append_event(&tx, a, None, &body, NOW).expect("ev").sequence, 1);
    tx.commit().expect("commit");
}

#[test]
fn idempotency_returns_original_or_conflict() {
    let (_d, mut s) = open();
    let key = IdemKey { principal: "p", operation: "run.create", target: Some("t"), key: "k1" };
    let h1 = Sha256Hex::of_bytes(b"one");
    let h2 = Sha256Hex::of_bytes(b"two");
    let tx = s.begin().expect("tx");
    assert_eq!(idem_lookup(&tx, &key, &h1).expect("lookup"), IdemOutcome::New);
    idem_record(&tx, &key, &h1, "{\"runId\":1}", NOW).expect("record");
    tx.commit().expect("commit");
    let tx = s.begin().expect("tx");
    assert_eq!(idem_lookup(&tx, &key, &h1).expect("lookup"), IdemOutcome::Replay("{\"runId\":1}".into()));
    assert_eq!(idem_lookup(&tx, &key, &h2).expect("lookup"), IdemOutcome::Conflict);
    let other_target = IdemKey { target: None, ..key };
    assert_eq!(idem_lookup(&tx, &other_target, &h2).expect("lookup"), IdemOutcome::New, "scope includes target");
}

#[test]
fn database_enforces_one_active_run_per_session() {
    let (_d, mut s) = open();
    let a = new_session(&mut s);
    let tx = s.begin().expect("tx");
    insert_run(&tx, Uuid::now_v7(), a, RunState::Queued, NOW).expect("first");
    assert!(insert_run(&tx, Uuid::now_v7(), a, RunState::Queued, NOW).is_err(), "second active run");
    tx.commit().expect("commit");
}

#[test]
fn terminal_runs_do_not_block_new_ones() {
    let (_d, mut s) = open();
    let a = new_session(&mut s);
    let tx = s.begin().expect("tx");
    let r1 = Uuid::now_v7();
    insert_run(&tx, r1, a, RunState::Queued, NOW).expect("first");
    set_run_state(&tx, r1, RunState::Failed, None, NOW).expect("terminal");
    insert_run(&tx, Uuid::now_v7(), a, RunState::Queued, NOW).expect("new run after terminal");
    tx.commit().expect("commit");
}

#[test]
fn terminal_state_is_immutable() {
    let (_d, mut s) = open();
    let a = new_session(&mut s);
    let tx = s.begin().expect("tx");
    let r = Uuid::now_v7();
    insert_run(&tx, r, a, RunState::Queued, NOW).expect("run");
    set_run_state(&tx, r, RunState::Cancelled, None, NOW).expect("cancel");
    assert!(matches!(set_run_state(&tx, r, RunState::Completed, None, NOW), Err(StoreError::TerminalRun)));
}

#[test]
fn deleting_session_cascades() {
    let (_d, mut s) = open();
    let a = new_session(&mut s);
    let tx = s.begin().expect("tx");
    let body = EventBody::RunState { state: RunState::Queued, revision: 1, reason: None };
    append_event(&tx, a, None, &body, NOW).expect("ev");
    insert_run(&tx, Uuid::now_v7(), a, RunState::Queued, NOW).expect("run");
    tx.execute("DELETE FROM sessions WHERE id = ?1", [a.to_string()]).expect("delete");
    let left: i64 = tx
        .query_row("SELECT (SELECT COUNT(*) FROM events) + (SELECT COUNT(*) FROM runs)", [], |r| r.get(0))
        .expect("count");
    assert_eq!(left, 0);
}

#[test]
fn session_revision_cas() {
    let (_d, mut s) = open();
    let a = new_session(&mut s);
    let tx = s.begin().expect("tx");
    assert_eq!(bump_session(&tx, a, 1, NOW, true).expect("bump"), Some(2));
    assert_eq!(bump_session(&tx, a, 1, NOW, true).expect("stale"), None, "stale revision");
    tx.commit().expect("commit");
    let row = s.get_session(a).expect("q").expect("row");
    assert_eq!(row.revision, 2);
}
