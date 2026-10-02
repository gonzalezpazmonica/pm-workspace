use super::*;

#[test]
fn every_preset_has_stable_version_hash() {
    for id in [PresetId::Resume, PresetId::Compare, PresetId::DraftSpec] {
        let p = preset(id);
        assert_eq!(p.version, Sha256Hex::of_bytes(p.instructions.as_bytes()));
        assert!(!p.instructions.is_empty());
    }
    assert_ne!(preset(PresetId::Resume).version, preset(PresetId::Compare).version);
}

#[test]
fn builtin_agent_is_hashed() {
    let a = builtin_agent();
    assert_eq!(a.body_hash, Sha256Hex::of_bytes(a.body.as_bytes()));
}
