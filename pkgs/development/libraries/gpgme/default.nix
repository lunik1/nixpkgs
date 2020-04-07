{ stdenv, fetchurl, fetchpatch, libgpgerror, gnupg, pkgconfig, glib, pth, libassuan
, file, which, ncurses
, texinfo
, buildPackages
, qtbase ? null
, pythonSupport ? false, swig2 ? null, python ? null
}:

let
  inherit (stdenv) lib;
  inherit (stdenv.hostPlatform) system;
in

stdenv.mkDerivation rec {
  pname = "gpgme";
  version = "1.13.1";

  src = fetchurl {
    url = "mirror://gnupg/gpgme/${pname}-${version}.tar.bz2";
    sha256 = "0imyjfryvvjdbai454p70zcr95m94j9xnzywrlilqdw2fqi0pqy4";
  };

  patches = [
    # Fix tests with gnupg > 2.2.19
    # https://dev.gnupg.org/T4820
    (fetchpatch {
      name = "cff600f1f65a2164ab25ff2b039cba008776ce62.patch";
      url = "http://git.gnupg.org/cgi-bin/gitweb.cgi?p=gpgme.git;a=patch;h=cff600f1f65a2164ab25ff2b039cba008776ce62";
      sha256 = "9vB2aTv3zeAQS3UxCDfkRjqUlng8lkcyJPgMzdm+Qzc=";
    })
    (fetchpatch {
      name = "c4cf527ea227edb468a84bf9b8ce996807bd6992.patch";
      url = "http://git.gnupg.org/cgi-bin/gitweb.cgi?p=gpgme.git;a=patch;h=c4cf527ea227edb468a84bf9b8ce996807bd6992";
      sha256 = "pKL1tvUw7PB2w4FHSt2up4SvpFiprBH6TLdgKxYFC3g=";
    })
  ];

  outputs = [ "out" "dev" "info" ];
  outputBin = "dev"; # gpgme-config; not so sure about gpgme-tool

  propagatedBuildInputs =
    [ libgpgerror glib libassuan pth ]
    ++ lib.optional (qtbase != null) qtbase;

  nativeBuildInputs = [ file pkgconfig gnupg texinfo ]
  ++ lib.optionals pythonSupport [ python swig2 which ncurses ];

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  postPatch =''
    substituteInPlace ./configure --replace /usr/bin/file ${file}/bin/file
  '';

  configureFlags = [
    "--enable-fixed-path=${gnupg}/bin"
    "--with-libgpg-error-prefix=${libgpgerror.dev}"
    "--with-libassuan-prefix=${libassuan.dev}"
  ] ++ lib.optional pythonSupport "--enable-languages=python"
  # Tests will try to communicate with gpg-agent instance via a UNIX socket
  # which has a path length limit. Nix on darwin is using a build directory
  # that already has quite a long path and the resulting socket path doesn't
  # fit in the limit. https://github.com/NixOS/nix/pull/1085
    ++ lib.optionals stdenv.isDarwin [ "--disable-gpg-test" ];

  env.NIX_CFLAGS_COMPILE = toString (
    # qgpgme uses Q_ASSERT which retains build inputs at runtime unless
    # debugging is disabled
    lib.optional (qtbase != null) "-DQT_NO_DEBUG"
    # https://www.gnupg.org/documentation/manuals/gpgme/Largefile-Support-_0028LFS_0029.html
    ++ lib.optional (system == "i686-linux") "-D_FILE_OFFSET_BITS=64");

  checkInputs = [ which ];

  doCheck = true;

  meta = with stdenv.lib; {
    homepage = https://gnupg.org/software/gpgme/index.html;
    description = "Library for making GnuPG easier to use";
    longDescription = ''
      GnuPG Made Easy (GPGME) is a library designed to make access to GnuPG
      easier for applications. It provides a High-Level Crypto API for
      encryption, decryption, signing, signature verification and key
      management.
    '';
    license = with licenses; [ lgpl21Plus gpl3Plus ];
    platforms = platforms.unix;
    maintainers = with maintainers; [ primeos ];
  };
}
