use serde::Serialize;
use std::path::PathBuf;

#[derive(Serialize, Clone, Debug)]
pub struct ActiveSession {
    pub pid: u32,
    pub name: String,
    pub project_path: String,
    pub branch: String,
    pub recent_actions: Vec<String>,
    pub agent_count: u32,
    pub shield_active: bool,
    pub is_nido: bool,
    pub nido_name: String,
    pub branch_status: BranchStatus,
}

#[derive(Serialize, Clone, Debug)]
pub struct BranchStatus {
    pub unpushed_commits: u32,
    pub has_pr: bool,
    pub merged: bool,
    pub dirty_files: u32,
}

fn home_dir() -> PathBuf { crate::config::home_dir() }

fn is_pid_alive(pid: u32) -> bool {
    #[cfg(target_os = "windows")]
    {
        use std::process::Command;
        use std::os::windows::process::CommandExt;
        let mut cmd = Command::new("tasklist");
        cmd.args(["/FI", &format!("PID eq {}", pid), "/NH", "/FO", "CSV"]);
        cmd.creation_flags(0x08000000);
        cmd.output().map(|o| {
            let out = String::from_utf8_lossy(&o.stdout);
            out.contains(&pid.to_string())
        }).unwrap_or(false)
    }
    #[cfg(unix)]
    {
        // kill(pid, 0) checks process existence without sending a signal.
        // Works on macOS, Linux, and other Unix variants (no /proc dependency).
        unsafe { libc::kill(pid as libc::pid_t, 0) == 0 }
    }
}

fn get_recent_live_actions(count: usize) -> Vec<String> {
    let log = home_dir().join(".savia").join("live.log");
    let content = std::fs::read_to_string(&log).unwrap_or_default();
    content.lines().rev()
        .filter(|l| !l.trim().is_empty())
        .take(count)
        .map(|l| l.trim().to_string())
        .collect()
}

fn count_running_agents() -> u32 {
    let ws = crate::config::workspace_dir();
    let lifecycle = ws.join("output").join("agent-lifecycle").join("lifecycle.jsonl");
    let content = std::fs::read_to_string(&lifecycle).unwrap_or_default();
    let mut running = std::collections::HashSet::new();
    for line in content.lines() {
        if let Ok(j) = serde_json::from_str::<serde_json::Value>(line) {
            let id = j["id"].as_str().unwrap_or("").to_string();
            match j["event"].as_str().unwrap_or("") {
                "start" => { running.insert(id); }
                "stop" => { running.remove(&id); }
                _ => {}
            }
        }
    }
    running.len() as u32
}

fn get_branch_status(cwd: &str) -> BranchStatus {
    let dir = PathBuf::from(cwd);
    let unpushed = crate::git::git_cmd_in(&["rev-list", "--count", "@{u}..HEAD"], &dir)
        .trim().parse::<u32>().unwrap_or(0);
    let dirty = crate::git::git_cmd_in(&["status", "--porcelain"], &dir)
        .lines().filter(|l| !l.trim().is_empty()).count() as u32;
    let branch = crate::git::git_cmd_in(&["branch", "--show-current"], &dir).trim().to_string();
    let merged_raw = crate::git::git_cmd_in(&["branch", "--merged", "main"], &dir);
    let is_merged = merged_raw.lines().any(|l| l.trim().trim_start_matches("* ") == branch)
        && branch != "main";
    BranchStatus {
        unpushed_commits: unpushed,
        has_pr: false, // needs gh CLI, skip for now
        merged: is_merged,
        dirty_files: dirty,
    }
}

#[tauri::command]
pub fn get_active_sessions() -> Vec<ActiveSession> {
    let sessions_dir = home_dir().join(".claude").join("sessions");
    let mut result = Vec::new();

    let entries = match std::fs::read_dir(&sessions_dir) {
        Ok(e) => e,
        Err(_) => return result,
    };

    let shield = std::env::var("SAVIA_SHIELD_ENABLED").unwrap_or("true".into()) != "false";
    let agents = count_running_agents();
    let actions = get_recent_live_actions(3);

    // Nidos check
    let nidos_reg = home_dir().join(".savia").join("nidos").join(".registry");
    let nido_entries: Vec<(String, String)> = std::fs::read_to_string(&nidos_reg)
        .unwrap_or_default().lines()
        .filter_map(|l| l.split_once('=').map(|(n, b)| (n.to_string(), b.to_string())))
        .collect();

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().map_or(true, |e| e != "json") { continue; }

        let content = match std::fs::read_to_string(&path) {
            Ok(c) => c,
            Err(_) => continue,
        };
        let json: serde_json::Value = match serde_json::from_str(&content) {
            Ok(j) => j,
            Err(_) => continue,
        };

        let pid = json["pid"].as_u64().unwrap_or(0) as u32;
        if pid == 0 || !is_pid_alive(pid) { continue; }

        let name = json["name"].as_str().unwrap_or("").to_string();
        let cwd = json["cwd"].as_str().unwrap_or("").to_string();
        let branch = crate::git::git_cmd_in(
            &["branch", "--show-current"], &PathBuf::from(&cwd),
        ).trim().to_string();

        let is_nido = nido_entries.iter().any(|(_, b)| branch.contains(b));
        let nido_name = nido_entries.iter()
            .find(|(_, b)| branch.contains(b))
            .map(|(n, _)| n.clone())
            .unwrap_or_default();

        result.push(ActiveSession {
            pid,
            name,
            project_path: cwd.clone(),
            branch,
            recent_actions: actions.clone(),
            agent_count: agents,
            shield_active: shield,
            is_nido,
            nido_name,
            branch_status: get_branch_status(&cwd),
        });
    }

    result
}
