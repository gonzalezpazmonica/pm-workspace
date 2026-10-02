use super::*;

fn args(v: &[&str]) -> Vec<String> {
    v.iter().map(|s| s.to_string()).collect()
}

#[test]
fn parses_commands() {
    assert_eq!(parse(&args(&["serve"])), Ok(Cmd::Serve { web: None }));
    assert_eq!(parse(&args(&["serve", "--web", "/tmp/w"])), Ok(Cmd::Serve { web: Some("/tmp/w".into()) }));
    assert_eq!(parse(&args(&["pair"])), Ok(Cmd::Pair));
    assert_eq!(parse(&args(&["doctor"])), Ok(Cmd::Doctor));
    assert!(parse(&args(&[])).is_err());
    assert!(parse(&args(&["serve", "--bind", "0.0.0.0"])).is_err(), "no bind override on the command line");
}
