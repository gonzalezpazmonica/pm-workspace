// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod config;
mod git;
mod logs;
mod sessions;
mod shield;
mod workflow;

use tauri::{
    menu::{MenuBuilder, MenuItemBuilder},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Emitter, Manager,
};
use tauri_plugin_autostart::MacosLauncher;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_autostart::init(
            MacosLauncher::LaunchAgent,
            None,
        ))
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_notification::init())
        .invoke_handler(tauri::generate_handler![
            shield::get_shield_health,
            config::get_shield_enabled,
            config::set_shield_enabled,
            config::get_hook_profile,
            config::set_hook_profile,
            git::get_branches,
            git::get_nidos,
            git::get_git_projects,
            git::delete_branch,
            workflow::get_current_task,
            workflow::get_health_score,
            sessions::get_active_sessions,
            logs::get_recent_audit,
            logs::get_recent_activity,
            logs::get_agent_activity,
        ])
        .setup(|app| {
            // --- Build tray menu ---
            let title_item = MenuItemBuilder::new("Savia Monitor")
                .enabled(false)
                .build(app)?;
            let shield_item = MenuItemBuilder::with_id("shield-status", "Shield: Activo")
                .enabled(false)
                .build(app)?;
            let show_item =
                MenuItemBuilder::with_id("show", "Mostrar").build(app)?;
            let hide_item =
                MenuItemBuilder::with_id("hide", "Ocultar").build(app)?;
            let quit_item =
                MenuItemBuilder::with_id("quit", "Salir").build(app)?;

            let menu = MenuBuilder::new(app)
                .item(&title_item)
                .separator()
                .item(&shield_item)
                .separator()
                .item(&show_item)
                .item(&hide_item)
                .separator()
                .item(&quit_item)
                .build()?;

            // --- Build tray icon ---
            let _tray = TrayIconBuilder::with_id("main-tray")
                .icon(app.default_window_icon().cloned().expect("app icon required"))
                .tooltip("Savia Monitor")
                .menu(&menu)
                .on_menu_event(|app, event| match event.id().as_ref() {
                    "show" => {
                        if let Some(win) = app.get_webview_window("main") {
                            let _ = win.show();
                            let _ = win.set_focus();
                        }
                    }
                    "hide" => {
                        if let Some(win) = app.get_webview_window("main") {
                            let _ = win.hide();
                        }
                    }
                    "quit" => {
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(win) = app.get_webview_window("main") {
                            let _ = win.show();
                            let _ = win.set_focus();
                        }
                    }
                })
                .build(app)?;

            // --- Background health polling thread ---
            let app_handle = app.handle().clone();
            std::thread::spawn(move || loop {
                let health = shield::poll_shield_health();
                let _ = app_handle.emit("shield-health", &health);
                std::thread::sleep(std::time::Duration::from_secs(5));
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running Savia Monitor");
}
