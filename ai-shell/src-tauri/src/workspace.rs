//! Semantic workspace — replaces the traditional file manager.
//! Files are indexed by their semantic meaning, not their path.
//! For Alpha: simple text search over ~/.workspace/. Embeddings in v0.2.

use serde::{Deserialize, Serialize};
use std::{fs, path::PathBuf};

#[derive(Serialize)]
pub struct SemanticResult {
    pub path:    String,
    pub snippet: String,
    pub score:   f32,
}

#[derive(Deserialize)]
pub struct OpenContext {
    pub path: String,
}

fn workspace_root() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("/home/ai"))
        .join(".workspace")
}

/// Keyword search over the semantic workspace (alpha stub).
/// v0.2 will replace this with a local embedding model (all-MiniLM via GGUF).
#[tauri::command]
pub async fn semantic_search(query: String) -> Result<Vec<SemanticResult>, String> {
    let root = workspace_root();
    if !root.exists() {
        fs::create_dir_all(&root).map_err(|e| e.to_string())?;
        return Ok(vec![]);
    }

    let q_lower = query.to_lowercase();
    let mut results = Vec::new();

    search_dir(&root, &q_lower, &root, &mut results);
    results.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());
    Ok(results.into_iter().take(10).collect())
}

fn search_dir(
    dir:     &PathBuf,
    query:   &str,
    root:    &PathBuf,
    results: &mut Vec<SemanticResult>,
) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            search_dir(&path, query, root, results);
        } else if path.is_file() {
            if let Ok(content) = fs::read_to_string(&path) {
                let lower = content.to_lowercase();
                if lower.contains(query) {
                    let snippet = extract_snippet(&content, query);
                    // Naïve score: occurrences / content length
                    let score = lower.matches(query).count() as f32 / content.len() as f32;
                    let rel = path.strip_prefix(root).unwrap_or(&path);
                    results.push(SemanticResult {
                        path:    rel.to_string_lossy().into_owned(),
                        snippet,
                        score,
                    });
                }
            }
        }
    }
}

fn extract_snippet(content: &str, query: &str) -> String {
    let lower = content.to_lowercase();
    let pos   = lower.find(query).unwrap_or(0);
    let start = pos.saturating_sub(80);
    let end   = (pos + 160).min(content.len());
    format!("…{}…", &content[start..end].trim())
}

/// Open a file from the workspace and return its content.
#[tauri::command]
pub async fn open_context(path: String) -> Result<String, String> {
    let full = workspace_root().join(&path);
    fs::read_to_string(&full).map_err(|e| e.to_string())
}
