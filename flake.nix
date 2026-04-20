{
  description = "AI-OS: An AI-native, immutable operating system";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-generators = {
      url    = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
  let
    system = "x86_64-linux";
    pkgs   = nixpkgs.legacyPackages.${system};
  in {
    # Full NixOS configuration (for VMs / direct install)
    nixosConfigurations.ai-os = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ ./nix/configuration.nix ];
    };

    packages.${system} = {
      # ISO image — run: nix build .#iso
      iso = nixos-generators.nixosGenerate {
        inherit system;
        format  = "iso";
        modules = [ ./nix/configuration.nix ];
      };

      # QEMU VM for rapid iteration — run: nix build .#vm && result/bin/run-*-vm
      vm = nixos-generators.nixosGenerate {
        inherit system;
        format  = "vm";
        modules = [ ./nix/configuration.nix ];
      };
    };
  };
}
