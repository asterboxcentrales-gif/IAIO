{ config, pkgs, lib, ... }:

# AI Shell v0.1 — Python TUI inside foot terminal, kiosk via Cage.
# Tauri/Rust UI moves to v0.2 after Cargo.lock is generated.
let
  ai-shell-script = pkgs.writeShellScriptBin "ai-shell-launch" ''
    export OLLAMA_HOST="http://127.0.0.1:11434"
    export AI_OS_MODEL="llama3.2:3b"
    export TERM=xterm-256color

    # Wait for Ollama to be ready (max 30s)
    for i in $(seq 1 30); do
      ${pkgs.curl}/bin/curl -sf "$OLLAMA_HOST/api/tags" > /dev/null && break
      sleep 1
    done

    exec ${pkgs.python3}/bin/python3 /etc/ai-shell/ai_shell.py
  '';
in {
  # Install the Python shell script into /etc
  environment.etc."ai-shell/ai_shell.py".source =
    ../../ai-shell/ai_shell.py;

  environment.systemPackages = with pkgs; [
    ai-shell-script
    foot          # Wayland-native terminal
    python3
    curl
  ];

  # foot terminal config — minimal, dark, no chrome
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

  # systemd user service: cage → foot → ai_shell.py
  systemd.user.services.ai-shell = {
    description = "AI-OS Shell (Wayland kiosk)";
    wantedBy    = [ "graphical-session.target" ];
    after       = [ "graphical-session-pre.target" ];
    partOf      = [ "graphical-session.target" ];

    serviceConfig = {
      Type       = "simple";
      Restart    = "always";
      RestartSec = "2s";
      ExecStart  = pkgs.writeShellScript "start-aios" ''
        ${pkgs.cage}/bin/cage -s -- \
          ${pkgs.foot}/bin/foot \
            --config=/etc/ai-shell/foot.ini \
            --fullscreen \
            -- \
            ${ai-shell-script}/bin/ai-shell-launch
      '';
      Environment = [
        "WAYLAND_DISPLAY=wayland-1"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];
    };
  };

  # Auto-start graphical session on TTY1 login
  environment.extraInit = lib.mkAfter ''
    if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
      systemctl --user import-environment PATH
      exec systemctl --user start graphical-session.target
    fi
  '';
}
