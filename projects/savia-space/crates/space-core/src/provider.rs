//! Provider port and the deterministic mock provider.
//!
//! A provider receives the exact approved body bytes and streams raw content chunks. It never
//! sees credentials from the client and never adds or reorders anything in the body.

use std::time::Duration;
use tokio::sync::{mpsc, watch};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Finish {
    Stop,
    Length,
    ToolCalls,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ProviderEvent {
    /// Raw content (the model's JSON being built).
    Chunk(String),
    Done(Finish),
    Failed,
    /// Local abort confirmed: the adapter stopped reading and publishing.
    Cancelled,
}

pub trait Provider: Send + Sync {
    /// Sends `body` byte for byte. The stream ends after `Done`, `Failed` or `Cancelled`;
    /// a stream that just closes is an EOF without `done` (protocol error).
    fn dispatch(&self, body: Vec<u8>, cancel: watch::Receiver<bool>) -> mpsc::Receiver<ProviderEvent>;
}

/// Deterministic provider for tests and the mock profile. The prompt may carry
/// `#fixture:<name>` to select a failure mode: length, tool-call, error, eof, quote-mismatch.
pub struct MockProvider {
    pub chunk_delay: Duration,
}

fn sources_of(body: &serde_json::Value) -> Vec<(u64, String)> {
    let user = body["messages"][1]["content"].as_str().unwrap_or("");
    let doc = user.find('{').map(|i| &user[i..]).unwrap_or("{}");
    let parsed: serde_json::Value = serde_json::from_str(doc).unwrap_or_default();
    parsed["sources"]
        .as_array()
        .map(|a| {
            a.iter().map(|s| (s["index"].as_u64().unwrap_or(0), s["text"].as_str().unwrap_or("").to_owned())).collect()
        })
        .unwrap_or_default()
}

fn quote_of(text: &str) -> String {
    let q: String = text.chars().take(40).collect();
    q.trim().to_owned()
}

impl Provider for MockProvider {
    fn dispatch(&self, body: Vec<u8>, mut cancel: watch::Receiver<bool>) -> mpsc::Receiver<ProviderEvent> {
        let (tx, rx) = mpsc::channel(64);
        let delay = self.chunk_delay;
        tokio::spawn(async move {
            let v: serde_json::Value = serde_json::from_slice(&body).unwrap_or_default();
            let prompt = v["messages"]
                .as_array()
                .and_then(|m| m.last())
                .and_then(|m| m["content"].as_str())
                .unwrap_or("")
                .to_owned();
            let sources = sources_of(&v);
            let fixture =
                prompt.split("#fixture:").nth(1).map(|s| s.split_whitespace().next().unwrap_or("").to_owned());
            if fixture.as_deref() == Some("error") {
                let _ = tx.send(ProviderEvent::Failed).await;
                return;
            }
            let citations: Vec<serde_json::Value> = sources
                .iter()
                .map(|(i, t)| {
                    let q = if fixture.as_deref() == Some("quote-mismatch") {
                        "frase inventada".into()
                    } else {
                        quote_of(t)
                    };
                    serde_json::json!({"sourceIndex": i, "quote": q})
                })
                .collect();
            let text = format!(
                "Borrador de prueba generado por el proveedor simulado a partir de {} fuente(s). No es un modelo real.",
                sources.len()
            );
            let output = serde_json::json!({
                "text": text,
                "citations": citations,
                "claims": [{"text": "Resumen de las fuentes seleccionadas.", "support": "quoted", "citationIndexes": [0]}]
            });
            let raw = output.to_string();
            let chars: Vec<char> = raw.chars().collect();
            for piece in chars.chunks(16) {
                if *cancel.borrow() {
                    let _ = tx.send(ProviderEvent::Cancelled).await;
                    return;
                }
                if tx.send(ProviderEvent::Chunk(piece.iter().collect())).await.is_err() {
                    return;
                }
                if !delay.is_zero() {
                    tokio::select! {
                        _ = tokio::time::sleep(delay) => {}
                        _ = cancel.changed() => {
                            let _ = tx.send(ProviderEvent::Cancelled).await;
                            return;
                        }
                    }
                }
            }
            let end = match fixture.as_deref() {
                Some("length") => Some(ProviderEvent::Done(Finish::Length)),
                Some("tool-call") => Some(ProviderEvent::Done(Finish::ToolCalls)),
                Some("eof") => None,
                _ => Some(ProviderEvent::Done(Finish::Stop)),
            };
            if let Some(ev) = end {
                let _ = tx.send(ev).await;
            }
        });
        rx
    }
}

#[cfg(test)]
#[path = "provider.test.rs"]
mod tests;
