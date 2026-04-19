# pi-mono-nix

Nix flake packaging the **[pi](https://github.com/badlogic/pi-mono) coding agent CLI** from `badlogic/pi-mono`. Auto-updated daily from upstream GitHub Releases.

Supports `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.

## Quick use (one-shot)

```bash
nix run github:tienedev/pi-mono-nix -- --help
```

## Flake input

```nix
{
  inputs.pi-mono-nix = {
    url = "github:tienedev/pi-mono-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then enable the overlay on your systems:

```nix
{ inputs, ... }: {
  nixpkgs.overlays = [ inputs.pi-mono-nix.overlays.default ];
  environment.systemPackages = [ pkgs.pi ];        # NixOS
  # or home.packages = [ pkgs.pi ];                # home-manager / nix-darwin
}
```

Or grab the package directly without the overlay:

```nix
home.packages = [ inputs.pi-mono-nix.packages.${pkgs.system}.default ];
```

## Configurable options

`pi` accepts overrides so you choose what lands in its runtime `PATH` and environment:

| Option                  | Default | What it does                                                    |
|-------------------------|---------|-----------------------------------------------------------------|
| `withRipgrep`           | `true`  | Bundle `ripgrep` — used by the `read`/search tools              |
| `withSandbox`           | `true`  | Bundle `bubblewrap` for bash sandboxing (Linux only, ignored on darwin) |
| `withGit`               | `true`  | Bundle `git` — pi works heavily in git repos                    |
| `withNodejs`            | `true`  | Bundle `nodejs_20` — needed to load TypeScript extensions/skills |
| `extraRuntimePackages`  | `[]`    | Extra packages prepended to the wrapper's PATH                  |
| `extraEnv`              | `{}`    | Extra env vars set by the wrapper (e.g. `{ PI_CONFIG_DIR = "..."; }`) |

Example — a slim `pi` without sandbox and nodejs, plus `fd` for extensions:

```nix
(pkgs.pi.override {
  withSandbox = false;
  withNodejs = false;
  extraRuntimePackages = [ pkgs.fd ];
  extraEnv = { PI_LOG_LEVEL = "debug"; };
})
```

## Outputs

- `packages.<system>.{pi,default}` — the `pi` binary derivation
- `overlays.default` — adds `pkgs.pi` (overridable via `.override`)
- `homeManagerModules.default` — adds `pi` to `home.packages`
- `devShells.<system>.default` — for hacking on this flake

## Auto-update

`.github/workflows/update.yml` runs daily at 08:00 UTC, checks the latest release on `badlogic/pi-mono`, recomputes the four platform hashes, smoke-builds, and commits if changed.

## License

MIT. Upstream `pi-mono` is MIT. The shipped binary is Bun-compiled from the upstream sources.
