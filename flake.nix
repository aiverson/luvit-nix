{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    luvit = {
      url = "github:luvit/luvit";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, luvit }: let
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
          version = "2.18.1-unstable";

          litSha256 = "sha256-W6VNp1jkDeafE4fdfK7xfX57wqkDQIyApBdF0R5/Jbo=";

          src = inputs.luvit;

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

          buildInputs = with pkgs; [ cmake openssl ];

          cmakeFlags = [
            "-DWithOpenSSL=ON"
            "-DWithSharedOpenSSL=ON"
            "-DWithPCRE=ON"
            "-DWithLPEG=ON"
            "-DWithSharedPCRE=OFF"
            "-DLUVI_VERSION=${version}"
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
            maintainers = [ aiverson ];
          };
        };
      };
    });
}
