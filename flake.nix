{
  description = "virtual environments";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
  };
  outputs = { self, utils, devshell, nixpkgs }:
    utils.lib.eachDefaultSystem (system: {
      devShell = let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlays.default ];
        };

      in pkgs.devshell.mkShell {
        packages = with pkgs; [ azure-cli terraform ];
      };
    });
}
