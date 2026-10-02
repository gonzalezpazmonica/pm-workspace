use super::*;

#[test]
fn reexports_store_api() {
    let dir = tempfile::tempdir().expect("tmp");
    let _lock = InstanceLock::acquire(dir.path()).expect("lock");
    let store = Store::open(&dir.path().join("space.db")).expect("open");
    assert_eq!(store.schema_version(), SCHEMA_VERSION);
}
