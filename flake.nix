{
  description = "wslg managed by flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    wsland.url = "github:qq1038765585/wsland/working";
    wslg-freerdp.url = "github:qq1038765585/freerdp-flake/working";
  };

  outputs = { self, nixpkgs, wsland, wslg-freerdp }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };

        wslg-freerdp-lib = wslg-freerdp.packages.${system}.default;
      in {
          wslg-applist = pkgs.stdenv.mkDerivation {
          name = "wsl-applist";
          src = ./rdpapplist;

          nativeBuildInputs = with pkgs; [
            pkg-config meson ninja
          ];

          buildInputs = with pkgs; [
            wslg-freerdp-lib
          ];
        };

        default = pkgs.stdenv.mkDerivation {
          name = "wslg-daemon";
          src = ./WSLGd;

          nativeBuildInputs = with pkgs; [
            pkg-config meson ninja
          ];

          buildInputs = with pkgs; [
            wsland.packages.${system}.default libcap
          ];
        };
      });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };

        wslg-freerdp-lib = wslg-freerdp.packages.${system}.default;
      in {
          wslg-applist = pkgs.mkShell {
            packages = with pkgs; [
              pkg-config meson ninja wslg-freerdp-lib
            ];
          };

          default = pkgs.mkShell {
            packages = with pkgs; [
              pkg-config meson ninja
              wsland.packages.${system}.default libcap
            ];
          };
        });
    };
}
