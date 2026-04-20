#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# AI-OS :: ISO Builder
# Requires: Nix with flakes enabled, running on Linux (or NixOS)
# Usage:
#   ./scripts/build-iso.sh          → build ISO
#   ./scripts/build-iso.sh --vm     → build QEMU VM image (fast dev loop)
#   ./scripts/build-iso.sh --flash  → build ISO + flash to /dev/sdX
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TARGET="${1:-}"

# ── Sanity checks ─────────────────────────────────────────────────────────
if ! command -v nix &>/dev/null; then
  echo "ERROR: Nix is not installed. Install from https://nixos.org/download"
  exit 1
fi

if ! nix --version 2>&1 | grep -q "nix"; then
  echo "ERROR: Cannot run nix command"
  exit 1
fi

# Enable flakes if not already set
NIX_FLAGS="--extra-experimental-features 'nix-command flakes'"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║           AI-OS Build System v0.1           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Build ─────────────────────────────────────────────────────────────────
if [[ "$TARGET" == "--vm" ]]; then
  echo "→ Building QEMU VM image (fast dev mode)…"
  nix build .#vm $NIX_FLAGS

  echo ""
  echo "✓ VM built. Launch with:"
  echo "  ./result/bin/run-ai-os-vm"
  echo ""
  echo "  (QEMU will open a window with the AI shell)"

elif [[ "$TARGET" == "--flash" ]]; then
  echo "→ Building ISO…"
  nix build .#iso $NIX_FLAGS

  ISO_PATH=$(readlink -f result/iso/*.iso)
  echo "✓ ISO ready: $ISO_PATH"
  echo ""
  echo "Available drives:"
  lsblk -d -o NAME,SIZE,MODEL | grep -v "loop"
  echo ""
  read -rp "Flash to which device? (e.g. /dev/sdb) ⚠ ALL DATA WILL BE ERASED: " DEVICE

  if [[ ! -b "$DEVICE" ]]; then
    echo "ERROR: $DEVICE is not a block device."
    exit 1
  fi

  echo "Flashing $ISO_PATH → $DEVICE …"
  sudo dd if="$ISO_PATH" of="$DEVICE" bs=4M status=progress oflag=sync
  sudo sync
  echo "✓ Done. Safely remove the device."

else
  echo "→ Building ISO…"
  nix build .#iso $NIX_FLAGS --show-trace 2>&1 | tee build.log

  ISO_PATH=$(readlink -f result/iso/*.iso 2>/dev/null || echo "")
  if [[ -z "$ISO_PATH" ]]; then
    echo "ERROR: Build succeeded but ISO not found. Check build.log"
    exit 1
  fi

  SIZE=$(du -h "$ISO_PATH" | cut -f1)
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  ✓ ISO ready                                ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  echo "  Path : $ISO_PATH"
  echo "  Size : $SIZE"
  echo ""
  echo "  Flash: sudo dd if=$ISO_PATH of=/dev/sdX bs=4M status=progress"
  echo "  VM:    ./scripts/build-iso.sh --vm"
fi
