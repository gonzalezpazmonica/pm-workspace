use super::*;
use crate::catalog::{CaptureRow, insert_capture, insert_web_session};
use crate::store::{Store, insert_run};
use space_contracts::Sha256Hex;
use space_contracts::model::RunState;
use uuid::Uuid;

const OLD: &str = "2026-08-01T00:00:00.000Z";
const RECENT: &str = "2026-10-02T23:00:00.000Z";
const NOW_MS: i64 = 1_791_000_000_000; // 2026-10-03T04:00:00Z

fn capture(project: Uuid, at: &str) -> CaptureRow {
    CaptureRow {
        id: Uuid::now_v7(),
        project_id: project,
        session_id: None,
        dome_id: "d".into(),
        resource_id: "r.md".into(),
        title: "R".into(),
        content_hash: Sha256Hex::of_bytes(b"t"),
        text_base: "t".into(),
        obtained_at: at.into(),
    }
}

fn count(s: &mut Store, table: &str) -> i64 {
    let tx = s.begin().expect("tx");
    tx.query_row(&format!("SELECT COUNT(*) FROM {table}"), [], |r| r.get(0)).expect("count")
}

#[test]
fn purges_only_what_is_past_retention_and_idle() {
    let dir = tempfile::tempdir().expect("tmp");
    let mut s = Store::open(&dir.path().join("space.db")).expect("open");
    let project = Uuid::now_v7();
    let old = s.create_session(project, "vieja", OLD).expect("s").id;
    let busy = s.create_session(project, "vieja con run activo", OLD).expect("s").id;
    let _fresh = s.create_session(project, "reciente", RECENT).expect("s").id;
    {
        let tx = s.begin().expect("tx");
        insert_run(&tx, Uuid::now_v7(), old, RunState::Completed, OLD).expect("run");
        insert_run(&tx, Uuid::now_v7(), busy, RunState::Running, OLD).expect("run");
        insert_capture(&tx, &capture(project, OLD)).expect("orphan old");
        insert_capture(&tx, &capture(project, RECENT)).expect("orphan recent");
        insert_web_session(&tx, &Sha256Hex::of_bytes(b"a"), OLD).expect("web old");
        insert_web_session(&tx, &Sha256Hex::of_bytes(b"b"), RECENT).expect("web recent");
        tx.commit().expect("commit");
    }
    let tx = s.begin().expect("tx");
    let r = purge(&tx, NOW_MS, 30, 48 * 3_600_000).expect("purge");
    tx.commit().expect("commit");
    assert_eq!(r, Purged { sessions: 1, orphan_captures: 1, web_sessions: 1, idempotency: 0 });
    assert_eq!(count(&mut s, "sessions"), 2, "active run protects the session; recent one stays");
    assert_eq!(count(&mut s, "runs"), 1, "runs of the purged session cascade");
    assert_eq!(count(&mut s, "captures"), 1);
    assert_eq!(count(&mut s, "web_sessions"), 1);
}
