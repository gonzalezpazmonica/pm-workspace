use std::fs;
use std::path::PathBuf;

pub fn workspace_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("CLAUDE_PROJECT_DIR") {
        return PathBuf::from(dir);
    }
    // Walk up from CWD
    if let Ok(cwd) = std::env::current_dir() {
        let mut dir = cwd.as_path();
        loop {
            if dir.join(".claude").is_dir() { return dir.to_path_buf(); }
            match dir.parent() { Some(p) => dir = p, None => break }
        }
    }
    // Walk up from exe location
    if let Ok(exe) = std::env::current_exe() {
        if let Some(mut dir) = exe.parent() {
            loop {
                if dir.join(".claude").is_dir() { return dir.to_path_buf(); }
                match dir.parent() { Some(p) => dir = p, None => break }
            }
        }
    }
    // Well-known paths under HOME
    let home = home_dir();
    for name in ["savia", "claude", "pm-workspace"] {
        let p = home.join(name);
        if p.join(".claude").is_dir() { return p; }
    }
    // Scan cloud-sync folders (OneDrive, Dropbox, etc.)
    if let Ok(entries) = std::fs::read_dir(&home) {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_dir() {
                for sub in ["Documentos/savia", "Documents/savia", "savia", "claude"] {
                    let c = p.join(sub);
                    if c.join(".claude").is_dir() { return c; }
                }
            }
        }
    }
    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

pub fn home_dir() -> PathBuf {
    std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
}

#[tauri::command]
pub fn get_shield_enabled() -> bool {
    std::env::var("SAVIA_SHIELD_ENABLED").map(|v| v != "false").unwrap_or(true)
}

#[tauri::command]
pub fn set_shield_enabled(enabled: bool) -> Result<(), String> {
    unsafe { std::env::set_var("SAVIA_SHIELD_ENABLED", if enabled { "true" } else { "false" }); }
    Ok(())
}

#[tauri::command]
pub fn get_hook_profile() -> String {
    let p = home_dir().join(".savia").join("hook-profile");
    fs::read_to_string(&p).map(|s| s.trim().to_string()).unwrap_or_else(|_| "standard".to_string())
}

#[tauri::command]
pub fn set_hook_profile(profile: String) -> Result<(), String> {
    let valid = ["minimal", "standard", "strict", "ci"];
    if !valid.contains(&profile.as_str()) { return Err(format!("Invalid profile: {}", profile)); }
    let p = home_dir().join(".savia").join("hook-profile");
    if let Some(parent) = p.parent() { let _ = fs::create_dir_all(parent); }
    fs::write(&p, &profile).map_err(|e| e.to_string())
}
