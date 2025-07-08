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
        
        makeLitPackage = { buildInputs ? [ ], nativeBuildInputs ? [ ], src, pname, litSha256, ... }@args:
          let
            deps = vendorLitDeps {
              inherit src pname;
              sha256 = litSha256;
            };
          in pkgs.stdenv.mkDerivation ({
            strictDeps = true;
            buildPhase = ''
              runHook preBuild
              echo database: `pwd`/.litdb.git >> litconfig
              export LIT_CONFIG=`pwd`/litconfig
              ln -s ${deps}/deps ./deps
              lit make . ./$pname ${luviBase} || echo "work around bug"
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp ./$pname $out/bin/$pname
              runHook postInstall
            '';
            meta.mainProgram = pname;
          } // args // {
            nativeBuildInputs = with selfPkgs; [ lit ] ++ nativeBuildInputs;
            buildInputs = with selfPkgs; [ luvi lit ] ++ buildInputs;
          });
      };

      packages = rec {
        default = luvit;

        luvit = self.lib.${system}.makeLitPackage {
          pname = "luvit";
          version = "unstable-2024-11-26";

          # This needs invalidated when updating src
          litSha256 = "sha256-AYMQi3d3wOH7jz/E4wSV7Kjx+/O6mkhkYJpFXVnCvtI=";

          src = pkgs.fetchFromGitHub {
            owner = "luvit";
            repo = "luvit";
            rev = "eb8dd116eecf6ac33f293c32c8d59ff86cb290fa";
            hash = "sha256-udkNmMr8pErzCWrtF+K5uE8Do82TJGW4Uh+JS27ZxKk=";
          };

          meta = {
            description = "a lua runtime for application";
            homepage = "https://github.com/luvit/luvi";

            license = pkgs.lib.licenses.apsl20;
            mainProgram = "luvit";
            maintainers = [ aiverson ];
          };
        };

        luvi = pkgs.stdenv.mkDerivation (finalAttrs: {
          pname = "luvi";
          version = "2.15.0";
          strictDeps = true;

          src = pkgs.fetchFromGitHub {
            owner = "luvit";
            repo = "luvi";
            rev = "v${finalAttrs.version}";
            sha256 = "sha256-+mVoL/B3hBt2SHAjEQdN0XUhb3WF3wbYPwgArkVEP4M=";
            fetchSubmodules = true;
          };

          nativeBuildInputs = with pkgs; [ cmake ];
          buildInputs = with pkgs; [ openssl zlib ];

          cmakeFlags = [
            "-DWithOpenSSL=ON"
            "-DWithPCRE=ON"
            "-DWithLPEG=ON"
            "-DWithZLIB=ON"
            "-DWithSharedOpenSSL=ON"
            "-DWithSharedPCRE=ON"
            "-DWithSharedLPEG=ON"
            "-DWithSharedZLIB=ON"
            "-DLUVI_VERSION=${finalAttrs.version}"
          ];

          # Fix version, convince luv not to install staticlib/headers
          postPatch = ''
            echo ${finalAttrs.version} >> VERSION
            substituteInPlace ./deps/luv/deps/luajit.cmake \
              --replace-fail 'git show' 'true'
            substituteInPlace ./deps/luv/CMakeLists.txt \
              --replace-fail 'if (CMAKE_INSTALL_PREFIX)' 'if (FALSE)'
          '';

          meta = {
            description = "a lua runtime for applications";
            homepage = "https://github.com/luvit/luvi";

            license = pkgs.lib.licenses.apsl20;
            mainProgram = "luvi";
            maintainers = [ aiverson ];
          };
        });

        lit = pkgs.stdenv.mkDerivation rec {
          pname = "lit";
          version = "3.8.5";
          strictDeps = true;
          env.UV_USE_IO_URING = 0;

          src = pkgs.fetchFromGitHub {
            owner = "luvit";
            repo = "lit";
            rev = "${version}";
            sha256 = "sha256-8Fy1jIDNSI/bYHmiGPEJipTEb7NYCbN3LsrME23sLqQ=";
            fetchSubmodules = true;
          };

          nativeBuildInputs = [ selfPkgs.luvi ];
          buildPhase = ''
            echo database: `pwd`/.litdb.git >> litconfig
            export LIT_CONFIG=`pwd`/litconfig
            luvi . -- make . ./lit ${selfLib.luviBase} || echo work around bug
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
