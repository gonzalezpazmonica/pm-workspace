//! savia-vaults over MCP stdio, with the person's own reader token.
//!
//! The child gets a minimal environment built from scratch; the token travels only in
//! `SAVIA_AUTH_TOKEN` (never argv, never a temp file). savia-vaults re-reads users and
//! revocations on every call, so access checks are current.

use crate::knowledge::{Hit, KnowledgeError, Note, normalize_text, snippet_of, title_of};
use serde_json::{Value, json};
use space_contracts::Sha256Hex;
use std::path::PathBuf;
use std::process::Stdio;
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, ChildStdin, ChildStdout, Command};
use tokio::sync::Mutex;

pub const MAX_NOTE_BYTES: usize = 256 * 1024;
const MAX_LINE_BYTES: usize = 2 * 1024 * 1024;
const CALL_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Clone, Debug)]
pub struct VaultsConfig {
    /// e.g. `["node", "/path/to/savia-vaults/dist/cli/main.js", "serve", "--transport", "mcp"]`
    pub command: Vec<String>,
    pub cwd: Option<PathBuf>,
    pub token: Option<String>,
}

struct Conn {
    _child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
    next_id: u64,
}

pub struct Vaults {
    cfg: VaultsConfig,
    conn: Mutex<Option<Conn>>,
}

#[derive(Debug, thiserror::Error)]
pub enum ToolError {
    #[error("access denied or not found")]
    Denied,
    #[error("protocol: {0}")]
    Protocol(String),
}

pub fn request_line(id: u64, method: &str, params: Value) -> String {
    format!("{}\n", json!({"jsonrpc": "2.0", "id": id, "method": method, "params": params}))
}

/// Text payload of an MCP tool result; tool-level errors read as "denied" (indistinguishable).
pub fn tool_text(result: &Value) -> Result<String, ToolError> {
    if result["isError"].as_bool() == Some(true) {
        return Err(ToolError::Denied);
    }
    result["content"]
        .as_array()
        .and_then(|a| a.iter().find(|c| c["type"] == "text"))
        .and_then(|c| c["text"].as_str())
        .map(str::to_owned)
        .ok_or_else(|| ToolError::Protocol("tool result without text".into()))
}

fn level_allowed(level: Option<&str>) -> bool {
    matches!(level.unwrap_or("N1"), "N1" | "N2")
}

pub fn parse_rag(text: &str, limit: usize) -> Result<Vec<Hit>, ToolError> {
    let v: Value = serde_json::from_str(text).map_err(|e| ToolError::Protocol(e.to_string()))?;
    let degraded_domes: Vec<String> = v["domes"]
        .as_array()
        .map(|a| {
            a.iter().filter(|d| d["status"] != "ok").filter_map(|d| d["name"].as_str().map(str::to_owned)).collect()
        })
        .unwrap_or_default();
    let mut out: Vec<Hit> = Vec::new();
    for result in v["results"].as_array().into_iter().flatten() {
        for h in result["hits"].as_array().into_iter().flatten() {
            if !level_allowed(h["confidentiality"].as_str()) {
                continue;
            }
            let (Some(dome), Some(path)) = (h["dome"].as_str(), h["path"].as_str()) else { continue };
            if out.iter().any(|x| x.dome_id == dome && x.resource_id == path) {
                continue;
            }
            out.push(Hit {
                dome_id: dome.into(),
                resource_id: path.into(),
                heading: h["heading"].as_str().unwrap_or(path).chars().take(240).collect(),
                snippet: snippet_of(h["text"].as_str().unwrap_or(""), 480),
                degraded: degraded_domes.iter().any(|d| d == dome),
            });
            if out.len() >= limit {
                return Ok(out);
            }
        }
    }
    Ok(out)
}

pub fn parse_read(dome: &str, path: &str, text: &str) -> Result<Option<Note>, ToolError> {
    let v: Value = serde_json::from_str(text).map_err(|e| ToolError::Protocol(e.to_string()))?;
    if !level_allowed(v["frontmatter"]["confidentiality"].as_str()) {
        return Ok(None);
    }
    let content = v["content"].as_str().ok_or_else(|| ToolError::Protocol("note without content".into()))?;
    if content.len() > MAX_NOTE_BYTES {
        return Err(ToolError::Protocol("note larger than 256 KiB".into()));
    }
    let text_base = normalize_text(content);
    Ok(Some(Note {
        dome_id: dome.into(),
        resource_id: path.into(),
        title: title_of(&text_base, path),
        content_hash: Sha256Hex::of_bytes(text_base.as_bytes()),
        text_base,
    }))
}

impl Vaults {
    pub fn new(cfg: VaultsConfig) -> Self {
        Self { cfg, conn: Mutex::new(None) }
    }

    async fn spawn(&self) -> Result<Conn, KnowledgeError> {
        let (program, args) =
            self.cfg.command.split_first().ok_or_else(|| KnowledgeError::Unavailable("empty command".into()))?;
        let mut cmd = Command::new(program);
        cmd.args(args)
            .env_clear()
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .kill_on_drop(true);
        for key in ["PATH", "HOME", "LANG"] {
            if let Ok(v) = std::env::var(key) {
                cmd.env(key, v);
            }
        }
        if let Some(t) = &self.cfg.token {
            cmd.env("SAVIA_AUTH_TOKEN", t);
        }
        if let Some(cwd) = &self.cfg.cwd {
            cmd.current_dir(cwd);
        }
        let mut child = cmd.spawn().map_err(|e| KnowledgeError::Unavailable(format!("spawn: {e}")))?;
        let stdin = child.stdin.take().ok_or_else(|| KnowledgeError::Unavailable("no stdin".into()))?;
        let stdout =
            BufReader::new(child.stdout.take().ok_or_else(|| KnowledgeError::Unavailable("no stdout".into()))?);
        let mut conn = Conn { _child: child, stdin, stdout, next_id: 1 };
        rpc(
            &mut conn,
            "initialize",
            json!({
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "savia-space", "version": env!("CARGO_PKG_VERSION")}
            }),
        )
        .await?;
        conn.stdin
            .write_all(b"{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}\n")
            .await
            .map_err(|e| KnowledgeError::Unavailable(e.to_string()))?;
        Ok(conn)
    }

    async fn call_tool(&self, name: &str, args: Value) -> Result<Result<String, ToolError>, KnowledgeError> {
        let mut guard = self.conn.lock().await;
        if guard.is_none() {
            *guard = Some(self.spawn().await?);
        }
        let conn = guard.as_mut().ok_or_else(|| KnowledgeError::Unavailable("no connection".into()))?;
        match rpc(conn, "tools/call", json!({"name": name, "arguments": args})).await {
            Ok(result) => Ok(tool_text(&result)),
            Err(e) => {
                *guard = None; // drop a broken child; the next call starts a fresh one
                Err(e)
            }
        }
    }

    pub async fn search(&self, queries: &[String], domes: &[String], limit: usize) -> Result<Vec<Hit>, KnowledgeError> {
        let args = json!({"queries": queries, "domes": domes, "k": limit.clamp(1, 8), "fields": "lean"});
        match self.call_tool("vault_rag", args).await? {
            Ok(text) => parse_rag(&text, limit).map_err(|e| KnowledgeError::Unavailable(e.to_string())),
            Err(ToolError::Denied) => Ok(vec![]),
            Err(e) => Err(KnowledgeError::Unavailable(e.to_string())),
        }
    }

    pub async fn read(&self, dome: &str, path: &str) -> Result<Option<Note>, KnowledgeError> {
        match self.call_tool("vault_read", json!({"vault": dome, "path": path})).await? {
            Ok(text) => parse_read(dome, path, &text).map_err(|e| KnowledgeError::Unavailable(e.to_string())),
            Err(ToolError::Denied) => Ok(None),
            Err(e) => Err(KnowledgeError::Unavailable(e.to_string())),
        }
    }
}

async fn rpc(conn: &mut Conn, method: &str, params: Value) -> Result<Value, KnowledgeError> {
    let id = conn.next_id;
    conn.next_id += 1;
    let line = request_line(id, method, params);
    let unavailable = |e: String| KnowledgeError::Unavailable(e);
    tokio::time::timeout(CALL_TIMEOUT, async {
        conn.stdin.write_all(line.as_bytes()).await.map_err(|e| unavailable(e.to_string()))?;
        conn.stdin.flush().await.map_err(|e| unavailable(e.to_string()))?;
        loop {
            let mut buf = String::new();
            let n = (&mut conn.stdout)
                .take(MAX_LINE_BYTES as u64)
                .read_line(&mut buf)
                .await
                .map_err(|e| unavailable(e.to_string()))?;
            if n == 0 {
                return Err(unavailable("MCP closed".into()));
            }
            if !buf.ends_with('\n') && n >= MAX_LINE_BYTES {
                return Err(unavailable("MCP response too large".into()));
            }
            let Ok(msg) = serde_json::from_str::<Value>(buf.trim_end()) else { continue };
            if msg["id"].as_u64() != Some(id) {
                continue; // notifications or stale responses
            }
            if msg.get("error").is_some() {
                return Err(unavailable("MCP error".into()));
            }
            return Ok(msg["result"].clone());
        }
    })
    .await
    .map_err(|_| unavailable("MCP timeout".into()))?
}

#[cfg(test)]
#[path = "vaults.test.rs"]
mod tests;
