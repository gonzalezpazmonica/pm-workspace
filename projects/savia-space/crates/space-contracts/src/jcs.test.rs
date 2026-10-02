use super::*;
use serde_json::json;

fn canon(v: Value) -> String {
    String::from_utf8(canonicalize(&v).expect("canonical")).expect("utf8")
}

#[test]
fn sorts_keys_by_utf16_not_by_codepoint() {
    // U+10000 is a surrogate pair (0xD800 0xDC00) and sorts before U+FB33 in UTF-16,
    // although it is after it by code point.
    let v = json!({"\u{FB33}": 1, "\u{10000}": 2});
    assert_eq!(canon(v), "{\"\u{10000}\":2,\"\u{FB33}\":1}");
}

#[test]
fn escapes_like_json_stringify() {
    let v = json!("a\"b\\c\u{1}\u{1f}\n\t\u{7f}\u{2028}é");
    assert_eq!(canon(v), "\"a\\\"b\\\\c\\u0001\\u001f\\n\\t\u{7f}\u{2028}é\"");
}

#[test]
fn rejects_floats_and_unsafe_integers() {
    assert_eq!(canonicalize(&json!(1.5)), Err(JcsError::NonInteger));
    assert_eq!(canonicalize(&json!(1.0)), Err(JcsError::NonInteger));
    assert_eq!(canonicalize(&json!(9_007_199_254_740_992_i64)), Err(JcsError::UnsafeInteger));
    assert_eq!(canonicalize(&json!(u64::MAX)), Err(JcsError::UnsafeInteger));
    assert_eq!(canon(json!(-9_007_199_254_740_991_i64)), "-9007199254740991");
}

#[test]
fn rejects_floats_nested_inside_containers() {
    assert_eq!(canonicalize(&json!({"a": [1, {"b": 0.5}]})), Err(JcsError::NonInteger));
}

#[test]
fn keeps_null_and_empty_containers_distinct() {
    assert_eq!(canon(json!({"a": null, "b": [], "c": {}, "d": ""})), r#"{"a":null,"b":[],"c":{},"d":""}"#);
}

#[test]
fn canonical_form_is_idempotent() {
    let v = json!({"z": [3, 2, 1], "a": {"y": "\u{1F600}", "x": null}});
    let once = canonicalize(&v).expect("canonical");
    let reparsed = crate::json::parse_strict(&once).expect("valid");
    assert_eq!(canonicalize(&reparsed).expect("canonical"), once);
}
