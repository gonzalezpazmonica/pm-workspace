use super::*;

#[test]
fn second_lock_on_same_dir_fails_and_releases_on_drop() {
    let dir = tempfile::tempdir().expect("tmp");
    let first = InstanceLock::acquire(dir.path()).expect("first lock");
    assert!(matches!(InstanceLock::acquire(dir.path()), Err(LockError::Held)));
    drop(first);
    assert!(InstanceLock::acquire(dir.path()).is_ok(), "released on drop");
}
