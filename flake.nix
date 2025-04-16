{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    nix-pkgset.url = "github:szlend/nix-pkgset";
    nix-pkgset.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-pkgset,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        selfPkgs = self.legacyPackages.${system};
        inherit (pkgs) lib;
      in
      {
        legacyPackages = pkgs.callPackage ./packages.nix { inherit nix-pkgset; };

        lib = lib.filterAttrs (_: lib.isFunction) self.legacyPackages.${system};

        packages = lib.filterAttrs (_: lib.isDerivation) self.legacyPackages.${system};

        checks = {
          simple-lpeg =
            pkgs.runCommandNoCC "simple-lpeg-check"
              {
                strictDeps = true;
                nativeBuildInputs = [ selfPkgs.luvit ];
              }
              ''
                luvit ${./checks/simple-lpeg.lua} || exit 1
                mkdir $out
              '';
        } // (lib.filterAttrs (_: lib.isDerivation) selfPkgs);
      }
    )
    // {
      # Instantiate pkgset for this flake against an arbitrary nixpkgs base
      mkPkgset = pkgs: pkgs.callPackage ./packages.nix { inherit nix-pkgset; };
    };
}
