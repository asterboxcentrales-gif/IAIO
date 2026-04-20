#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# AI-OS :: Dev environment for the ai-shell Tauri app (no NixOS required)
# Requires: Rust, Node.js, Tauri CLI, Ollama running locally
# Usage: ./scripts/dev-shell.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT/ai-shell"

# Check Ollama
if ! curl -sf http://localhost:11434/api/tags > /dev/null; then
  echo "⚠  Ollama not running. Starting it…"
  ollama serve &
  sleep 2
fi

# Pull model if absent
if ! curl -sf http://localhost:11434/api/tags | grep -q "llama3.2"; then
  echo "→ Pulling llama3.2:3b (first time only)…"
  ollama pull llama3.2:3b
fi

echo "→ Starting AI Shell in dev mode…"
npm install --silent
npm run dev
