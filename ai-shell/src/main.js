import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

// ── DOM refs ──────────────────────────────────────────────────────────────
const messagesEl  = document.getElementById("messages");
const inputEl     = document.getElementById("user-input");
const sendBtn     = document.getElementById("send-btn");
const ollamaDot   = document.getElementById("ollama-dot");
const modelNameEl = document.getElementById("model-name");
const hostnameEl  = document.getElementById("status-hostname");
const timeEl      = document.getElementById("status-time");
const wsPanel     = document.getElementById("workspace-panel");
const wsSearch    = document.getElementById("ws-search");
const wsResults   = document.getElementById("ws-results");

// ── State ─────────────────────────────────────────────────────────────────
let isStreaming = false;

// ── Boot ──────────────────────────────────────────────────────────────────
(async () => {
  updateClock();
  setInterval(updateClock, 1000);
  await pollStatus();
  setInterval(pollStatus, 10_000);
})();

async function pollStatus() {
  try {
    const s = await invoke("get_status");
    hostnameEl.textContent = s.hostname;
    modelNameEl.textContent = s.model;
    ollamaDot.className = "dot " + (s.ollama_online ? "online" : "offline");
  } catch {
    ollamaDot.className = "dot offline";
  }
}

function updateClock() {
  timeEl.textContent = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

// ── Input handling ────────────────────────────────────────────────────────
inputEl.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    submit();
  }
  // Auto-grow textarea
  setTimeout(() => {
    inputEl.style.height = "auto";
    inputEl.style.height = Math.min(inputEl.scrollHeight, 120) + "px";
  });
});

sendBtn.addEventListener("click", submit);

// Workspace toggle
document.addEventListener("keydown", (e) => {
  if (e.ctrlKey && e.code === "Space") {
    wsPanel.classList.toggle("hidden");
    if (!wsPanel.classList.contains("hidden")) wsSearch.focus();
  }
  if (e.key === "Escape") wsPanel.classList.add("hidden");
});

wsSearch.addEventListener("input", debounce(searchWorkspace, 300));

// ── Submit ────────────────────────────────────────────────────────────────
async function submit() {
  const text = inputEl.value.trim();
  if (!text || isStreaming) return;

  inputEl.value = "";
  inputEl.style.height = "auto";

  appendMessage("user", text);

  const aiEl = appendMessage("ai", "");
  const pEl  = aiEl.querySelector("p");
  pEl.classList.add("cursor-blink");

  isStreaming  = true;
  let fullText = "";

  try {
    // Streaming token listener
    const unlisten = await listen("ai-token", (event) => {
      fullText += event.payload;
      pEl.textContent = fullText;
      scrollToBottom();
    });

    await invoke("chat_stream", { prompt: text });
    unlisten();
  } catch (err) {
    pEl.textContent = `Error: ${err}`;
  } finally {
    pEl.classList.remove("cursor-blink");
    isStreaming = false;

    // Check if response is an action JSON and show badge
    const action = tryParseAction(fullText.trim());
    if (action) renderActionBadge(aiEl, action);
  }

  scrollToBottom();
}

// ── Message rendering ─────────────────────────────────────────────────────
function appendMessage(role, text) {
  const div = document.createElement("div");
  div.className = `message ${role}`;

  const label = document.createElement("span");
  label.className = "role-label";
  label.textContent = role.toUpperCase();

  const p = document.createElement("p");
  p.textContent = text;

  div.appendChild(label);
  div.appendChild(p);
  messagesEl.appendChild(div);
  scrollToBottom();
  return div;
}

function renderActionBadge(container, action) {
  const badge = document.createElement("span");
  badge.className = "action-badge";
  badge.textContent = `⚡ ${action.action}`;
  container.appendChild(badge);
}

function tryParseAction(text) {
  try {
    const obj = JSON.parse(text);
    if (obj && obj.action) return obj;
  } catch {}
  return null;
}

function scrollToBottom() {
  const view = document.getElementById("chat-view");
  view.scrollTop = view.scrollHeight;
}

// ── Workspace search ──────────────────────────────────────────────────────
async function searchWorkspace() {
  const q = wsSearch.value.trim();
  if (!q) { wsResults.innerHTML = ""; return; }

  try {
    const results = await invoke("semantic_search", { query: q });
    wsResults.innerHTML = "";
    if (!results.length) {
      wsResults.innerHTML = '<li style="color:var(--text-muted)">No results</li>';
      return;
    }
    for (const r of results) {
      const li = document.createElement("li");
      li.innerHTML = `<strong>${escHtml(r.path)}</strong>${escHtml(r.snippet)}`;
      li.addEventListener("click", () => openWorkspaceFile(r.path));
      wsResults.appendChild(li);
    }
  } catch {}
}

async function openWorkspaceFile(path) {
  try {
    const content = await invoke("open_context", { path });
    appendMessage("system", `📄 ${path}\n\n${content}`);
    wsPanel.classList.add("hidden");
    scrollToBottom();
  } catch (e) {
    appendMessage("system", `Could not open ${path}: ${e}`);
  }
}

// ── Utils ─────────────────────────────────────────────────────────────────
function debounce(fn, ms) {
  let t;
  return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
}

function escHtml(str) {
  return str.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
}
