{
  perSystem =
    { config, pkgs, lib, ... }:
    let
      grammars = pkgs.vimPlugins.nvim-treesitter.builtGrammars;

      parsers = pkgs.runCommand "cfn-nvim-sandbox-parsers" { } ''
        mkdir -p $out/parser $out/queries
        ${lib.concatMapStringsSep "\n" (lang: ''
          ln -s ${grammars.${lang}}/parser $out/parser/${lang}.so
          ln -s ${grammars.${lang}}/queries $out/queries/${lang}
        '') [ "yaml" "json" ]}
      '';

      nvim = pkgs.writeShellScriptBin "nvim" ''
        set -euo pipefail

        root="$(${lib.getExe pkgs.git} rev-parse --show-toplevel)"

        export XDG_CONFIG_HOME="$root/sandbox"
        export XDG_DATA_HOME="$root/sandbox/.local/data"
        export XDG_STATE_HOME="$root/sandbox/.local/state"
        export XDG_CACHE_HOME="$root/sandbox/.local/cache"

        pack="$XDG_DATA_HOME/''${NVIM_APPNAME:-nvim}/site/pack/sandbox/start"
        mkdir -p "$pack"
        ln -sfn ${parsers} "$pack/parsers"

        exec ${lib.getExe pkgs.neovim-unwrapped} "$@"
      '';

      nvim-release = pkgs.writeShellScriptBin "nvim-release" ''
        export NVIM_APPNAME=release
        exec ${lib.getExe nvim} "$@"
      '';
    in
    {
      devShells.sandbox = pkgs.mkShell {
        packages = [
          nvim
          nvim-release
          pkgs.go
          pkgs.curl
          pkgs.awscli2
          pkgs.python3Packages.cfn-lint
          config.packages.cloudformation-languageserver
        ];
      };
    };
}
