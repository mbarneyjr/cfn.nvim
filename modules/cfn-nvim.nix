{ config, ... }:
let
  inherit (config) version;
in
{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      packages.cfn-nvim = pkgs.buildGoModule {
        pname = "cfn-nvim";
        inherit version;

        src = lib.fileset.toSource {
          root = ../.;
          fileset = lib.fileset.unions [
            ../cmd
            ../internal
            ../main.go
            ../go.mod
            ../go.sum
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

      packages.default = config.packages.cfn-nvim;

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.go
          pkgs.vhs
        ];
      };
    };
}
