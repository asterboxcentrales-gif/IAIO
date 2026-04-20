#!/usr/bin/env python3
"""AI-OS Shell v0.1 — terminal interface to Ollama (runs inside Cage/foot)."""
import json, os, sys, textwrap, urllib.request, urllib.error, readline

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")
MODEL       = os.getenv("AI_OS_MODEL", "llama3.2:3b")
WIDTH       = os.get_terminal_size().columns if sys.stdout.isatty() else 80

SYSTEM = (
    "You are the AI kernel of AI-OS. You replace the traditional desktop shell. "
    "Answer naturally. When the user asks for a system action (shutdown, reboot, "
    "list files, etc.), respond ONLY with JSON: "
    '{"action":"<name>","args":{}} — no prose.'
)

CYAN   = "\033[96m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
DIM    = "\033[2m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def banner():
    print(f"\n{BOLD}{CYAN}  ╔══════════════════════════════════╗")
    print(f"  ║         AI-OS  v0.1            ║")
    print(f"  ╚══════════════════════════════════╝{RESET}\n")
    print(f"{DIM}  Model : {MODEL}")
    print(f"  Engine: {OLLAMA_HOST}")
    print(f"  Ctrl+C to exit{RESET}\n")

def ollama_stream(prompt: str):
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "system": SYSTEM,
        "stream": True,
    }).encode()

    req = urllib.request.Request(
        f"{OLLAMA_HOST}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        for line in resp:
            chunk = json.loads(line.decode())
            yield chunk.get("response", "")
            if chunk.get("done"):
                break

def try_action(text: str) -> bool:
    """Execute OS actions returned as JSON by the model."""
    try:
        obj = json.loads(text.strip())
        action = obj.get("action", "")
        if action == "shutdown":
            print(f"\n{YELLOW}⚡ Shutting down…{RESET}")
            os.system("systemctl poweroff")
        elif action == "reboot":
            print(f"\n{YELLOW}⚡ Rebooting…{RESET}")
            os.system("systemctl reboot")
        elif action == "run_command":
            cmd = obj.get("args", {}).get("cmd", "")
            if cmd:
                print(f"\n{DIM}$ {cmd}{RESET}")
                os.system(cmd)
        else:
            return False
        return True
    except (json.JSONDecodeError, AttributeError):
        return False

def chat(history: list[dict], user_msg: str) -> str:
    history.append({"role": "user", "content": user_msg})

    print(f"\n{CYAN}  AI ▸{RESET} ", end="", flush=True)
    full = ""
    col  = 0
    try:
        for token in ollama_stream(user_msg):
            print(token, end="", flush=True)
            full += token
            col  += len(token)
            if col >= WIDTH - 8:
                print(f"\n{' '*7}", end="", flush=True)
                col = 0
    except urllib.error.URLError:
        print(f"{YELLOW}[Ollama not reachable — is the service running?]{RESET}")
    print("\n")

    history.append({"role": "assistant", "content": full})
    try_action(full)
    return full

def main():
    banner()
    history = []
    while True:
        try:
            user = input(f"{GREEN}  you ▸{RESET} ").strip()
            if not user:
                continue
            chat(history, user)
        except KeyboardInterrupt:
            print(f"\n\n{DIM}  Goodbye.{RESET}\n")
            sys.exit(0)
        except EOFError:
            sys.exit(0)

if __name__ == "__main__":
    main()
