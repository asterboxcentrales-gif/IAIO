{ config, pkgs, lib, ... }:

# Wayland compositor module — uses Cage (single-app kiosk compositor)
# Cage wraps one application full-screen with no window chrome.
{
  # Enable the Wayland session infrastructure
  programs.xwayland.enable = false;   # no X11 compatibility layer

  # Required by wlroots-based compositors
  security.polkit.enable   = true;
  security.pam.services.login.enableGnomeKeyring = false;

  environment.sessionVariables = {
    WAYLAND_DISPLAY  = "wayland-1";
    MOZ_ENABLE_WAYLAND = "1";
    # Force WebKitGTK to use the Wayland backend
    GDK_BACKEND      = "wayland";
    QT_QPA_PLATFORM  = "wayland";
    CLUTTER_BACKEND  = "wayland";
  };

  # cage is started by the ai-shell systemd user service (see ai-shell.nix)
  environment.systemPackages = with pkgs; [ cage ];
}
