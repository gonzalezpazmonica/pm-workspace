use super::*;

#[test]
fn default_config_round_trips_and_validates() {
    let c = Config::default_local();
    c.validate().expect("valid");
    let text = serde_json::to_string_pretty(&c).expect("ser");
    let back: Config = serde_json::from_str(&text).expect("de");
    assert_eq!(back, c);
}

#[test]
fn unknown_fields_and_non_loopback_hosts_are_rejected() {
    let mut v = serde_json::to_value(Config::default_local()).expect("ser");
    v["extra"] = serde_json::json!(1);
    assert!(serde_json::from_value::<Config>(v).is_err());
    let mut c = Config::default_local();
    c.bind = "0.0.0.0".into();
    assert!(c.validate().is_err());
}

#[test]
fn defaults_must_belong_to_allowlists() {
    let mut c = Config::default_local();
    c.projects[0].default_profile = "inexistente".into();
    assert!(c.validate().is_err());
}

#[test]
fn load_or_init_writes_a_private_file_once() {
    let dir = tempfile::tempdir().expect("tmp");
    let first = Config::load_or_init(dir.path()).expect("init");
    let second = Config::load_or_init(dir.path()).expect("load");
    assert_eq!(first, second);
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mode = std::fs::metadata(dir.path().join("config.json")).expect("meta").permissions().mode();
        assert_eq!(mode & 0o777, 0o600);
    }
}
