{ lib, pkgs, rustPlatform, webkitgtk_4_1, openssl, glib, gtk3, ... }:

rustPlatform.buildRustPackage {
  pname   = "ai-shell";
  version = "0.1.0";

  src = ./.;

  cargoLock.lockFile = ./src-tauri/Cargo.lock;

  nativeBuildInputs = with pkgs; [
    pkg-config
    wrapGAppsHook
    nodejs
    nodePackages.npm
    cargo-tauri
  ];

  buildInputs = with pkgs; [
    webkitgtk_4_1
    openssl
    glib
    gtk3
    libayatana-appindicator
  ];

  buildPhase = ''
    cd src-tauri
    cargo tauri build --bundles none
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp target/release/ai-shell $out/bin/ai-shell
  '';

  meta = {
    description = "AI-OS Shell — full-screen AI kiosk compositor frontend";
    license     = lib.licenses.mit;
    platforms   = lib.platforms.linux;
  };
}
