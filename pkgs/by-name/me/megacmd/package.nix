{
  lib,
  stdenv,
  c-ares,
  cmake,
  ninja,
  cryptopp,
  cryptopp-cmake,
  curl,
  gnumake,
  fetchFromGitHub,
  ffmpeg,
  freeimage,
  gcc-unwrapped,
  git,
  icu,
  libmediainfo,
  libraw,
  libsodium,
  libuv,
  libzen,
  pcre-cpp,
  pkg-config,
  readline,
  sqlite,
  unzip,
  vcpkg,
  zip,
  writeText,
  withFreeImage ? false, # default to false because freeimage is insecure
}:

let
  pname = "megacmd";
  version = "2.0.0";
  srcOptions =
    if stdenv.isLinux then
      {
        tag = "${version}_Linux";
        hash = "sha256-jfzTfu1m5muI4W+FaDsC+GE22zmxYmc3Wcib2sQCUCE=";
      }
    else
      {
        tag = "${version}_macOS";
        hash = "";
      };
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub (
    srcOptions
    // {
      owner = "meganz";
      repo = "MEGAcmd";
      fetchSubmodules = true;
    }
  );

  postUnpack =
    let
      vcpkg_target = "x64-linux";

      vcpkg_pkgs = [
        "cryptopp"
        "libsodium"
        "libzen"
      ];

      updates_vcpkg_file = writeText "update_vcpkg_MEGAcmd" (
        lib.concatMapStringsSep "\n" (name: ''
          Package : ${name}
            Architecture : ${vcpkg_target}
            Version : 1.0
          Status : is installed
        '') vcpkg_pkgs
      );
    in
    ''
      export VCPKG_ROOT="$TMP/vcpkg"

      cp -Lr ${vcpkg.src} $VCPKG_ROOT
      chmod +w -R $VCPKG_ROOT

      cp ${vcpkg}/share/vcpkg/ports/libsodium/sodiumConfig.cmake.in unofficial-sodiumConfig.cmake

      rm $VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
      touch $VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake

      mkdir cmake
      cp ${vcpkg}/share/vcpkg/ports/ffmpeg/FindFFMPEG.cmake.in cmake/FindFFMPEG.cmake

      mkdir -p $VCPKG_ROOT/installed/${vcpkg_target}/lib
      mkdir -p $VCPKG_ROOT/installed/vcpkg/updates
      ln -s ${updates_vcpkg_file} $VCPKG_ROOT/installed/vcpkg/status
      mkdir -p $VCPKG_ROOT/installed/vcpkg/info
      ${lib.concatMapStrings (name: ''
        touch $VCPKG_ROOT/installed/vcpkg/info/${name}_1.0_${vcpkg_target}.list
      '') vcpkg_pkgs}

      ln -s ${cryptopp}/lib/lib* $VCPKG_ROOT/installed/${vcpkg_target}/lib/
      ln -s ${libsodium}/lib/lib* $VCPKG_ROOT/installed/${vcpkg_target}/lib/
      ln -s ${libzen}/lib/lib* $VCPKG_ROOT/installed/${vcpkg_target}/lib/
    '';

  enableParallelBuilding = true;

  nativeBuildInputs = [
    git
    cmake
    ninja
    pkg-config
    unzip
    zip
  ];

  buildInputs =
    # lib.optionals stdenv.isLinux [ gcc-unwrapped ] # fix: ld: cannot find lib64/libstdc++fs.a
    [
      c-ares
      cryptopp
      cryptopp-cmake
      curl
      ffmpeg
      icu
      libmediainfo
      libraw
      libsodium
      libuv
      libzen
      pcre-cpp
      readline
      sqlite
    ]
    ++ lib.optionals withFreeImage [ freeimage ];

  # cryptopp_DIR = "${cryptopp-cmake}/lib/cmake/cryptopp";
  unofficial-sodium_DIR = ".";

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    (lib.cmakeFeature "CMAKE_MAKE_PROGRAM" "ninja")
    # (lib.cmakeFeature "CRYPTOPP_LIBARIES" "${cryptopp}/lib/libcryptopp.so")
    # (lib.cmakeFeature "CRYPTOPP_INCLUDE_DIRS" "${cryptopp.dev}/include/cryptopp")
    # (lib.cmakeFeature "GIT_EXECUTABLE" "${fakegit}/bin/git")
    (lib.cmakeFeature "VCPKG_ROOT" "/build/vcpkg")
    (lib.cmakeFeature "USE_MEDIAINFO" "0")
    (lib.cmakeFeature "USE_FREEIMAGE" "0")
    (lib.cmakeFeature "USE_FFMPEG" "0")
    (lib.cmakeFeature "USE_LIBUV" "0")
    (lib.cmakeFeature "USE_PDFIUM" "0")
    # (lib.cmakeFeature "cryptopp_DIR" "${cryptopp-cmake}/lib/cmake/cryptopp")
    # (lib.cmakeFeature "CMAKE_TOOLCHAIN_FILE" "${vcpkg}/share/vcpkg/scripts/buildsystems/vcpkg.cmake")
    # (lib.cmakeFeature "CMAKE_PREFIX_PATH" "${cryptopp-cmake}/lib/cmake/cryptopp")
    # (lib.cmakeFeature "VCPKG_MAINFEST_INSTALL" "OFF")
    # (lib.cmakeFeature "CMAKE_MODULE_PATH" "cmake")
  ];

  # configureFlags = [
  #   "--disable-examples"
  #   "--with-cares"
  #   "--with-cryptopp"
  #   "--with-curl"
  #   "--with-ffmpeg"
  #   "--with-icu"
  #   "--with-libmediainfo"
  #   "--with-libuv"
  #   "--with-libzen"
  #   "--with-pcre"
  #   "--with-readline"
  #   "--with-sodium"
  #   "--with-termcap"
  # ] ++ (if withFreeImage then [ "--with-freeimage" ] else [ "--without-freeimage" ]);

  # On darwin, some macros defined in AssertMacros.h (from apple-sdk) are conflicting.
  postConfigure = ''
    echo '#define __ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES 0' >> sdk/include/mega/config.h
  '';

  patches = [
    # ./no-vcpkg.test
    ./fix-ffmpeg.patch # https://github.com/meganz/sdk/issues/2635#issuecomment-1495405085
    # ./fix-darwin.patch # fix: libtool tag not found; MacFileSystemAccess not declared; server cannot init
  ];

  meta = {
    description = "MEGA Command Line Interactive and Scriptable Application";
    homepage = "https://mega.io/cmd";
    license = with lib.licenses; [
      bsd2
      gpl3Only
    ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = with lib.maintainers; [
      lunik1
      ulysseszhan
    ];
  };
}
