{
  perSystem =
    { pkgs, ... }:
    {
      packages.cloudformation-languageserver = pkgs.callPackage ./_package.nix { };
    };
}
