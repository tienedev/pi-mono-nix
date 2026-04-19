{
  description = "Nix flake for pi — interactive coding agent CLI from badlogic/pi-mono (auto-updated daily)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          pi = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.pi;
        }
      );

      overlays.default = final: prev: {
        pi = final.callPackage ./package.nix { };
      };

      homeManagerModules.default =
        { pkgs, ... }:
        {
          home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];
        };

      # Default dev shell — for hacking on this flake itself.
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nix-prefetch
              pkgs.jq
              pkgs.curl
            ];
          };
        }
      );
    };
}
