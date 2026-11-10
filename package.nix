{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  autoPatchelfHook,
  libxcb,
  # Runtime tools — exposed in the wrapper's PATH.
  # Toggle or extend from the outside via .override { ... }.
  ripgrep,
  bubblewrap,
  procps,
  git,
  nodejs_22,
  coreutils,
  bash,
  # Feature toggles (override via pi.override { withSandbox = false; })
  withRipgrep ? true,
  withSandbox ? true, # bubblewrap — Linux only, ignored on darwin
  withGit ? true,
  withNodejs ? true, # for TypeScript/JS extensions & skills
  extraRuntimePackages ? [ ],
  extraEnv ? { }, # { FOO = "bar"; } → --set FOO bar
}:

let
  version = "1.5.2";

  platformMap = {
    x86_64-linux = {
      suffix = "linux-x64";
      hash = "sha256-gRxvLJ56ruJStUBCUuVW+3E6ognB9/kkImqnfU73DLU=";
    };
    aarch64-linux = {
      suffix = "linux-arm64";
      hash = "sha256-QoBc1WFZUvy7/JxWsE+P64Q5UTSVLhaabNyNdnaXVmY=";
    };
    x86_64-darwin = {
      suffix = "darwin-x64";
      hash = "sha256-+ZegiGE1FKyX2ROu6nZCCU2E/m1GhU/35k4sEuU23FA=";
    };
    aarch64-darwin = {
      suffix = "darwin-arm64";
      hash = "sha256-VrXhlNSFztVVZnuLoydhV6gnLp7N6eAB5CivgJhb3Zs=";
    };
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
      or (throw "pi-mono: unsupported system ${stdenv.hostPlatform.system}");

  runtimePath =
    lib.optional withRipgrep ripgrep
    ++ lib.optional (withSandbox && stdenv.hostPlatform.isLinux) bubblewrap
    ++ lib.optional withGit git
    ++ lib.optional withNodejs nodejs_22
    ++ [
      procps
      coreutils
      bash
    ]
    ++ extraRuntimePackages;

  envFlags = lib.concatStringsSep " " (
    lib.mapAttrsToList (k: v: "--set ${lib.escapeShellArg k} ${lib.escapeShellArg (toString v)}") extraEnv
  );
in
stdenv.mkDerivation {
  pname = "pi";
  inherit version;

  src = fetchurl {
    url = "https://github.com/badlogic/pi-mono/releases/download/v${version}/pi-${platform.suffix}.tar.gz";
    hash = platform.hash;
  };

  sourceRoot = "pi";
  dontStrip = true;

  nativeBuildInputs = [
    makeBinaryWrapper
  ] ++ lib.optionals stdenv.hostPlatform.isElf [ autoPatchelfHook ];

  # Native node addons in the Linux bundle: libgcc_s (clipboard addon, 0.81+)
  # and libxcb (native/linux/prebuilds/*/linux-platform-x11.node, 1.x).
  buildInputs = lib.optionals stdenv.hostPlatform.isElf [
    stdenv.cc.cc.lib
    libxcb
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/pi $out/bin
    cp -r . $out/share/pi/
    chmod +x $out/share/pi/pi

    makeBinaryWrapper $out/share/pi/pi $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath runtimePath} \
      ${envFlags}

    runHook postInstall
  '';

  meta = with lib; {
    description = "pi — interactive coding agent CLI from the pi-mono toolkit";
    longDescription = ''
      pi is a minimal terminal coding harness with read/write/edit/bash tools,
      session management, and a pluggable extension system. Supports Anthropic,
      OpenAI, Google, OpenRouter, vLLM and many other providers.
    '';
    homepage = "https://github.com/badlogic/pi-mono";
    changelog = "https://github.com/badlogic/pi-mono/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames platformMap;
    mainProgram = "pi";
  };
}
