use std::fs;
use std::path::PathBuf;

pub fn workspace_dir() -> PathBuf {
    std::env::var("CLAUDE_PROJECT_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::current_dir().unwrap_or_else(|_| PathBuf::from(".")))
}

pub fn home_dir() -> PathBuf {
    // Cross-platform: HOME on Linux/macOS, USERPROFILE on Windows
    std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
}

#[tauri::command]
pub fn get_shield_enabled() -> bool {
    std::env::var("SAVIA_SHIELD_ENABLED")
        .map(|v| v != "false")
        .unwrap_or(true)
}

#[tauri::command]
pub fn set_shield_enabled(enabled: bool) -> Result<(), String> {
    unsafe {
        std::env::set_var(
            "SAVIA_SHIELD_ENABLED",
            if enabled { "true" } else { "false" },
        );
    }
    Ok(())
}

#[tauri::command]
pub fn get_hook_profile() -> String {
    let profile_path = home_dir().join(".savia").join("hook-profile");
    fs::read_to_string(&profile_path)
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "standard".to_string())
}

#[tauri::command]
pub fn set_hook_profile(profile: String) -> Result<(), String> {
    let valid = ["minimal", "standard", "strict", "ci"];
    if !valid.contains(&profile.as_str()) {
        return Err(format!(
            "Invalid profile: {}. Valid: {:?}",
            profile, valid
        ));
    }
    let profile_path = home_dir().join(".savia").join("hook-profile");
    if let Some(parent) = profile_path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    fs::write(&profile_path, &profile).map_err(|e| e.to_string())
}
