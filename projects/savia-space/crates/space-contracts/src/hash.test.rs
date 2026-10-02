use super::*;

#[test]
fn known_vector() {
    assert_eq!(
        Sha256Hex::of_bytes(b"abc").as_str(),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
}

#[test]
fn canonical_hash_ignores_key_order() {
    let a = serde_json::json!({"b": 1, "a": 2});
    let b = serde_json::json!({"a": 2, "b": 1});
    assert_eq!(Sha256Hex::of_canonical(&a), Sha256Hex::of_canonical(&b));
}

#[test]
fn rejects_bad_format() {
    assert!(Sha256Hex::try_from("AB".repeat(32)).is_err());
    assert!(Sha256Hex::try_from("ab".repeat(31)).is_err());
    assert!(Sha256Hex::try_from("ab".repeat(32)).is_ok());
}

#[test]
fn deserialization_validates() {
    assert!(serde_json::from_str::<Sha256Hex>(r#""xyz""#).is_err());
}
