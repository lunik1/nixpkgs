{
  lib,
  stdenvNoCC,
  cryptopp,
  vcpkg,
  libzen,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "crypto++-cmake";
  version = "8.9.0";

  src = fetchFromGitHub {
    owner = "abdes";
    repo = "cryptopp-cmake";
    rev = "f815f6284684be6ab03af4b6c273359331c61241";
    hash = "sha256-j1B1aKCDE1Znz+Hp/djjZBYwdAiMzq3tYnx89ZWbwoc=";
  };

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/lib/cmake/cryptopp
    cp cryptopp/cryptoppConfig.cmake $out/lib/cmake/cryptopp
    touch $out/lib/cmake/cryptopp/cryptopp-shared-targets.cmake


    mkdir -p $out/lib/cmake/unofficial-sodium/
    cp ${vcpkg}/share/vcpkg/ports/libsodium/sodiumConfig.cmake.in $out/lib/cmake/unofficial-sodium/unofficial-sodiumConfig.cmake

    mkdir -p $out/lib/cmake/unofficial-sqlite3/
    cp ${vcpkg}/share/vcpkg/ports/sqlite3/sqlite3-config.in.cmake $out/lib/cmake/unofficial-sqlite3/unofficial-sqlite3Config.cmake

  '';

  meta = with lib; {
    # description = "Free C++ class library of cryptographic schemes";
    # homepage = "https://cryptopp.com/";
    license = with licenses; [
      bsd3
    ];
    platforms = platforms.all;
    maintainers = with maintainers; [ lunik1 ];
  };
}
