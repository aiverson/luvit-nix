{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    luvit = {
      url = "github:luvit/luvit";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, luvit }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
    aiverson = {
      name = "Alex Iverson";
      email = "alexjiverson@gmail.com";
    };
  in {
    lib = with pkgs; with self.packages.${system}; rec {
      makeLuviScript = name: source:
        writeBinScript name "${luvi}/bin/luvi ${source} -- $@";
      luviBase = writeScript "luvi" ''
        #!${luvi}/bin/luvi --
      '';
      vendorLitDeps = { src, sha256, pname, ... }@args:
        stdenv.mkDerivation({
          name = "${pname}-vendoredpkgs";
          buildInputs = [ lit curl cacert ];
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
        in stdenv.mkDerivation ({
          buildPhase = ''
            echo database: `pwd`/.litdb.git >> litconfig
            export LIT_CONFIG=`pwd`/litconfig
            ln -s ${deps} ./deps
            lit install || echo work around bug
            lit make . ./$pname ${luviBase} || echo work around bug
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp ./$pname $out/bin/$pname
          '';
        } // args // {
          buildInputs = [ lit curl ] ++ buildInputs;
        });
    };

    # Specify the default package
    defaultPackage.x86_64-linux = self.packages.x86_64-linux.luvit;

    packages.x86_64-linux = with pkgs; with self.lib; rec {
      luvit = makeLitPackage rec {
        pname = "luvit";
        version = "2.17.0";

        litSha256 = "sha256-3EYdIjxF6XvFE3Ft6qpx/gaySMKiZi3kKr2K7QPB+G0=";

        src = inputs.luvit;

        meta = {
          description = "a lua runtime for application";
          homepage = "https://github.com/luvit/luvi";

          license = pkgs.lib.licenses.apsl20;
          maintainers = [ aiverson ];
          platforms = pkgs.lib.platforms.linux;
        };
      };

      luvi = stdenv.mkDerivation rec {
        pname = "luvi";
        version = "2.11.0";

        src = pkgs.fetchFromGitHub {
          owner = "luvit";
          repo = "luvi";
          rev = "v${version}";
          sha256 = "VQCqyNQ9Ox+oE2u4l/O2czIBxTwSGfpEQdEjRgZCdOg=";
          fetchSubmodules = true;
        };

        buildInputs = [ cmake openssl ];

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
          platforms = pkgs.lib.platforms.linux;
        };
      };


      lit = stdenv.mkDerivation rec {
        pname = "lit";
        version = "3.8.1";

        src = pkgs.fetchFromGitHub {
          owner = "luvit";
          repo = "lit";
          rev = "${version}";
          sha256 = "sha256-/Si340i40mDxWwcZcPpRrvl8tpZs+pJM5a2yY2Lpd6g=";
          fetchSubmodules = true;
        };

        buildInputs = [ luvi strace ];
        buildPhase = ''
          echo database: `pwd`/.litdb.git >> litconfig
          LIT_CONFIG=`pwd`/litconfig luvi . -- make . ./lit ${luviBase} || echo work around bug
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
          platforms = pkgs.lib.platforms.linux;
        };
      };
    };
  };
}
