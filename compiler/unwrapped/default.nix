# https://nim-lang.github.io/Nim/packaging.html

{ stdenv, lib, fetchurl, openssl, pcre, readline, boehmgc, sqlite }:

let
  parseCpu = platform: with platform;
    # Derive a Nim CPU identifier
    if isAarch32 then "arm" else
    if isAarch64 then "arm64" else
    if isAlpha then "alpha" else
    if isAvr then "avr" else
    if isMips && is32bit then "mips" else
    if isMips && is64bit then "mips64" else
    if isMsp430 then "msp430" else
    if isPowerPC && is32bit then "powerpc" else
    if isPowerPC && is64bit then "powerpc64" else
    if isRiscV && is64bit then "riscv64" else
    if isSparc then "sparc" else
    if isx86_32 then "i386" else
    if isx86_64 then "amd64" else
    abort "no Nim CPU support known for ${config}";

  parseOs = platform: with platform;
    # Derive a Nim OS identifier
    let isGenode =
      if platform ? isGenode
      then platform.isGenode
      else false;
    in
    if isAndroid then "Android" else
    if isDarwin then "MacOSX" else
    if isFreeBSD then "FreeBSD" else
    if isGenode then "Genode" else
    if isLinux then "Linux" else
    if isNetBSD then "NetBSD" else
    if isNone then "Standalone" else
    if isOpenBSD then "OpenBSD" else
    if isWindows then "Windows" else
    if isiOS then "iOS" else
    abort "no Nim OS support known for ${config}";

  parsePlatform = p: {
    cpu = parseCpu p;
    os = parseOs p;
  };

  nimBuild  = parsePlatform stdenv.buildPlatform;
  nimHost   = parsePlatform stdenv.hostPlatform;
  nimTarget = parsePlatform stdenv.targetPlatform;

  version = "1.0.2";

in stdenv.mkDerivation {
  pname = "nim";
  inherit version;

  src = fetchurl {
    url = "https://nim-lang.org/download/nim-${version}.tar.xz";
    sha256 = "1rjinrs119c8i6wzz5fzjfml7n7kbd5hb9642g4rr8qxkq4sx83k";
  };

  patches = [
    ./NIM_CONFIG_DIR.patch
    # This patch allows us to override the compiler
    # configuration using a wrapper.
    ./genode.patch
    ./detect_nixos.patch
  ];

  enableParallelBuilding = true;

  NIX_LDFLAGS = [ "-lcrypto" "-lpcre" "-lreadline" "-lgc" "-lsqlite3" ];

  buildInputs = [ openssl pcre readline boehmgc sqlite ];

  dontConfigure = true;

  kochArgs = [
    "--cpu:${nimHost.cpu}"
    "--os:${nimHost.os}"
    "-d:release"
    "-d:useGnuReadline"
    (lib.optionals (stdenv.isDarwin || stdenv.isLinux) "-d:nativeStacktrace")
  ];

  buildPhase = with stdenv.buildPlatform.uname; ''
    runHook preBuild

    local HOME=$TMPDIR
    ./build.sh --cpu ${nimBuild.cpu} --os ${nimBuild.os}
    ./bin/nim c koch
    ./koch boot $kochArgs --parallelBuild:$NIX_BUILD_CORES
    ./koch toolsNoNimble $kochArgs --parallelBuild:$NIX_BUILD_CORES

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    ./install.sh $out
    mv $out/nim/* $out
    rmdir $out/nim

    install -Dt $out/bin bin/*

    runHook postInstall
  '';

  passthru = { build = nimBuild; host = nimHost; target = nimTarget; };

  meta = with stdenv.lib; {
    description = "Statically typed, imperative programming language";
    homepage = "https://nim-lang.org/";
    license = licenses.mit;
    maintainers = with maintainers; [ ehmry ];
    platforms = with platforms; linux ++ darwin; # arbitrary
  };
}
