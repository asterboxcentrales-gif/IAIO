{ config, pkgs, lib, ... }:

# AI Engine module — runs Ollama as a system service.
# The shell communicates with it via HTTP on localhost:11434.
{
  # Ollama is available in nixpkgs >= 24.05
  services.ollama = {
    enable      = true;
    # Bind only to loopback — never expose inference to the network
    host        = "127.0.0.1";
    port        = 11434;
    # Use GPU acceleration when available; falls back to CPU automatically
    acceleration = "auto";
    # Models are stored in persistent state (survives reboots)
    home        = "/var/lib/ollama";
  };

  # Pull the default model on first boot.
  # llama3.2:3b — 2GB, runs on 8GB RAM, good reasoning for system commands.
  # Swap to llama3.2:1b for < 4GB RAM devices.
  systemd.services.ollama-pull-model = {
    description   = "Pull default AI model on first boot";
    after         = [ "ollama.service" "network-online.target" ];
    wants         = [ "network-online.target" ];
    wantedBy      = [ "multi-user.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      # Only pull if the model directory doesn't already exist
      ExecStart = pkgs.writeShellScript "pull-model" ''
        MODEL_DIR="/var/lib/ollama/models/manifests/registry.ollama.ai/library/llama3.2"
        if [ ! -d "$MODEL_DIR" ]; then
          echo "[AI-OS] Pulling llama3.2:3b — this only happens once..."
          ${pkgs.curl}/bin/curl -s -X POST http://127.0.0.1:11434/api/pull \
            -H 'Content-Type: application/json' \
            -d '{"name":"llama3.2:3b","stream":false}'
        fi
      '';
    };
  };

  # Ensure Ollama socket is ready before the shell starts
  systemd.services.ollama.serviceConfig = {
    Restart      = "on-failure";
    RestartSec   = "3s";
  };
}
