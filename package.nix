{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  autoPatchelfHook,
  # Runtime tools — exposed in the wrapper's PATH.
  # Toggle or extend from the outside via .override { ... }.
  ripgrep,
  bubblewrap,
  procps,
  git,
  nodejs_20,
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
  version = "0.67.68";

  platformMap = {
    x86_64-linux = {
      suffix = "linux-x64";
      hash = "sha256-hbg5hQQvr/5jU4bA27prd0Us74OP2cbWd1p5xmfCFyo=";
    };
    aarch64-linux = {
      suffix = "linux-arm64";
      hash = "sha256-JCBXi7u1429TKG6W8QeAN10cXHmT/u41W8l68eRFagg=";
    };
    x86_64-darwin = {
      suffix = "darwin-x64";
      hash = "sha256-GjGrYC7nsJCv8obhI91TUxKIpEup6mxGBCLO5f8apSY=";
    };
    aarch64-darwin = {
      suffix = "darwin-arm64";
      hash = "sha256-UfwEZO8GRZ46yKjrynAzYKne/tGrlrXMuL+4DwyD+PI=";
    };
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
      or (throw "pi-mono: unsupported system ${stdenv.hostPlatform.system}");

  runtimePath =
    lib.optional withRipgrep ripgrep
    ++ lib.optional (withSandbox && stdenv.hostPlatform.isLinux) bubblewrap
    ++ lib.optional withGit git
    ++ lib.optional withNodejs nodejs_20
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
