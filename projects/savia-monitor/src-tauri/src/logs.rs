use serde::Serialize;
use std::path::PathBuf;

#[derive(Serialize, Clone, Debug)]
pub struct AuditEntry {
    pub ts: String,
    pub layer: u32,
    pub file: String,
    pub verdict: String,
    pub detail: String,
}

#[derive(Serialize, Clone, Debug)]
pub struct ActivityEntry {
    pub ts: String,
    pub kind: String, // tool, agent, shield, error
    pub message: String,
    pub project: String,
}

#[derive(Serialize, Clone, Debug)]
pub struct AgentEntry {
    pub ts: String,
    pub event: String,
    pub agent_type: String,
    pub id: String,
}

fn workspace_dir() -> PathBuf {
    std::env::var("CLAUDE_PROJECT_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::current_dir().unwrap_or_default())
}

fn read_jsonl_tail(path: &PathBuf, limit: usize) -> Vec<String> {
    let content = std::fs::read_to_string(path).unwrap_or_default();
    content.lines().rev().take(limit).map(|s| s.to_string()).collect()
}

#[tauri::command]
pub fn get_recent_audit(limit: Option<usize>) -> Vec<AuditEntry> {
    let path = workspace_dir().join("output").join("data-sovereignty-audit.jsonl");
    let lines = read_jsonl_tail(&path, limit.unwrap_or(20));
    lines.iter().filter_map(|line| {
        let json: serde_json::Value = serde_json::from_str(line).ok()?;
        Some(AuditEntry {
            ts: json["ts"].as_str().unwrap_or("").to_string(),
            layer: json["layer"].as_u64().unwrap_or(0) as u32,
            file: json["file"].as_str().unwrap_or("").to_string(),
            verdict: json["verdict"].as_str().unwrap_or("").to_string(),
            detail: json["detail"].as_str().unwrap_or("").to_string(),
        })
    }).collect()
}

#[tauri::command]
pub fn get_recent_activity(limit: Option<usize>) -> Vec<ActivityEntry> {
    let home = crate::config::home_dir();
    let log_path = home.join(".savia").join("live.log");
    let content = std::fs::read_to_string(&log_path).unwrap_or_default();

    content.lines().rev().take(limit.unwrap_or(30)).filter_map(|line| {
        if line.trim().is_empty() { return None; }
        let kind = if line.contains("🤖") || line.contains("Agente") { "agent" }
            else if line.contains("⚙") || line.contains("Ejecutando") { "tool" }
            else if line.contains("🔍") || line.contains("🔎") { "search" }
            else if line.contains("✏") || line.contains("📝") { "edit" }
            else if line.contains("👁") { "read" }
            else { "other" };

        // Extract timestamp [HH:MM:SS]
        let ts = line.get(1..9).unwrap_or("").to_string();

        Some(ActivityEntry {
            ts,
            kind: kind.to_string(),
            message: line.trim().to_string(),
            project: String::new(),
        })
    }).collect()
}

#[tauri::command]
pub fn get_agent_activity() -> Vec<AgentEntry> {
    let path = workspace_dir().join("output").join("agent-lifecycle").join("lifecycle.jsonl");
    let lines = read_jsonl_tail(&path, 20);
    lines.iter().filter_map(|line| {
        let json: serde_json::Value = serde_json::from_str(line).ok()?;
        Some(AgentEntry {
            ts: json["ts"].as_str().unwrap_or("").to_string(),
            event: json["event"].as_str().unwrap_or("").to_string(),
            agent_type: json["agent"].as_str().unwrap_or("").to_string(),
            id: json["id"].as_str().unwrap_or("").to_string(),
        })
    }).collect()
}
