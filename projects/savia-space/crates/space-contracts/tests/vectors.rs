//! Shared JCS vectors (`contracts/vectors/jcs.json`): every implementation of the contracts
//! (Rust here, TypeScript in the web app) must produce the same bytes and hashes.

use space_contracts::{Sha256Hex, jcs, json};

fn vectors() -> serde_json::Value {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../contracts/vectors/jcs.json");
    let raw = std::fs::read(path).expect("vectors file");
    json::parse_strict(&raw).expect("vectors are strict JSON")
}

#[test]
fn accepted_vectors_match_canonical_bytes_and_hash() {
    let v = vectors();
    let cases = v["accept"].as_array().expect("accept list");
    assert!(cases.len() >= 8);
    for case in cases {
        let name = case["name"].as_str().expect("name");
        let input = case["input"].as_str().expect("input");
        let parsed = json::parse_strict(input.as_bytes()).unwrap_or_else(|e| panic!("{name}: {e}"));
        let bytes = jcs::canonicalize(&parsed).unwrap_or_else(|e| panic!("{name}: {e}"));
        assert_eq!(String::from_utf8(bytes.clone()).expect("utf8"), case["canonical"], "{name}");
        assert_eq!(Sha256Hex::of_bytes(&bytes).as_str(), case["sha256"], "{name}");
    }
}

#[test]
fn rejected_vectors_fail_parse_or_canonicalization() {
    let v = vectors();
    for case in v["reject"].as_array().expect("reject list") {
        let name = case["name"].as_str().expect("name");
        let input = case["input"].as_str().expect("input");
        let outcome = json::parse_strict(input.as_bytes())
            .map_err(|e| e.to_string())
            .and_then(|parsed| jcs::canonicalize(&parsed).map_err(|e| e.to_string()));
        assert!(outcome.is_err(), "{name} must be rejected");
    }
}
