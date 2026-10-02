use super::*;

#[test]
fn formats_epoch_millis_as_rfc3339_utc() {
    assert_eq!(format_utc_millis(0), "1970-01-01T00:00:00.000Z");
    assert_eq!(format_utc_millis(951_782_400_123), "2000-02-29T00:00:00.123Z", "leap day");
    assert_eq!(format_utc_millis(1_790_985_600_000), "2026-10-03T00:00:00.000Z");
}

#[test]
fn parses_back_what_it_formats() {
    for ms in [0_i64, 951_782_400_123, 1_790_985_659_999, 4_102_444_800_000] {
        assert_eq!(parse_utc_millis(&format_utc_millis(ms)), Some(ms), "{ms}");
    }
}

#[test]
fn rejects_non_canonical_timestamps() {
    assert_eq!(parse_utc_millis("2026-10-03T00:00:00Z"), None, "milliseconds are mandatory");
    assert_eq!(parse_utc_millis("2026-10-03T00:00:00.000+02:00"), None, "only Z");
    assert_eq!(parse_utc_millis("2026-13-01T00:00:00.000Z"), None);
}

#[test]
fn now_is_monotone_enough_and_well_formed() {
    let n = utc_now();
    assert_eq!(n.len(), 24);
    assert!(parse_utc_millis(&n).is_some());
}
