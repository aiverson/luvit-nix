{ pkgs ? import <nixpkgs> { }, ... }:

with pkgs;

let
  aiverson = {
    name = "Alex Iverson";
    email = "alexjiverson@gmail.com";
  };
  luvi = stdenv.mkDerivation rec {
    name = "luvi-${version}";
    version = "2.11.0";

    src = fetchFromGitHub {
      owner = "luvit";
      repo = "luvi";
      rev = "473a70e76ebb6d337f529db4f57507ca3dee04ba";
      fetchSubmodules = true;
      sha256 = "1m3az9sb9rj9p4iisy6x6bnhsflns2pkml1g94a6xf1pwbfbsg2f";
      # date = 2020-05-08T12:02:57-05:00;
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

      license = stdenv.lib.licenses.apsl20;
      maintainers = [ aiverson ];
      platforms = stdenv.lib.platforms.linux;
    };
  };

  makeLuviScript = name: source:
    writeBinScript name "${luvi}/bin/luvi ${source} -- $@";
  luviBase = writeScript "luvi" ''
    #!${luvi}/bin/luvi --
  '';

  lit = stdenv.mkDerivation rec {
    name = "lit-${version}";
    version = "3.8.1";

    src = fetchFromGitHub {
      owner = "luvit";
      repo = "lit";
      rev = "3bf3517b6efd08fd6bae12fd83707535a4a9d4af";
      fetchSubmodules = true;
      sha256 = "0lk8ac6ds3p2lfmb1mz1px0jjv6adlszsxm3j8g0z8if7nc41ba0";
      # date = 2020-03-09T01:43:33-07:00;
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
      description = "packageing tool for luvit";
      homepage = "https://github.com/luvit/lit";

      license = stdenv.lib.licenses.apsl20;
      maintainers = [ aiverson ];
      platforms = stdenv.lib.platforms.linux;
    };
  };

  makeLitPackage = { buildInputs ? [ ], ... }@args:
    stdenv.mkDerivation ({
      buildPhase = ''
        echo database: `pwd`/.litdb.git >> litconfig
        export LIT_CONFIG=`pwd`/litconfig
        lit install || echo work around bug
        lit make . ./$pname ${luviBase} || echo work around bug
      '';
      installPhase = ''
        mkdir -p $out/bin
        cp ./$pname $out/bin/$pname
      '';
    } // args // {
      buildInputs = [ lit ] ++ buildInputs;
    });

  luvit = makeLitPackage rec {
    name = "luvit-${version}";
    pname = "luvit";
    version = "2.17.0";

    src = fetchFromGitHub {
      owner = "luvit";
      repo = "luvit";
      rev = "788e0fb20b2f897f4624ac9290230060609cef50";
      sha256 = "0x8z3r88197bcl9bnwp3rrsw2px9cb1js1xpw0pvrfc76lg56qmj";
      # date = 2020-05-09T16:11:21+08:00;
    };

    meta = {
      description = "a lua runtime for application";
      homepage = "https://github.com/luvit/luvi";

      license = stdenv.lib.licenses.apsl20;
      maintainers = [ aiverson ];
      platforms = stdenv.lib.platforms.linux;
    };
  };

  lua = lua52Packages.lua.withPackages (p: with p; [ lpeg ]);

in { inherit luvit luvi lit makeLitPackage; }
