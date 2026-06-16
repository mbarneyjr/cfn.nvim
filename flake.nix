{
  description = "Neovim plugin for working with AWS CloudFormation templates.";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          pkgs,
          self',
          ...
        }:
        {
          packages.cfn-nvim = pkgs.buildGoModule {
            pname = "cfn-nvim";
            version = "0.0.0";
            src = ./.;
            vendorHash = "sha256-X0zCwxCbIPVFW7AhKCPJUrs41FqW9MTEPyqJBraCXLk=";
            subPackages = [ "." ];
            postInstall = ''
              mv $out/bin/cfn.nvim $out/bin/cfn-nvim
            '';
          };
          packages.default = pkgs.symlinkJoin {
            name = "cfn-nvim";
            paths = [
              self'.packages.cfn-nvim
            ];
          };
          devShells.default = pkgs.mkShell {
            buildInputs = [ pkgs.go ];
          };
        };
    };
}
