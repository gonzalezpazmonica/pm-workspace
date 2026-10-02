use super::*;

fn feed_all(chunks: &[&str]) -> (String, Result<(), DecodeError>) {
    let mut d = TextExtractor::default();
    let mut out = String::new();
    for c in chunks {
        match d.push(c) {
            Ok(t) => out.push_str(&t),
            Err(e) => return (out, Err(e)),
        }
    }
    (out, Ok(()))
}

#[test]
fn extracts_text_value_in_one_chunk() {
    let (t, r) = feed_all(&[r#"{"text":"Hola mundo","citations":[],"claims":[]}"#]);
    assert!(r.is_ok());
    assert_eq!(t, "Hola mundo");
}

#[test]
fn extracts_text_when_it_is_the_last_key_and_ignores_other_strings() {
    let doc = r#"{"citations":[{"sourceIndex":0,"quote":"text"}],"claims":[{"text":"no","support":"proposed","citationIndexes":[]}],"text":"sí"}"#;
    let (t, _) = feed_all(&[doc]);
    assert_eq!(t, "sí", "only the top-level text key");
}

#[test]
fn any_chunking_gives_the_same_text() {
    let doc = "{\"text\":\"a\\\"b\\\\c\\n\\u00e9\\ud83d\\ude00 fin\",\"citations\":[],\"claims\":[]}";
    let expected = "a\"b\\c\né😀 fin";
    let chars: Vec<char> = doc.chars().collect();
    for split in 1..chars.len() {
        let a: String = chars[..split].iter().collect();
        let b: String = chars[split..].iter().collect();
        let (t, r) = feed_all(&[&a, &b]);
        assert!(r.is_ok(), "split {split}");
        assert_eq!(t, expected, "split {split}");
    }
    let singles: Vec<String> = chars.iter().map(|c| c.to_string()).collect();
    let refs: Vec<&str> = singles.iter().map(String::as_str).collect();
    assert_eq!(feed_all(&refs).0, expected);
}

#[test]
fn lone_surrogate_is_a_protocol_error() {
    let (_, r) = feed_all(&[r#"{"text":"\ud800x"}"#]);
    assert!(r.is_err());
}

#[test]
fn invalid_escape_is_a_protocol_error() {
    let (_, r) = feed_all(&[r#"{"text":"\q"}"#]);
    assert!(r.is_err());
}

#[test]
fn buffer_limit_is_enforced() {
    let mut d = TextExtractor::default();
    let big = "x".repeat(MAX_RAW_BYTES + 1);
    assert!(d.push(&format!("{{\"text\":\"{big}")).is_err());
}

#[test]
fn raw_buffer_is_kept_for_final_parse() {
    let mut d = TextExtractor::default();
    d.push("{\"text\":\"a\",").expect("ok");
    d.push("\"citations\":[],\"claims\":[]}").expect("ok");
    assert_eq!(d.raw(), "{\"text\":\"a\",\"citations\":[],\"claims\":[]}");
}
