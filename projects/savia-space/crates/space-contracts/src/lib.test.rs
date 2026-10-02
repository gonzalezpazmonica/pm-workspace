use super::*;

#[test]
fn public_api_reexports_hash_type() {
    let h: Sha256Hex = Sha256Hex::of_bytes(b"");
    assert_eq!(h.as_str(), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
}
