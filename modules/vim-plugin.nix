{ config, ... }:
let
  inherit (config) version;
in
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.vim-plugin = pkgs.vimUtils.buildVimPlugin {
        pname = "cfn.nvim";
        inherit version;

        src = lib.fileset.toSource {
          root = ../.;
          fileset = lib.fileset.unions [
            ../lua
            ../doc/cfn.nvim.txt
            ../readme.md
          ];
        };

        nvimRequireCheck = "cfn";

        meta = {
          description = "Neovim plugin for working with AWS CloudFormation templates";
          homepage = "https://github.com/mbarneyjr/cfn.nvim";
          license = lib.licenses.mit;
          platforms = lib.platforms.unix;
        };
      };
    };
}
