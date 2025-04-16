# USAGE:
# crossbuild from current system to x64, or from x64 to aarch64:
#   nix-build demo.nix --attr luvit
# Demonstrating that overriding lit via an overrideScope call composes with the other packages:
#   nix-build demo.nix --attr luvit --arg testOverrideScope true 
# With most nix flakes this would require using an overlay, but with nix-pkgset it works because the packages are a scope
{
  curFlake ? builtins.getFlake (builtins.toString ./.),
  hostSystem ? builtins.currentSystem,
  crossSystem ? if hostSystem == "x86_64-linux" then "aarch64-unknown-linux-gnu" else "x86_64-unknown-linux-gnu",
  pkgsCross ? import (builtins.getFlake "github:nixos/nixpkgs/nixos-24.11") {
    system = hostSystem;
    crossSystem = {
      config = crossSystem;
    };
  },
  testOverrideScope ? false,
}:
# curFlake.mkPkgset pkgsCross
# and curFlake.legacyPackages.aarch64-linux.override { pkgs = pkgsCross; } are kinda equivalent
# but the latter might result in an unnecessary eval of the non-cross nixpkgs?
(curFlake.legacyPackages.aarch64-linux.override {
  pkgs = pkgsCross;
})
.overrideScope (final: prev: {
  lit = prev.lit.overrideAttrs {
    postBuild = pkgsCross.lib.optionalString testOverrideScope ''
      echo "!!! demoing this override propagating by deliberately failing the lit build !!!"
      exit 1
    '';
  };
})
