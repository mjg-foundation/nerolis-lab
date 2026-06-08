{
  description = "Development shell for the Neroli's Lab monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        lib = pkgs.lib;
        nodejs = pkgs.nodejs_22;

        nativeNodeBuildInputs = with pkgs; [
          gcc
          gnumake
          pkg-config
          python3
        ];

        mkNodeModules =
          dir:
          pkgs.importNpmLock.buildNodeModules {
            npmRoot = dir;
            inherit nodejs;
            derivationArgs = {
              nativeBuildInputs = nativeNodeBuildInputs;
            };
          };

        nodeModules = {
          root = mkNodeModules ./.;
          common = mkNodeModules ./common;
          backend = mkNodeModules ./backend;
          frontend = mkNodeModules ./frontend;
          guides = mkNodeModules ./guides;
          docs = mkNodeModules ./docs;
        };
      in
      {
        packages =
          lib.mapAttrs'
            (name: value: lib.nameValuePair "${name}-node-modules" value)
            nodeModules;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            docker
            docker-compose
            gcc
            git
            gnumake
            just
            nodejs
            pkg-config
            python3
          ];

          shellHook = ''
            echo "Neroli's Lab dev shell ready. See Justfile recipes with: just -h"
          '';
        };
      }
    );
}
