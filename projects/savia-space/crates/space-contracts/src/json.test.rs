use super::*;

#[test]
fn rejects_duplicate_keys_at_any_depth() {
    assert!(parse_strict(br#"{"a":1,"a":2}"#).is_err());
    assert!(parse_strict(br#"{"x":{"b":1,"b":1}}"#).is_err());
    assert!(parse_strict(br#"[{"c":true,"c":false}]"#).is_err());
}

#[test]
fn rejects_trailing_content_and_invalid_utf8() {
    assert!(parse_strict(br#"{"a":1} {}"#).is_err());
    assert!(parse_strict(b"\"\xff\"").is_err());
}

#[test]
fn rejects_lone_surrogate_escape() {
    assert!(parse_strict(br#""\ud800""#).is_err());
}

#[test]
fn rejects_non_finite_literals() {
    assert!(parse_strict(b"NaN").is_err());
    assert!(parse_strict(b"Infinity").is_err());
}

#[test]
fn accepts_plain_document() {
    let v = parse_strict(br#"{"a":[1,"x",null,false]}"#).expect("valid");
    assert_eq!(v["a"][1], "x");
    assert!(v["a"][2].is_null());
}
