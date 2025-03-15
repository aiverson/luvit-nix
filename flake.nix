{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils }: let
    aiverson = {
      name = "Alex Iverson";
      email = "alexjiverson@gmail.com";
    };
  in flake-utils.lib.eachDefaultSystem (system: 
    let
      pkgs = import nixpkgs { inherit system; };
      selfPkgs = self.packages.${system};
      selfLib = self.lib.${system};
    in
    {
      lib = rec {
        /*
          Creates an executable script at /nix/store/<store path>/bin/<name>
          which executes the lua script located at source using `luvi`.
        */
        makeLuviScript = name: source:
          pkgs.writeScriptBin name "${selfPkgs.luvi}/bin/luvi ${source} -- $@";

        luviBase = pkgs.writeScript "luvi" ''
          #!${selfPkgs.luvi}/bin/luvi --
        '';

        vendorLitDeps = { src, sha256, pname, ... }@args:
          pkgs.stdenv.mkDerivation({
            name = "${pname}-vendoredpkgs";
            buildInputs = with pkgs; [ selfPkgs.lit curl cacert ];
            phases = [ "unpackPhase" "configurePhase" "buildPhase" ];
            buildPhase = ''
              export HOME=./
              mkdir -p $out
              lit install || echo "work around bug"
              cp -r ./deps $out
            '';

            inherit src;

            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = sha256;
          });
        
        makeLitPackage = { buildInputs ? [ ], src, pname, litSha256, ... }@args:
          let
            deps = vendorLitDeps {
              inherit src pname;
              sha256 = litSha256;
            };
          in pkgs.stdenv.mkDerivation ({
            buildPhase = ''
              echo database: `pwd`/.litdb.git >> litconfig
              export LIT_CONFIG=`pwd`/litconfig
              ln -s ${deps}/deps ./deps
              lit make . ./$pname ${luviBase} || echo "work around bug"
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp ./$pname $out/bin/$pname
            '';
          } // args // {
            buildInputs = with selfPkgs; [ lit luvi ] ++ buildInputs;
          });
      };

      # defaultPackage is depricated in nix 2.13, using this for compatibility
      defaultPackage = selfPkgs.default;

      packages = rec {
        default = luvit;

        luvit = self.lib.${system}.makeLitPackage {
          pname = "luvit";
          version = "unstable-2022-01-19";

          # This needs invalidated when updating src
          litSha256 = "sha256-3EYdIjxF6XvFE3Ft6qpx/gaySMKiZi3kKr2K7QPB+G0=";

          src = pkgs.fetchFromGitHub {
            owner = "luvit";
            repo = "luvit";
            rev = "3f328ad928eb214f6438dd25fb9ee8b5c1e9255c";
            hash = "sha256-TNiD6GPnS8O2d53sJ52xWYqMAXrVJu2lkfXhf2jWuL0=";
          };

          meta = {
            description = "a lua runtime for application";
            homepage = "https://github.com/luvit/luvi";

            license = pkgs.lib.licenses.apsl20;
            maintainers = [ aiverson ];
          };
        };

        luvi = pkgs.stdenv.mkDerivation rec {
          pname = "luvi";
          version = "2.14.0";

          src = pkgs.fetchFromGitHub {
            owner = "luvit";
            repo = "luvi";
            rev = "v${version}";
            sha256 = "sha256-c1rvRDHSU23KwrfEAu+fhouoF16Sla6hWvxyvUb5/Kg=";
            fetchSubmodules = true;
          };

          patches = [
            ./luvi/0001-CMake-non-internal-RPATH-cache-variables.patch
            ./luvi/0002-Respect-provided-CMAKE_INSTALL_RPATH.patch
          ];

          buildInputs = with pkgs; [ cmake openssl ];

          cmakeFlags = [
            "-DWithOpenSSL=ON"
            "-DWithSharedOpenSSL=ON"
            "-DWithPCRE=ON"
            "-DWithLPEG=ON"
            "-DWithSharedPCRE=OFF"
            "-DLUVI_VERSION=${version}"
            "-DCMAKE_BUILD_WITH_INSTALL_RPATH=OFF"
            "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF"
          ];

          patchPhase = ''
            echo ${version} >> VERSION
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp luvi $out/bin/luvi
          '';

          meta = {
            description = "a lua runtime for applications";
            homepage = "https://github.com/luvit/luvi";

            license = pkgs.lib.licenses.apsl20;
            mainProgram = "luvit";
            maintainers = [ aiverson ];
          };
        };

        lit = pkgs.stdenv.mkDerivation rec {
          pname = "lit";
          version = "3.8.5";

          src = pkgs.fetchFromGitHub {
            owner = "luvit";
            repo = "lit";
            rev = "${version}";
            sha256 = "sha256-8Fy1jIDNSI/bYHmiGPEJipTEb7NYCbN3LsrME23sLqQ=";
            fetchSubmodules = true;
          };

          buildInputs = [ selfPkgs.luvi ];
          buildPhase = ''
            echo database: `pwd`/.litdb.git >> litconfig
            export LIT_CONFIG=`pwd`/litconfig
            ${selfPkgs.luvi}/bin/luvi . -- make . ./lit ${selfLib.luviBase} || echo work around bug
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp lit $out/bin/lit
          '';

          meta = {
            description = "packaging tool for luvit";
            homepage = "https://github.com/luvit/lit";

            license = pkgs.lib.licenses.apsl20;
            mainProgram = "lit";
            maintainers = [ aiverson ];
          };
        };
      };

      checks = {
        simple-lpeg = pkgs.runCommandNoCC "simple-lpeg-check" {
          strictDeps = true;
          nativeBuildInputs = [ selfPkgs.luvit ];
        } ''
          luvit ${./checks/simple-lpeg.lua} || exit 1
          mkdir $out
        '';
      } // selfPkgs;
    });
}
