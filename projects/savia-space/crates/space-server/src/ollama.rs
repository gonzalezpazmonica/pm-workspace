//! Ollama adapter: POST the approved bytes to `127.0.0.1:<port>/api/chat`, parse NDJSON.
//!
//! No redirects, no retries, no extra fields. `thinking` is dropped. A tool call ends the run.

use futures_util::StreamExt;
use serde_json::Value;
use space_core::provider::{Finish, Provider, ProviderEvent};
use tokio::sync::{mpsc, watch};

pub struct OllamaProvider {
    port: u16,
    client: reqwest::Client,
}

impl OllamaProvider {
    pub fn new(port: u16) -> Self {
        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .no_proxy()
            .build()
            .unwrap_or_default();
        Self { port, client }
    }
}

/// Maps one NDJSON line to provider events.
pub fn parse_line(line: &str) -> Vec<ProviderEvent> {
    let Ok(v) = serde_json::from_str::<Value>(line) else { return vec![ProviderEvent::Failed] };
    if v.get("error").is_some() {
        return vec![ProviderEvent::Failed];
    }
    let msg = &v["message"];
    if msg["tool_calls"].as_array().is_some_and(|a| !a.is_empty()) {
        return vec![ProviderEvent::Done(Finish::ToolCalls)];
    }
    let mut out = Vec::new();
    if let Some(c) = msg["content"].as_str().filter(|c| !c.is_empty()) {
        out.push(ProviderEvent::Chunk(c.to_owned()));
    }
    if v["done"].as_bool() == Some(true) {
        out.push(ProviderEvent::Done(match v["done_reason"].as_str() {
            Some("length") => Finish::Length,
            _ => Finish::Stop,
        }));
    }
    out
}

/// Resolves when cancellation is requested; drops the watch guard before returning.
async fn cancelled(c: &mut watch::Receiver<bool>) {
    let _ = c.wait_for(|v| *v).await.map(|_| ());
}

impl Provider for OllamaProvider {
    fn dispatch(&self, body: Vec<u8>, mut cancel: watch::Receiver<bool>) -> mpsc::Receiver<ProviderEvent> {
        let (tx, rx) = mpsc::channel(64);
        let url = format!("http://127.0.0.1:{}/api/chat", self.port);
        let client = self.client.clone();
        tokio::spawn(async move {
            let send = client.post(url).header("content-type", "application/json").body(body).send();
            let resp = tokio::select! {
                r = send => r,
                _ = cancelled(&mut cancel) => { let _ = tx.send(ProviderEvent::Cancelled).await; return; }
            };
            let Ok(resp) = resp.and_then(|r| r.error_for_status()) else {
                let _ = tx.send(ProviderEvent::Failed).await;
                return;
            };
            let mut stream = resp.bytes_stream();
            let mut buf: Vec<u8> = Vec::new();
            loop {
                let next = tokio::select! {
                    n = stream.next() => n,
                    _ = cancelled(&mut cancel) => {
                        drop(stream); // closes the connection: local abort
                        let _ = tx.send(ProviderEvent::Cancelled).await;
                        return;
                    }
                };
                match next {
                    Some(Ok(bytes)) => {
                        buf.extend_from_slice(&bytes);
                        while let Some(pos) = buf.iter().position(|b| *b == b'\n') {
                            let line: Vec<u8> = buf.drain(..=pos).collect();
                            let text = String::from_utf8_lossy(&line);
                            let text = text.trim();
                            if text.is_empty() {
                                continue;
                            }
                            for ev in parse_line(text) {
                                let terminal = !matches!(ev, ProviderEvent::Chunk(_));
                                if tx.send(ev).await.is_err() || terminal {
                                    return;
                                }
                            }
                        }
                    }
                    Some(Err(_)) => {
                        let _ = tx.send(ProviderEvent::Failed).await;
                        return;
                    }
                    None => return, // EOF without done: the runtime treats it as a protocol error
                }
            }
        });
        rx
    }
}

#[cfg(test)]
#[path = "ollama.test.rs"]
mod tests;
