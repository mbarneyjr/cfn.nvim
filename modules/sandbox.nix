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

      mkSandbox =
        name:
        let
          nvim = pkgs.writeShellScriptBin "nvim" ''
            set -euo pipefail

            root="$(${lib.getExe pkgs.git} rev-parse --show-toplevel)"
            home="$root/sandbox/${name}"

            export XDG_CONFIG_HOME="$home"
            export XDG_DATA_HOME="$home/.local/data"
            export XDG_STATE_HOME="$home/.local/state"
            export XDG_CACHE_HOME="$home/.local/cache"

            pack="$XDG_DATA_HOME/nvim/site/pack/sandbox/start"
            mkdir -p "$pack"
            ln -sfn ${parsers} "$pack/parsers"

            exec ${lib.getExe pkgs.neovim-unwrapped} "$@"
          '';
        in
        pkgs.mkShell {
          packages = [
            nvim
            pkgs.git
            pkgs.go
            pkgs.curl
            pkgs.awscli2
            pkgs.python3Packages.cfn-lint
            config.packages.cloudformation-languageserver
          ];
        };
    in
    {
      devShells.sandbox-dev = mkSandbox "dev";
      devShells.sandbox-live = mkSandbox "live";
      devShells.sandbox-release = mkSandbox "release";
      devShells.sandbox-lazy-dev = mkSandbox "lazy-dev";
      devShells.sandbox-lazy-release = mkSandbox "lazy-release";
    };
}
