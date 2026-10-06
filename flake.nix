{
  description = "A Nix-flake-based Python development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
  inputs.nixpkgs-poetry.url = "github:NixOS/nixpkgs/6df24922a1400241dae323af55f30e4318a6ca65";

  outputs = { self, nixpkgs, nixpkgs-poetry }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
          pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
          };
          poetryPkgs = import nixpkgs-poetry { inherit system; };
      });
    in
    {
      devShells = forEachSupportedSystem ({ pkgs, poetryPkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [ python3 uv poetryPkgs.poetry ];
        };
      });
    };
}
