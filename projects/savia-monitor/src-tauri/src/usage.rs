use serde::Serialize;
use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Serialize, Clone, Debug)]
pub struct DailyUsage {
    pub date: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read: u64,
    pub cache_creation: u64,
}

#[derive(Serialize, Clone, Debug)]
pub struct ModelUsage {
    pub model: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read: u64,
    pub turns: u32,
    pub cost_usd: f64,
}

#[derive(Serialize, Clone, Debug)]
pub struct ProjectUsage {
    pub project: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cost_usd: f64,
}

#[derive(Serialize, Clone, Debug)]
pub struct UsageSummary {
    pub total_sessions: u32,
    pub total_turns: u32,
    pub total_input: u64,
    pub total_output: u64,
    pub total_cache_read: u64,
    pub total_cache_creation: u64,
    pub total_cost_usd: f64,
    pub daily: Vec<DailyUsage>,
    pub by_model: Vec<ModelUsage>,
    pub by_project: Vec<ProjectUsage>,
}

struct Turn {
    date: String,
    model: String,
    input_tokens: u64,
    output_tokens: u64,
    cache_read: u64,
    cache_creation: u64,
    session_id: String,
    project: String,
}

// Anthropic API rates April 2026 (USD per million tokens)
fn cost_for_model(model: &str, input: u64, output: u64, cache_read: u64, cache_creation: u64) -> f64 {
    let (input_rate, output_rate) = if model.contains("opus") {
        (15.0, 75.0)
    } else if model.contains("sonnet") {
        (3.0, 15.0)
    } else if model.contains("haiku") {
        (1.0, 5.0)
    } else {
        (3.0, 15.0) // default to sonnet rates
    };
    let m = 1_000_000.0;
    (input as f64 * input_rate / m)
        + (output as f64 * output_rate / m)
        + (cache_read as f64 * input_rate * 0.1 / m)
        + (cache_creation as f64 * input_rate * 1.25 / m)
}

fn extract_project_name(path: &PathBuf) -> String {
    // ~/.claude/projects/{project-slug}/{session-id}.jsonl
    // Take the parent directory name as project slug
    path.parent()
        .and_then(|p| p.file_name())
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default()
}

fn scan_jsonl(path: &PathBuf, cutoff: &str) -> Vec<Turn> {
    let content = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };
    let project = extract_project_name(path);
    let mut seen: HashMap<String, Turn> = HashMap::new();

    for line in content.lines() {
        if line.is_empty() { continue; }
        let json: serde_json::Value = match serde_json::from_str(line) {
            Ok(j) => j,
            Err(_) => continue,
        };
        if json["type"].as_str() != Some("assistant") { continue; }
        let usage = &json["message"]["usage"];
        if usage.is_null() { continue; }

        let ts = json["timestamp"].as_str().unwrap_or("");
        let date = ts.get(..10).unwrap_or("");
        if !cutoff.is_empty() && date < cutoff { continue; }

        let msg_id = json["message"]["id"].as_str().unwrap_or("")
            .to_string();
        let session_id = json["sessionId"].as_str().unwrap_or("")
            .to_string();

        let turn = Turn {
            date: date.to_string(),
            model: json["message"]["model"].as_str().unwrap_or("unknown").to_string(),
            input_tokens: usage["input_tokens"].as_u64().unwrap_or(0),
            output_tokens: usage["output_tokens"].as_u64().unwrap_or(0),
            cache_read: usage["cache_read_input_tokens"].as_u64().unwrap_or(0),
            cache_creation: usage["cache_creation_input_tokens"].as_u64().unwrap_or(0),
            session_id,
            project: project.clone(),
        };
        // Keep last occurrence per message_id (final tally)
        let key = if msg_id.is_empty() { format!("{}_{}", ts, turn.model) } else { msg_id };
        seen.insert(key, turn);
    }

    seen.into_values().collect()
}

fn scan_dir_recursive(dir: &PathBuf, cutoff: &str) -> Vec<Turn> {
    let mut turns = Vec::new();
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return turns,
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            turns.extend(scan_dir_recursive(&path, cutoff));
        } else if path.extension().map_or(false, |e| e == "jsonl") {
            turns.extend(scan_jsonl(&path, cutoff));
        }
    }
    turns
}

#[tauri::command]
pub fn get_usage_summary(days: Option<u32>) -> UsageSummary {
    let home = crate::config::home_dir();
    let projects_dir = home.join(".claude").join("projects");

    let cutoff = days.map(|d| {
        let now = chrono::Utc::now();
        let past = now - chrono::Duration::days(d as i64);
        past.format("%Y-%m-%d").to_string()
    }).unwrap_or_default();

    let turns = scan_dir_recursive(&projects_dir, &cutoff);

    // Aggregate by day
    let mut daily_map: HashMap<String, (u64, u64, u64, u64)> = HashMap::new();
    for t in &turns {
        let e = daily_map.entry(t.date.clone()).or_default();
        e.0 += t.input_tokens; e.1 += t.output_tokens;
        e.2 += t.cache_read; e.3 += t.cache_creation;
    }
    let mut daily: Vec<DailyUsage> = daily_map.into_iter().map(|(date, (i, o, cr, cc))| {
        DailyUsage { date, input_tokens: i, output_tokens: o, cache_read: cr, cache_creation: cc }
    }).collect();
    daily.sort_by(|a, b| a.date.cmp(&b.date));

    // Aggregate by model
    let mut model_map: HashMap<String, (u64, u64, u64, u32)> = HashMap::new();
    for t in &turns {
        let e = model_map.entry(t.model.clone()).or_default();
        e.0 += t.input_tokens; e.1 += t.output_tokens;
        e.2 += t.cache_read; e.3 += 1;
    }
    let by_model: Vec<ModelUsage> = model_map.into_iter().map(|(model, (i, o, cr, turns))| {
        let cost = cost_for_model(&model, i, o, cr, 0);
        ModelUsage { model, input_tokens: i, output_tokens: o, cache_read: cr, turns, cost_usd: cost }
    }).collect();

    // Aggregate by project
    let mut proj_map: HashMap<String, (u64, u64, String)> = HashMap::new();
    for t in &turns {
        let e = proj_map.entry(t.project.clone()).or_insert((0, 0, t.model.clone()));
        e.0 += t.input_tokens; e.1 += t.output_tokens;
    }
    let mut by_project: Vec<ProjectUsage> = proj_map.into_iter().map(|(project, (i, o, model))| {
        let cost = cost_for_model(&model, i, o, 0, 0);
        ProjectUsage { project, input_tokens: i, output_tokens: o, cost_usd: cost }
    }).collect();
    by_project.sort_by(|a, b| b.cost_usd.partial_cmp(&a.cost_usd).unwrap_or(std::cmp::Ordering::Equal));
    by_project.truncate(10);

    // Totals
    let mut sessions: std::collections::HashSet<String> = std::collections::HashSet::new();
    let (mut ti, mut to, mut tcr, mut tcc) = (0u64, 0u64, 0u64, 0u64);
    for t in &turns {
        sessions.insert(t.session_id.clone());
        ti += t.input_tokens; to += t.output_tokens;
        tcr += t.cache_read; tcc += t.cache_creation;
    }
    let total_cost: f64 = by_model.iter().map(|m| m.cost_usd).sum();

    UsageSummary {
        total_sessions: sessions.len() as u32,
        total_turns: turns.len() as u32,
        total_input: ti,
        total_output: to,
        total_cache_read: tcr,
        total_cache_creation: tcc,
        total_cost_usd: total_cost,
        daily,
        by_model,
        by_project,
    }
}
