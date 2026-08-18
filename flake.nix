{
  description = "Neovim plugin for working with AWS CloudFormation templates.";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs =
    inputs@{ flake-parts, self, ... }:
    let
      version = self.shortRev or self.dirtyShortRev or "dev";
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { pkgs, lib, ... }:
        {
          packages.cfn-nvim = pkgs.buildGoModule {
            pname = "cfn-nvim";
            inherit version;

            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./cmd
                ./internal
                ./main.go
                ./go.mod
                ./go.sum
              ];
            };

            vendorHash = "sha256-mH14zisCXtgEzRBbZFXRqNNpj7LTU06m4a5IJMkd7d4=";
            subPackages = [ "." ];

            ldflags = [
              "-s"
              "-w"
              "-X github.com/mbarneyjr/cfn.nvim/cmd.version=${version}"
            ];

            postInstall = ''
              mv $out/bin/cfn.nvim $out/bin/cfn-nvim
            '';

            meta = {
              description = "Helper CLI for the cfn.nvim Neovim plugin";
              mainProgram = "cfn-nvim";
              homepage = "https://github.com/mbarneyjr/cfn.nvim";
              platforms = lib.platforms.unix;
            };
          };

          packages.vim-plugin = pkgs.vimUtils.buildVimPlugin {
            pname = "cfn.nvim";
            inherit version;

            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./lua
                ./readme.md
              ];
            };

            nvimRequireCheck = "cfn";

            meta = {
              description = "Neovim plugin for working with AWS CloudFormation templates";
              homepage = "https://github.com/mbarneyjr/cfn.nvim";
              platforms = lib.platforms.unix;
            };
          };

          packages.default = self.packages.${pkgs.system}.cfn-nvim;

          devShells.default = pkgs.mkShell {
            buildInputs = [ pkgs.go ];
          };
        };
    };
}
