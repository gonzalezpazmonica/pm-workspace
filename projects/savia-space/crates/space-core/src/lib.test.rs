use super::*;

#[test]
fn modules_are_exposed() {
    assert_eq!(clock::format_utc_millis(0).len(), 24);
    const { assert!(decoder::MAX_RAW_BYTES > 0) };
    const { assert!(context::MAX_BODY_MESSAGES == 20) };
}
