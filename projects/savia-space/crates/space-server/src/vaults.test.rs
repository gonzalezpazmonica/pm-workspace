use super::*;

#[test]
fn request_is_newline_delimited_jsonrpc() {
    let line = request_line(7, "tools/call", serde_json::json!({"name": "vault_read"}));
    assert!(line.ends_with('\n'));
    let v: serde_json::Value = serde_json::from_str(line.trim_end()).expect("json");
    assert_eq!(v["jsonrpc"], "2.0");
    assert_eq!(v["id"], 7);
}

#[test]
fn tool_text_extracts_text_and_flags_errors() {
    let ok = serde_json::json!({"content": [{"type": "text", "text": "{\"a\":1}"}]});
    assert_eq!(tool_text(&ok).expect("ok"), "{\"a\":1}");
    let err = serde_json::json!({"content": [{"type": "text", "text": "Error: denied"}], "isError": true});
    assert!(matches!(tool_text(&err), Err(ToolError::Denied)));
}

#[test]
fn rag_hits_are_mapped_and_capped() {
    let text = serde_json::json!({
        "results": [{"query": "riego", "hits": [
            {"dome": "SaviaDocs", "confidentiality": "N1", "path": "a.md", "heading": "A", "text": "uno", "score": 0.5},
            {"dome": "Privada", "confidentiality": "N3", "path": "b.md", "heading": "B", "text": "dos", "score": 0.4}
        ]}],
        "domes": [{"name": "SaviaDocs", "status": "ok"}]
    })
    .to_string();
    let hits = parse_rag(&text, 8).expect("parse");
    assert_eq!(hits.len(), 1, "N3 and above never become candidates");
    assert_eq!(hits[0].resource_id, "a.md");
    assert!(!hits[0].degraded);
}

#[test]
fn read_returns_content_and_rejects_high_levels() {
    let ok = serde_json::json!({"path": "a.md", "content": "# T\r\nhola", "frontmatter": {"confidentiality": "N2"}})
        .to_string();
    let note = parse_read("Dome", "a.md", &ok).expect("parse").expect("note");
    assert_eq!(note.text_base, "# T\nhola");
    assert_eq!(note.title, "T");
    let n4 = serde_json::json!({"path": "a.md", "content": "x", "frontmatter": {"confidentiality": "N4"}}).to_string();
    assert!(parse_read("Dome", "a.md", &n4).expect("parse").is_none());
    let missing = serde_json::json!({"path": "a.md", "content": "x"}).to_string();
    assert!(parse_read("Dome", "a.md", &missing).expect("parse").is_some(), "no label = N1 default of the dome");
}

#[test]
fn oversized_note_is_refused() {
    let big = "x".repeat(MAX_NOTE_BYTES + 1);
    let doc = serde_json::json!({"path": "a.md", "content": big}).to_string();
    assert!(parse_read("D", "a.md", &doc).is_err());
}
