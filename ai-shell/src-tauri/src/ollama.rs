use anyhow::Result;
use futures_util::StreamExt;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::env;

fn base_url() -> String {
    env::var("OLLAMA_HOST").unwrap_or_else(|_| "http://127.0.0.1:11434".into())
}

fn default_model() -> String {
    env::var("AI_OS_MODEL").unwrap_or_else(|_| "llama3.2:3b".into())
}

#[derive(Serialize)]
struct GenerateRequest<'a> {
    model:  &'a str,
    prompt: &'a str,
    stream: bool,
    system: &'a str,
}

#[derive(Deserialize)]
pub struct GenerateResponse {
    pub response: String,
    pub done:     bool,
}

#[derive(Deserialize)]
pub struct ModelTag {
    pub name: String,
}

#[derive(Deserialize)]
struct TagsResponse {
    models: Vec<ModelTag>,
}

const SYSTEM_PROMPT: &str = r#"
You are the AI kernel of AI-OS, a next-generation operating system.
You replace the traditional desktop shell. You have two roles:
1. CONVERSATION: Answer questions, explain concepts, assist the user naturally.
2. SYSTEM CONTROL: When the user asks to perform an OS action, respond ONLY with a
   JSON object in this exact format — no prose, no markdown:
   {"action": "<action_name>", "args": {<key>: <value>}}

Available actions: open_file, search_files, run_command, get_status, shutdown, reboot.

Be concise. Prefer action JSON over verbose explanations when the intent is clear.
"#;

pub async fn generate(prompt: &str) -> Result<String> {
    let client = Client::new();
    let url    = format!("{}/api/generate", base_url());
    let model  = default_model();

    let resp: GenerateResponse = client
        .post(&url)
        .json(&GenerateRequest {
            model:  &model,
            prompt,
            stream: false,
            system: SYSTEM_PROMPT,
        })
        .send()
        .await?
        .json()
        .await?;

    Ok(resp.response)
}

/// Streaming variant: calls `callback` with each token chunk as it arrives.
pub async fn generate_stream(
    prompt:   &str,
    callback: impl Fn(String) + Send + 'static,
) -> Result<()> {
    let client = Client::new();
    let url    = format!("{}/api/generate", base_url());
    let model  = default_model();

    let mut stream = client
        .post(&url)
        .json(&GenerateRequest {
            model:  &model,
            prompt,
            stream: true,
            system: SYSTEM_PROMPT,
        })
        .send()
        .await?
        .bytes_stream();

    while let Some(chunk) = stream.next().await {
        let bytes = chunk?;
        if let Ok(text) = std::str::from_utf8(&bytes) {
            for line in text.lines() {
                if line.is_empty() { continue; }
                if let Ok(resp) = serde_json::from_str::<GenerateResponse>(line) {
                    callback(resp.response);
                    if resp.done { break; }
                }
            }
        }
    }
    Ok(())
}

pub async fn list_models() -> Result<Vec<String>> {
    let client = Client::new();
    let url    = format!("{}/api/tags", base_url());

    let resp: TagsResponse = client.get(&url).send().await?.json().await?;
    Ok(resp.models.into_iter().map(|m| m.name).collect())
}

pub async fn health() -> bool {
    let client = Client::new();
    let url    = format!("{}/api/tags", base_url());
    client.get(&url).send().await.map(|r| r.status().is_success()).unwrap_or(false)
}
