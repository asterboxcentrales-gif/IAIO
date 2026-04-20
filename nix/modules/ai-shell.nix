{ config, pkgs, lib, ... }:

# AI Shell v0.1 — Python TUI inside foot terminal, kiosk via services.cage.
let
  ai-launch = pkgs.writeShellScriptBin "ai-shell-launch" ''
    export OLLAMA_HOST="http://127.0.0.1:11434"
    export AI_OS_MODEL="llama3.2:3b"
    export TERM=xterm-256color

    # Wait for Ollama (max 30s)
    for i in $(seq 1 30); do
      ${pkgs.curl}/bin/curl -sf "$OLLAMA_HOST/api/tags" > /dev/null && break
      sleep 1
    done

    exec ${pkgs.foot}/bin/foot \
      --config=/etc/ai-shell/foot.ini \
      -- \
      ${pkgs.python3}/bin/python3 /etc/ai-shell/ai_shell.py
  '';
in {
  environment.etc."ai-shell/ai_shell.py".source = ../../ai-shell/ai_shell.py;

  environment.etc."ai-shell/foot.ini".text = ''
    [main]
    font=monospace:size=13
    pad=20x20

    [colors]
    background=0a0a0f
    foreground=e2e2f0
    selection-background=7c6fff
    selection-foreground=0a0a0f

    [cursor]
    color=7c6fff e2e2f0
    blink=yes

    [key-bindings]
    scrollback-up-page=none
    scrollback-down-page=none
  '';

  environment.systemPackages = with pkgs; [ foot python3 curl ai-launch ];

  # services.cage: NixOS-native kiosk service — starts cage on TTY1 as user 'ai'
  services.cage = {
    enable  = true;
    user    = "ai";
    program = "${ai-launch}/bin/ai-shell-launch";
  };
}
