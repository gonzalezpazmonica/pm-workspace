use super::*;

#[test]
fn content_lines_become_chunks() {
    let ev = parse_line(r#"{"model":"m","message":{"role":"assistant","content":"{\"text\":"},"done":false}"#);
    assert_eq!(ev, vec![ProviderEvent::Chunk("{\"text\":".into())]);
}

#[test]
fn done_reasons_map_to_finish() {
    assert_eq!(
        parse_line(r#"{"message":{"content":""},"done":true,"done_reason":"stop"}"#),
        vec![ProviderEvent::Done(Finish::Stop)]
    );
    assert_eq!(
        parse_line(r#"{"message":{"content":"x"},"done":true,"done_reason":"length"}"#),
        vec![ProviderEvent::Chunk("x".into()), ProviderEvent::Done(Finish::Length)]
    );
}

#[test]
fn tool_calls_and_errors_are_terminal() {
    assert_eq!(
        parse_line(r#"{"message":{"content":"","tool_calls":[{"function":{"name":"bash"}}]},"done":false}"#),
        vec![ProviderEvent::Done(Finish::ToolCalls)]
    );
    assert_eq!(parse_line(r#"{"error":"model not found"}"#), vec![ProviderEvent::Failed]);
    assert_eq!(parse_line("not json"), vec![ProviderEvent::Failed]);
}

#[test]
fn thinking_is_never_forwarded() {
    let ev = parse_line(r#"{"message":{"content":"","thinking":"secret reasoning"},"done":false}"#);
    assert!(ev.is_empty());
}

#[tokio::test]
async fn sends_exact_bytes_to_a_loopback_server() {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.expect("bind");
    let port = listener.local_addr().expect("addr").port();
    let body = br#"{"messages":[],"model":"m","stream":true,"tools":[]}"#.to_vec();
    let expected = body.clone();
    let server = tokio::spawn(async move {
        let (mut sock, _) = listener.accept().await.expect("accept");
        let mut buf = vec![0u8; 8192];
        let mut got = Vec::new();
        loop {
            let n = sock.read(&mut buf).await.expect("read");
            got.extend_from_slice(&buf[..n]);
            if let Some(pos) = got.windows(4).position(|w| w == b"\r\n\r\n") {
                let head = String::from_utf8_lossy(&got[..pos]).to_lowercase();
                let len: usize = head
                    .lines()
                    .find_map(|l| l.strip_prefix("content-length:").map(|v| v.trim().parse().unwrap_or(0)))
                    .unwrap_or(0);
                if got.len() >= pos + 4 + len {
                    let received = got[pos + 4..pos + 4 + len].to_vec();
                    let reply = "{\"message\":{\"content\":\"hola\"},\"done\":false}\n{\"message\":{\"content\":\"\"},\"done\":true,\"done_reason\":\"stop\"}\n";
                    let resp = format!(
                        "HTTP/1.1 200 OK\r\ncontent-type: application/x-ndjson\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}",
                        reply.len(),
                        reply
                    );
                    sock.write_all(resp.as_bytes()).await.expect("write");
                    return received;
                }
            }
        }
    });
    let p = OllamaProvider::new(port);
    let (_tx, cancel) = tokio::sync::watch::channel(false);
    let mut rx = p.dispatch(body, cancel);
    let mut events = Vec::new();
    while let Some(e) = rx.recv().await {
        events.push(e);
    }
    assert_eq!(server.await.expect("server"), expected, "bytes on the wire = approved bytes");
    assert_eq!(events, vec![ProviderEvent::Chunk("hola".into()), ProviderEvent::Done(Finish::Stop)]);
}
