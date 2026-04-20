#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod ollama;
mod workspace;

use tauri::Manager;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let win = app.get_webview_window("main").unwrap();

            // Kiosk mode: full-screen, no title bar, no decorations
            win.set_fullscreen(true)?;
            win.set_decorations(false)?;
            win.set_resizable(false)?;
            win.set_always_on_top(true)?;

            // Prevent accidental close (Alt+F4 etc.)
            win.on_window_event(|event| {
                if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                    api.prevent_close();
                }
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::chat,
            commands::chat_stream,
            commands::run_system,
            commands::list_models,
            commands::get_status,
            workspace::semantic_search,
            workspace::open_context,
        ])
        .run(tauri::generate_context!())
        .expect("AI-OS Shell failed to start");
}
