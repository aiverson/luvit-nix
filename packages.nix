{ nix-pkgset, pkgs }:
let
  aiverson = {
    name = "Alex Iverson";
    email = "alexjiverson@gmail.com";
  };
in
nix-pkgset.lib.makePackageSet "luvit-nix" pkgs.newScope (self: {
  /*
    Creates an executable script at /nix/store/<store path>/bin/<name>
    which executes the lua script located at source using `luvi`.
  */
  makeLuviScript = name: source: pkgs.writeScriptBin name "${self.luvi}/bin/luvi ${source} -- $@";

  luviBase = pkgs.writeScript "luvi" ''
    #!${self.luvi}/bin/luvi --
  '';

  vendorLitDeps = self.callPackage (
    {
      curl,
      lit,
      cacert,
    }:
    {
      src,
      sha256,
      pname,
      ...
    }@args:
    pkgs.stdenv.mkDerivation ({
      name = "${pname}-vendoredpkgs";
      nativeBuildInputs = [ curl ];
      buildInputs = [
        lit
        cacert
      ];
      phases = [
        "unpackPhase"
        "configurePhase"
        "buildPhase"
      ];
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
    })
  ) { };

  makeLitPackage = self.callPackage (
    {
      lit,
      luvi,
      luviBase,
    }:
    {
      buildInputs ? [ ],
      nativeBuildInputs ? [ ],
      src,
      pname,
      litSha256,
      ...
    }@args:
    let
      deps = self.vendorLitDeps {
        inherit src pname;
        sha256 = litSha256;
      };
    in
    pkgs.stdenv.mkDerivation (
      {
        strictDeps = true;
        buildPhase = ''
          runHook preBuild
          echo database: `pwd`/.litdb.git >> litconfig
          export LIT_CONFIG=`pwd`/litconfig
          ln -s ${deps}/deps ./deps
          lit make . ./$pname ${luviBase} | cat || echo "work around bug"
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp ./$pname $out/bin/$pname
          runHook postInstall
        '';
        meta.mainProgram = pname;
      }
      // args
      // {
        nativeBuildInputs = [ lit ] ++ nativeBuildInputs;
        buildInputs = [
          luvi
          lit
        ] ++ buildInputs;
      }
    )
  ) { };

  luvit = self.makeLitPackage {
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

  luvi = self.callPackage (
    {
      stdenv,
      cmake,
      openssl,
      zlib,
      luajit,
      ninja,
    }:
    stdenv.mkDerivation (finalAttrs: {
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

      nativeBuildInputs = [
        cmake
        luajit
        ninja
      ];
      buildInputs = [
        luajit
        openssl
        zlib
      ];

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
        "-DLUA_BUILD_TYPE=System"
      ];

      # Fix version, convince luv not to install staticlib/headers
      postPatch = ''
        echo ${finalAttrs.version} >> VERSION
        substituteInPlace deps/luv/deps/luajit.cmake \
          --replace-fail 'git show' 'true'
        substituteInPlace deps/luv/CMakeLists.txt \
          --replace-fail 'if (CMAKE_INSTALL_PREFIX)' 'if (FALSE)'
        substituteInPlace cmake/Modules/LuaAddExecutable.cmake \
          --replace-fail 'if ($ENV{LUA_PATH})' 'IF (FALSE)'
        substituteInPlace CMakeLists.txt \
          --replace-fail 'set(luajit_vmdef ''${CMAKE_CURRENT_BINARY_DIR}/deps/luv/vmdef.lua)' 'set(luajit_vmdef ${luajit}/share/lua/${luajit.luaversion}/jit/vmdef.lua)'
      '';

      meta = {
        description = "a lua runtime for applications";
        homepage = "https://github.com/luvit/luvi";

        license = pkgs.lib.licenses.apsl20;
        mainProgram = "luvi";
        maintainers = [ aiverson ];
      };
    })
  ) { };

  lit = self.callPackage (
    {
      luvi,
      luviBase,
      stdenv,
    }:
    stdenv.mkDerivation rec {
      pname = "lit";
      version = "3.8.5";
      strictDeps = true;

      src = pkgs.fetchFromGitHub {
        owner = "luvit";
        repo = "lit";
        rev = "${version}";
        sha256 = "sha256-8Fy1jIDNSI/bYHmiGPEJipTEb7NYCbN3LsrME23sLqQ=";
        fetchSubmodules = true;
      };

      nativeBuildInputs = [ luvi ];
      buildPhase = ''
        runHook preBuild
        echo database: `pwd`/.litdb.git >> litconfig
        export LIT_CONFIG=`pwd`/litconfig
        luvi . -- make . ./lit ${luviBase} || echo work around bug
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cp lit $out/bin/lit
        runHook postInstall
      '';

      meta = {
        description = "packaging tool for luvit";
        homepage = "https://github.com/luvit/lit";

        license = pkgs.lib.licenses.apsl20;
        mainProgram = "lit";
        maintainers = [ aiverson ];
      };
    }
  ) { };
})
