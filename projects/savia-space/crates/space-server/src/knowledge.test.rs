use super::*;

#[tokio::test]
async fn fixture_search_finds_relevant_notes_only_in_allowed_domes() {
    let k = Knowledge::fixtures();
    let hits = k.search(&["riego depósito".into()], &["fixtures".into()], 8).await.expect("search");
    assert!(!hits.is_empty());
    assert_eq!(hits[0].resource_id, "huerto-riego.md");
    let none = k.search(&["riego".into()], &["otra-cupula".into()], 8).await.expect("search");
    assert!(none.is_empty(), "domes outside the binding are invisible");
}

#[tokio::test]
async fn read_normalizes_newlines_and_hashes_full_text() {
    let k = Knowledge::fixtures();
    let note = k.read("fixtures", "huerto-cultivos.md").await.expect("read").expect("exists");
    assert!(!note.text_base.contains('\r'));
    assert_eq!(note.content_hash, Sha256Hex::of_bytes(note.text_base.as_bytes()));
    assert!(k.read("fixtures", "no-existe.md").await.expect("read").is_none());
}

#[test]
fn normalization_only_touches_line_endings() {
    assert_eq!(normalize_text("a\r\nb\rc\n"), "a\nb\nc\n");
    assert_eq!(normalize_text("é\u{301}"), "é\u{301}", "no Unicode normalization");
}
