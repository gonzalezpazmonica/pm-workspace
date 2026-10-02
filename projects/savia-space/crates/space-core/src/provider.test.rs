use super::*;
use crate::decoder::TextExtractor;
use space_contracts::model::ModelOutput;

fn body(prompt: &str, sources: &[(u8, &str)]) -> Vec<u8> {
    let docs: Vec<serde_json::Value> =
        sources.iter().map(|(i, t)| serde_json::json!({"index": i, "title": "t", "text": t})).collect();
    let doc = serde_json::json!({"sources": docs});
    let user = format!("preámbulo\n{}", serde_json::to_string(&doc).expect("doc"));
    serde_json::to_vec(&serde_json::json!({
        "model": "fixture-v1",
        "messages": [{"role": "system", "content": "s"}, {"role": "user", "content": user}, {"role": "user", "content": prompt}],
        "stream": true, "tools": []
    }))
    .expect("body")
}

async fn collect(mut rx: tokio::sync::mpsc::Receiver<ProviderEvent>) -> (String, Option<ProviderEvent>) {
    let mut raw = String::new();
    while let Some(ev) = rx.recv().await {
        match ev {
            ProviderEvent::Chunk(c) => raw.push_str(&c),
            other => return (raw, Some(other)),
        }
    }
    (raw, None)
}

#[tokio::test]
async fn mock_cites_every_source_with_a_literal_quote() {
    let p = MockProvider { chunk_delay: std::time::Duration::ZERO };
    let (_cancel_tx, cancel_rx) = tokio::sync::watch::channel(false);
    let rx = p.dispatch(body("Resume", &[(0, "El cielo es azul hoy."), (1, "La hierba crece.")]), cancel_rx);
    let (raw, end) = collect(rx).await;
    assert_eq!(end, Some(ProviderEvent::Done(Finish::Stop)));
    let out: ModelOutput = serde_json::from_str(&raw).expect("valid model output");
    assert_eq!(out.citations.len(), 2);
    assert!("El cielo es azul hoy.".contains(&out.citations[0].quote));
    let mut d = TextExtractor::default();
    assert!(!d.push(&raw).expect("decode").is_empty());
}

#[tokio::test]
async fn fixtures_cover_failure_modes() {
    let p = MockProvider { chunk_delay: std::time::Duration::ZERO };
    for (tag, expected) in [
        ("#fixture:length", Some(ProviderEvent::Done(Finish::Length))),
        ("#fixture:tool-call", Some(ProviderEvent::Done(Finish::ToolCalls))),
        ("#fixture:error", Some(ProviderEvent::Failed)),
        ("#fixture:eof", None),
    ] {
        let (_t, c) = tokio::sync::watch::channel(false);
        let (_, end) = collect(p.dispatch(body(tag, &[(0, "Texto.")]), c)).await;
        assert_eq!(end, expected, "{tag}");
    }
}

#[tokio::test]
async fn cancel_stops_the_stream_without_done() {
    let p = MockProvider { chunk_delay: std::time::Duration::from_millis(20) };
    let (cancel_tx, cancel_rx) = tokio::sync::watch::channel(false);
    let mut rx = p.dispatch(body("Resume", &[(0, "Texto largo de prueba.")]), cancel_rx);
    let _first = rx.recv().await;
    cancel_tx.send(true).expect("cancel");
    let (_, end) = collect(rx).await;
    assert_eq!(end, Some(ProviderEvent::Cancelled));
}
