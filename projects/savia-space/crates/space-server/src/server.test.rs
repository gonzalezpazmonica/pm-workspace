use super::*;
use space_contracts::Sha256Hex;
use space_contracts::model::{NoteSourceRef, Span};

#[tokio::test]
async fn revalidator_accepts_current_hash_and_rejects_changes() {
    let r = KnowledgeRevalidator::fixtures_only();
    let note = Knowledge::fixtures().read("fixtures", "huerto-riego.md").await.expect("read").expect("note");
    let good = NoteSourceRef {
        dome_id: "fixtures".into(),
        resource_id: "huerto-riego.md".into(),
        content_hash: note.content_hash.clone(),
        span: Span { start: 0, end: 1 },
    };
    assert!(r.still_valid(std::slice::from_ref(&good)).await);
    let mut changed = good.clone();
    changed.content_hash = Sha256Hex::of_bytes(b"old version");
    assert!(!r.still_valid(&[good, changed]).await);
    let foreign = NoteSourceRef { dome_id: "otra".into(), ..note_ref() };
    assert!(!r.still_valid(&[foreign]).await, "unknown dome without Vaults = not valid");
}

fn note_ref() -> NoteSourceRef {
    NoteSourceRef {
        dome_id: "fixtures".into(),
        resource_id: "x.md".into(),
        content_hash: Sha256Hex::of_bytes(b"x"),
        span: Span { start: 0, end: 1 },
    }
}

#[test]
fn router_picks_provider_by_model_name() {
    let cfg = Config::default_local();
    let r = ProviderRouter::from_config(&cfg);
    assert!(r.route(br#"{"model":"fixture-v1"}"#).is_some());
    assert!(r.route(br#"{"model":"gemma3:4b"}"#).is_some());
    assert!(r.route(br#"{"model":"desconocido"}"#).is_none());
}

#[test]
fn state_dir_must_be_private() {
    let dir = tempfile::tempdir().expect("tmp");
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(dir.path(), std::fs::Permissions::from_mode(0o755)).expect("chmod");
        assert!(check_state_dir(dir.path()).is_err(), "readable by others");
        std::fs::set_permissions(dir.path(), std::fs::Permissions::from_mode(0o700)).expect("chmod");
    }
    assert!(check_state_dir(dir.path()).is_ok());
}

#[cfg(unix)]
#[tokio::test]
async fn pairing_socket_serves_one_time_codes_to_the_owner() {
    use tokio::io::AsyncReadExt;
    let dir = tempfile::tempdir().expect("tmp");
    let issued = std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
    let counter = issued.clone();
    let sock = dir.path().join("pair.sock");
    let handle = spawn_pairing_listener(&sock, dir.path(), move || {
        counter.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        "abcd-1234".to_owned()
    })
    .expect("listen");
    use std::os::unix::fs::PermissionsExt;
    assert_eq!(std::fs::metadata(&sock).expect("meta").permissions().mode() & 0o777, 0o600);
    let mut s = tokio::net::UnixStream::connect(&sock).await.expect("connect");
    let mut out = String::new();
    s.read_to_string(&mut out).await.expect("read");
    assert_eq!(out.trim(), "abcd-1234");
    assert_eq!(issued.load(std::sync::atomic::Ordering::SeqCst), 1);
    handle.abort();
}
