use serde::Serialize;
use std::path::PathBuf;
use std::process::Command;

#[derive(Serialize, Clone)]
pub struct BranchInfo {
    pub name: String,
    pub current: bool,
    pub remote: bool,
    pub merged: bool,
    pub group: String,
    pub pending_files: i32,
}

#[derive(Serialize, Clone)]
pub struct GitProject {
    pub name: String,
    pub path: String,
    pub branch: String,
    pub has_changes: bool,
}

fn workspace_dir() -> PathBuf {
    std::env::var("CLAUDE_PROJECT_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::current_dir().unwrap_or_else(|_| PathBuf::from(".")))
}

fn classify_group(name: &str) -> String {
    let clean = name
        .trim_start_matches("remotes/origin/")
        .trim_start_matches("remotes/");
    if clean.starts_with("feat/") || clean.starts_with("feature/") {
        "feat".into()
    } else if clean.starts_with("fix/") {
        "fix".into()
    } else if clean.starts_with("agent/") || clean.starts_with("claude/") {
        "agent".into()
    } else if clean.starts_with("nido/") {
        "nido".into()
    } else if clean == "main" || clean == "master" || clean == "develop" {
        "main".into()
    } else {
        "other".into()
    }
}

fn git_cmd(args: &[&str], dir: &PathBuf) -> String {
    Command::new("git")
        .args(args)
        .current_dir(dir)
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default()
}

pub fn git_cmd_ws(args: &[&str]) -> String {
    git_cmd(args, &workspace_dir())
}

pub fn git_cmd_in(args: &[&str], dir: &PathBuf) -> String {
    git_cmd(args, dir)
}

#[tauri::command]
pub fn get_branches(project_path: Option<String>) -> Vec<BranchInfo> {
    let dir = project_path.map(PathBuf::from).unwrap_or_else(workspace_dir);
    let all = git_cmd(&["branch", "-a", "--no-color"], &dir);
    let merged_raw = git_cmd(&["branch", "--merged", "main", "--no-color"], &dir);
    let merged: Vec<&str> = merged_raw.lines().map(|l| l.trim().trim_start_matches("* ")).collect();

    all.lines()
        .filter(|l| !l.contains("HEAD"))
        .map(|line| {
            let current = line.starts_with('*');
            let name = line.trim().trim_start_matches("* ").to_string();
            let remote = name.starts_with("remotes/");
            let clean_name = name
                .trim_start_matches("remotes/origin/")
                .trim_start_matches("remotes/");
            let is_merged = merged.iter().any(|m| *m == clean_name) && clean_name != "main";
            // Count files differing from main (only for local non-main branches)
            let pending = if !remote && clean_name != "main" && clean_name != "master" {
                let diff = git_cmd(&["diff", "--name-only", &format!("main...{}", clean_name)], &dir);
                diff.lines().filter(|l| !l.is_empty()).count() as i32
            } else {
                0
            };
            BranchInfo {
                group: classify_group(&name),
                name,
                current,
                remote,
                merged: is_merged,
                pending_files: pending,
            }
        })
        .collect()
}

#[tauri::command]
pub fn get_nidos() -> String {
    let home = crate::config::home_dir();
    let registry = home.join(".savia").join("nidos").join(".registry");
    std::fs::read_to_string(registry).unwrap_or_default()
}

#[tauri::command]
pub fn get_git_projects() -> Vec<GitProject> {
    let ws = workspace_dir();
    let projects_dir = ws.join("projects");
    let mut result = Vec::new();

    // Add the workspace root itself
    if ws.join(".git").exists() {
        let branch = git_cmd(&["branch", "--show-current"], &ws).trim().to_string();
        let status = git_cmd(&["status", "--porcelain"], &ws);
        result.push(GitProject {
            name: "savia (workspace)".into(),
            path: ws.to_string_lossy().to_string(),
            branch,
            has_changes: !status.trim().is_empty(),
        });
    }

    // Scan projects/ for git repos
    if let Ok(entries) = std::fs::read_dir(&projects_dir) {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_dir() && p.join(".git").exists() {
                let name = p.file_name().unwrap_or_default().to_string_lossy().to_string();
                let branch = git_cmd(&["branch", "--show-current"], &p).trim().to_string();
                let status = git_cmd(&["status", "--porcelain"], &p);
                result.push(GitProject {
                    name,
                    path: p.to_string_lossy().to_string(),
                    branch,
                    has_changes: !status.trim().is_empty(),
                });
            }
        }
    }
    result
}

#[tauri::command]
pub fn delete_branch(branch: String, project_path: Option<String>) -> Result<String, String> {
    // Validate branch name — no path traversal, no special chars
    if branch.contains("..") || branch.contains(' ') || branch.starts_with('-') {
        return Err(format!("Invalid branch name: {}", branch));
    }
    let dir = project_path.map(PathBuf::from).unwrap_or_else(workspace_dir);
    let output = Command::new("git")
        .args(["branch", "-d", &branch])
        .current_dir(&dir)
        .output()
        .map_err(|e| e.to_string())?;
    if output.status.success() {
        Ok(format!("Deleted branch {}", branch))
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}
