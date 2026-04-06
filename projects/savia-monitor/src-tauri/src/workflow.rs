use serde::Serialize;
use std::path::PathBuf;

#[derive(Serialize, Clone, Debug)]
pub struct HealthScore {
    pub total: u32,
    pub shield_score: u32,
    pub git_score: u32,
    pub agent_score: u32,
    pub profile_score: u32,
    pub breakdown: Vec<String>,
}

fn home_dir() -> PathBuf {
    crate::config::home_dir()
}

fn workspace_dir() -> PathBuf {
    std::env::var("CLAUDE_PROJECT_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::current_dir().unwrap_or_default())
}

#[tauri::command]
pub fn get_health_score() -> HealthScore {
    let mut breakdown = Vec::new();
    let mut shield_score: u32 = 0;
    let mut git_score: u32 = 0;
    let mut agent_score: u32 = 0;
    let mut profile_score: u32 = 0;

    // Shield layers (35 pts max)
    let health = crate::shield::poll_shield_health();
    let layers_up: u32 = [health.daemon_up, health.ner_available, health.ollama_up, health.proxy_up, true, true, true, true]
        .iter().filter(|&&x| x).count() as u32;
    shield_score = (layers_up * 35) / 8;
    breakdown.push(format!("Shield: {}/8 layers = {}pts", layers_up, shield_score));

    // Git cleanliness (25 pts max)
    let status = crate::git::git_cmd_ws(&["status", "--porcelain"]);
    let dirty_files = status.lines().filter(|l| !l.trim().is_empty()).count();
    if dirty_files == 0 {
        git_score = 25;
        breakdown.push("Git: clean = 25pts".into());
    } else {
        git_score = 25u32.saturating_sub((dirty_files as u32).min(25));
        breakdown.push(format!("Git: {} uncommitted files = {}pts", dirty_files, git_score));
    }

    // Agent success rate (25 pts max)
    let lifecycle = workspace_dir().join("output").join("agent-lifecycle").join("lifecycle.jsonl");
    if let Ok(content) = std::fs::read_to_string(&lifecycle) {
        let last_10: Vec<&str> = content.lines().rev().take(20).collect();
        let stops = last_10.iter().filter(|l| l.contains("\"stop\"")).count();
        let starts = last_10.iter().filter(|l| l.contains("\"start\"")).count();
        if starts > 0 {
            let rate = (stops * 100) / starts.max(1);
            agent_score = ((rate as u32) * 25) / 100;
            breakdown.push(format!("Agents: {}% completion = {}pts", rate, agent_score));
        } else {
            agent_score = 25; // no agents = no failures
            breakdown.push("Agents: no recent activity = 25pts".into());
        }
    } else {
        agent_score = 25;
        breakdown.push("Agents: no lifecycle log = 25pts".into());
    }

    // Hook profile level (15 pts max)
    let profile = crate::config::get_hook_profile();
    profile_score = match profile.as_str() {
        "strict" => 15,
        "standard" => 12,
        "ci" => 10,
        "minimal" => 5,
        _ => 8,
    };
    breakdown.push(format!("Profile: {} = {}pts", profile, profile_score));

    HealthScore {
        total: shield_score + git_score + agent_score + profile_score,
        shield_score,
        git_score,
        agent_score,
        profile_score,
        breakdown,
    }
}

#[tauri::command]
pub fn get_current_task() -> String {
    // Try work-queue.json
    let wq = home_dir().join(".savia").join("work-queue.json");
    if let Ok(content) = std::fs::read_to_string(&wq) {
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
            if let Some(task) = json["current_task"].as_str() {
                if !task.is_empty() { return task.to_string(); }
            }
        }
    }

    // Try detecting from live.log last entry
    let log = home_dir().join(".savia").join("live.log");
    if let Ok(content) = std::fs::read_to_string(&log) {
        if let Some(last) = content.lines().rev().find(|l| !l.trim().is_empty()) {
            return last.trim().to_string();
        }
    }

    String::new()
}
