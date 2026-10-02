use super::*;
use crate::store::{Store, insert_run};
use space_contracts::model::RunState;

const NOW: &str = "2026-10-02T21:00:00.000Z";

fn setup() -> (tempfile::TempDir, Store, Uuid, Uuid) {
    let dir = tempfile::tempdir().expect("tmp");
    let mut s = Store::open(&dir.path().join("space.db")).expect("open");
    let project = Uuid::now_v7();
    let sid = s.create_session(project, "S", NOW).expect("session").id;
    (dir, s, project, sid)
}

#[test]
fn sessions_are_listed_per_project_newest_first() {
    let (_d, mut s, project, first) = setup();
    let second = s.create_session(project, "T", "2026-10-02T22:00:00.000Z").expect("s").id;
    s.create_session(Uuid::now_v7(), "otro proyecto", NOW).expect("s");
    let tx = s.begin().expect("tx");
    let ids: Vec<Uuid> = list_sessions(&tx, project, 50).expect("list").into_iter().map(|r| r.id).collect();
    assert_eq!(ids, vec![second, first]);
}

#[test]
fn captures_bind_to_a_session_and_selection_has_cas() {
    let (_d, mut s, project, sid) = setup();
    let tx = s.begin().expect("tx");
    let cap = CaptureRow {
        id: Uuid::now_v7(),
        project_id: project,
        session_id: None,
        dome_id: "d".into(),
        resource_id: "r.md".into(),
        title: "R".into(),
        content_hash: Sha256Hex::of_bytes(b"texto"),
        text_base: "texto".into(),
        obtained_at: NOW.into(),
    };
    insert_capture(&tx, &cap).expect("capture");
    bind_capture(&tx, cap.id, sid).expect("bind");
    assert_eq!(get_capture(&tx, cap.id).expect("get").expect("row").session_id, Some(sid));
    assert_eq!(put_selection(&tx, sid, 0, "[1]").expect("put"), Some(1));
    assert_eq!(put_selection(&tx, sid, 0, "[2]").expect("stale"), None);
    assert_eq!(put_selection(&tx, sid, 1, "[2]").expect("put"), Some(2));
    let sel = get_selection(&tx, sid).expect("get").expect("row");
    assert_eq!((sel.revision, sel.refs.as_str()), (2, "[2]"));
}

#[test]
fn orphan_captures_expire() {
    let (_d, mut s, project, _sid) = setup();
    let tx = s.begin().expect("tx");
    let mut cap = CaptureRow {
        id: Uuid::now_v7(),
        project_id: project,
        session_id: None,
        dome_id: "d".into(),
        resource_id: "r.md".into(),
        title: "R".into(),
        content_hash: Sha256Hex::of_bytes(b"x"),
        text_base: "x".into(),
        obtained_at: "2026-10-02T20:00:00.000Z".into(),
    };
    insert_capture(&tx, &cap).expect("old");
    cap.id = Uuid::now_v7();
    cap.obtained_at = NOW.into();
    insert_capture(&tx, &cap).expect("fresh");
    assert_eq!(purge_orphan_captures(&tx, "2026-10-02T20:59:30.000Z").expect("purge"), 1);
}

#[test]
fn runs_are_listed_newest_first_and_web_sessions_validate() {
    let (_d, mut s, _p, sid) = setup();
    let tx = s.begin().expect("tx");
    let r = Uuid::now_v7();
    insert_run(&tx, r, sid, RunState::Queued, NOW).expect("run");
    assert_eq!(list_runs(&tx, sid, 20).expect("runs")[0].0, r);
    let token_hash = Sha256Hex::of_bytes(b"token");
    insert_web_session(&tx, &token_hash, NOW).expect("ws");
    assert!(
        web_session_valid(&tx, &token_hash, "2026-10-02T22:00:00.000Z", 8 * 3_600_000, 24 * 3_600_000).expect("ok")
    );
    assert!(
        !web_session_valid(&tx, &token_hash, "2026-10-03T06:00:01.000Z", 8 * 3_600_000, 24 * 3_600_000).expect("idle")
    );
    revoke_web_session(&tx, &token_hash).expect("revoke");
    assert!(!web_session_valid(&tx, &token_hash, NOW, 8 * 3_600_000, 24 * 3_600_000).expect("revoked"));
}
