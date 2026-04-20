{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/wayland.nix
    ./modules/ai-engine.nix
    ./modules/ai-shell.nix
  ];

  # ── Boot ─────────────────────────────────────────────────────────────────
  boot = {
    loader.grub = {
      enable  = true;
      device  = "nodev";
      efiSupport = true;
    };
    loader.efi.canTouchEfiVariables = true;

    # Stripped-down kernel — only what we need for display + network + NVMe
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules  = [ "virtio_gpu" "i915" "amdgpu" "nouveau" ];

    # Silent boot: remove TTY splash, go straight to compositor
    kernelParams = [
      "quiet" "rd.systemd.show_status=false"
      "rd.udev.log_level=3"  "vt.global_cursor_default=0"
    ];
    initrd.verbose = false;
    consoleLogLevel = 0;
  };

  # ── System ───────────────────────────────────────────────────────────────
  system.stateVersion = "24.11";

  networking = {
    hostName        = "ai-os";
    networkmanager.enable = true;
    firewall.enable = true;
    # Expose Ollama only to localhost — never to LAN
    firewall.allowedTCPPorts = [];
  };

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Users ────────────────────────────────────────────────────────────────
  users.mutableUsers = false;

  users.users.ai = {
    isNormalUser  = true;
    description   = "AI Shell User";
    # Passwordless — access is through the AI shell, not a login prompt
    hashedPassword = "";
    extraGroups    = [ "video" "audio" "networkmanager" "input" ];
    shell          = pkgs.bash;
  };

  # Auto-login: skip the TTY login prompt entirely
  services.getty.autologinUser = "ai";

  # ── Immutability ─────────────────────────────────────────────────────────
  # The entire system is read-only; only /home and /var are writable
  fileSystems."/".options = [ "ro" ];

  # ── Minimal packages (no desktop environment) ────────────────────────────
  environment.systemPackages = with pkgs; [
    # Compositor and GPU utils
    cage wlr-randr
    # Networking
    curl wget networkmanagerapplet
    # System tools
    htop ripgrep git
    # Fonts required by the AI shell WebView
    noto-fonts noto-fonts-emoji
    dejavu_fonts
  ];

  # Strip X11 entirely
  services.xserver.enable = false;
  hardware.opengl.enable  = true;

  # ── Sound (PipeWire) ─────────────────────────────────────────────────────
  security.rtkit.enable  = true;
  services.pipewire = {
    enable       = true;
    alsa.enable  = true;
    pulse.enable = true;
  };
}
