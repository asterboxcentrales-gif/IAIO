use crate::ollama;
use serde::{Deserialize, Serialize};
use std::process::Command;
use tauri::{AppHandle, Emitter};

#[derive(Serialize)]
pub struct ChatResponse {
    pub text:    String,
    pub action:  Option<ActionPayload>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ActionPayload {
    pub action: String,
    pub args:   serde_json::Value,
}

/// Single-shot chat — returns when the model finishes.
#[tauri::command]
pub async fn chat(prompt: String) -> Result<ChatResponse, String> {
    let raw = ollama::generate(&prompt).await.map_err(|e| e.to_string())?;

    // Detect if the model returned a system action JSON
    let action = serde_json::from_str::<ActionPayload>(&raw.trim()).ok();

    // Execute the action immediately if present
    if let Some(ref act) = action {
        execute_action(act).await;
    }

    Ok(ChatResponse { text: raw, action })
}

/// Streaming chat — emits 'ai-token' events to the frontend as tokens arrive.
#[tauri::command]
pub async fn chat_stream(prompt: String, app: AppHandle) -> Result<(), String> {
    let handle = app.clone();
    ollama::generate_stream(&prompt, move |token| {
        let _ = handle.emit("ai-token", token);
    })
    .await
    .map_err(|e| e.to_string())
}

/// Direct system command execution (sandboxed — only allow-listed commands).
#[tauri::command]
pub async fn run_system(command: String) -> Result<String, String> {
    let allowed = ["ls", "df", "free", "uname", "date", "uptime", "whoami"];
    let cmd = command.split_whitespace().next().unwrap_or("");

    if !allowed.contains(&cmd) {
        return Err(format!("Command '{}' is not in the allow-list", cmd));
    }

    let output = Command::new("sh")
        .arg("-c")
        .arg(&command)
        .output()
        .map_err(|e| e.to_string())?;

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

#[tauri::command]
pub async fn list_models() -> Result<Vec<String>, String> {
    ollama::list_models().await.map_err(|e| e.to_string())
}

#[derive(Serialize)]
pub struct SystemStatus {
    pub ollama_online: bool,
    pub model:         String,
    pub hostname:      String,
}

#[tauri::command]
pub async fn get_status() -> Result<SystemStatus, String> {
    let hostname = std::fs::read_to_string("/etc/hostname")
        .unwrap_or_else(|_| "ai-os".into())
        .trim()
        .to_string();

    Ok(SystemStatus {
        ollama_online: ollama::health().await,
        model:         std::env::var("AI_OS_MODEL").unwrap_or_else(|_| "llama3.2:3b".into()),
        hostname,
    })
}

async fn execute_action(act: &ActionPayload) {
    match act.action.as_str() {
        "shutdown" => {
            let _ = Command::new("systemctl").arg("poweroff").spawn();
        }
        "reboot" => {
            let _ = Command::new("systemctl").arg("reboot").spawn();
        }
        "run_command" => {
            if let Some(cmd) = act.args.get("cmd").and_then(|v| v.as_str()) {
                let _ = Command::new("sh").arg("-c").arg(cmd).spawn();
            }
        }
        _ => {}
    }
}
