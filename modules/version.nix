{ inputs, lib, ... }:
{
  options.version = lib.mkOption {
    type = lib.types.str;
    description = "Version stamped into the build outputs.";
  };

  config.version = inputs.self.shortRev or inputs.self.dirtyShortRev or "dev";
}
