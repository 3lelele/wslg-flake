# WSLg + wsland Integration Notes

## Purpose

This repository is being adapted to replace the default WSLg Weston compositor path with a `wsland`-based path built on `wlroots`.

The immediate goal is:

1. Build a custom WSLg system distro VHD from `wslg-flake`
2. Allow `WSLGd` to launch `wsland` instead of `weston`
3. Keep the existing WSLg RDP/vsock boot path working

The final user goal is JetBrains IDE Wayland startup with IME support, but that part is **not finished yet**. The current work only establishes the compositor replacement path.

## Repositories Involved

### 1. `wslg-flake`

Local path:

`/home/storm/Downloads/wslg-flake`

Remote:

`git@github.com:3lelele/wslg-flake.git`

This is the main build repository. It contains:

- `Dockerfile`
- `WSLGd`
- `build-and-export.sh`
- GitHub Actions workflow for remote VHD builds

### 2. `wsland`

Local path:

`/home/storm/Downloads/wsland`

Remote:

`git@github.com:3lelele/wsland.git`

This is the compositor implementation repo built on `wlroots`.

The GitHub Actions workflow in `wslg-flake` pulls this repo into `vendor/wsland` during CI.

## Key Configuration Files

### Windows-side `.wslgconfig`

Path:

`C:\ProgramData\Microsoft\WSL\.wslgconfig`

Current intended content:

```ini
[system-distro-env]
WSLG_USE_WSLAND=1
```

This is read by `WSLGd` and passed into the system distro environment.

### Windows-side `.wslconfig`

Used later to point WSL to the custom system distro VHD, for example:

```ini
[wsl2]
systemDistro=C:\\WSL\\system_x64.vhd
```

After replacing/updating the VHD, Windows must run:

```powershell
wsl --shutdown
```

Do **not** run `wsl --shutdown` before building the VHD. Build first, replace/configure VHD second, shutdown last.

## Important Code Changes Already Made

### In `wsland`

Files changed:

- [meson.build](/home/storm/Downloads/wsland/meson.build)
- [include/wsland/utils/config.h](/home/storm/Downloads/wsland/include/wsland/utils/config.h)
- [src/utils/config.c](/home/storm/Downloads/wsland/src/utils/config.c)
- [src/server/server.c](/home/storm/Downloads/wsland/src/server/server.c)

What changed:

1. `wsland` is now installed by Meson with `install: true`
2. `wsland` now accepts a fixed `WAYLAND_DISPLAY` name from env instead of always auto-allocating
3. `wsland` now accepts `WSLGD_NOTIFY_SOCKET` and sends a ready notification to `WSLGd`

Why this matters:

- WSLg expects a stable socket like `wayland-0`
- `WSLGd` waits for compositor readiness before continuing

### In `wslg-flake`

Files changed:

- [WSLGd/main.cpp](/home/storm/Downloads/wslg-flake/WSLGd/main.cpp)
- [Dockerfile](/home/storm/Downloads/wslg-flake/Dockerfile)
- [.dockerignore](/home/storm/Downloads/wslg-flake/.dockerignore)
- [.github/workflows/build-system-distro.yml](/home/storm/Downloads/wslg-flake/.github/workflows/build-system-distro.yml)

What changed:

1. `WSLGd` now supports `WSLG_USE_WSLAND=1`
2. When enabled, `WSLGd` launches `/usr/bin/wsland` instead of `/usr/bin/weston`
3. The Docker build now builds `vendor/wsland`
4. `rdpapplist` installation now creates:
   `/usr/lib/librdpapplist-server.so`
   as a symlink to the installed plugin under `/usr/lib/rdpapplist/`
5. `.dockerignore` now ignores only the root `.git`, not all nested `.git`
6. GitHub Actions workflow was added to build `system_x64.vhd` remotely

## Current GitHub Actions Workflow

Workflow file:

[.github/workflows/build-system-distro.yml](/home/storm/Downloads/wslg-flake/.github/workflows/build-system-distro.yml)

What it does:

1. Checks out `wslg-flake`
2. Clones:
   - `microsoft/FreeRDP-mirror` branch `working`
   - `microsoft/weston-mirror` branch `working`
   - `microsoft/pulseaudio-mirror` branch `working`
   - `https://github.com/3lelele/wsland.git` using input ref or default `master`
3. Downloads Mesa and DirectX-Headers source archives
4. Builds Docker image
5. Exports `system_x64.tar`
6. Converts tar to `system_x64.vhd`
7. Uploads both artifacts

## Confirmed CI Build Failures and Fixes

### Failure 1: `pulseaudio` Meson version parsing crash

Symptom:

`meson.build:17:33: ERROR: Index 1 out of bounds of array of size 1.`

Cause:

The workflow originally used:

`git clone --depth 1 --branch working https://github.com/microsoft/pulseaudio-mirror.git vendor/pulseaudio`

`pulseaudio` uses `git-version-gen` in `meson.build`, and shallow clone did not provide enough Git metadata to derive a valid version string.

Fix:

The workflow now uses a full clone for `pulseaudio` and fetches tags:

```sh
git clone --branch working https://github.com/microsoft/pulseaudio-mirror.git vendor/pulseaudio
git -C vendor/pulseaudio fetch --tags --force
```

### Failure 2: Weston link error for `-lrdpapplist-server`

Symptom:

`/usr/bin/ld: cannot find -lrdpapplist-server`

Cause:

`rdpapplist` installs:

`/usr/lib/rdpapplist/librdpapplist-server.so`

but Weston links against:

`-lrdpapplist-server`

There was no symlink in the standard library directory during Docker build.

Fix:

After installing `rdpapplist`, Dockerfile now creates:

```sh
ln -sf ${DESTDIR}${PREFIX}/lib/rdpapplist/librdpapplist-server.so ${DESTDIR}${PREFIX}/lib/librdpapplist-server.so
```

This mirrors the idea already present in `flake.nix`.

### Failure 3: Docker build context dropped vendor `.git`

Symptom:

Git-based version logic inside Docker failed because nested `.git` directories from `vendor/*` were missing.

Cause:

`.dockerignore` used a broad `.git` rule that also removed nested Git metadata.

Fix:

`.dockerignore` now ignores only top-level Git metadata:

```text
/.git
/.github
/.gitlab
/.gitlab-ci
/.vs
/out
/tmp
```

## Important Limitations

### IME / `text-input-unstable-v3` is still not implemented

This work does **not** complete JetBrains IME support yet.

`wsland` currently does not implement:

- `text-input-unstable-v3`
- `input-method`
- virtual keyboard plumbing

At time of writing, [protocol/meson.build](/home/storm/Downloads/wsland/protocol/meson.build) only generates:

- `xdg-shell`
- `pointer-constraints`

So even once the VHD builds and boots successfully, JetBrains Wayland IME behavior may still be incomplete.

## How To Use The Generated `system_x64.vhd`

After GitHub Actions successfully builds and you download `system_x64.vhd`:

1. Place it somewhere on Windows, for example:
   `C:\WSL\system_x64.vhd`
2. Put this in `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
systemDistro=C:\\WSL\\system_x64.vhd
```

3. Ensure `C:\ProgramData\Microsoft\WSL\.wslgconfig` contains:

```ini
[system-distro-env]
WSLG_USE_WSLAND=1
```

4. Run from Windows:

```powershell
wsl --shutdown
```

5. Re-enter the WSL distro

At that point WSL should boot using the custom system distro and try to launch `wsland`.

## Recommended Next Debug Order

If the CI build fails again:

1. Fix CI build until `system_x64.vhd` artifact is produced
2. Boot the custom system distro
3. Confirm `WSLGd` launches `wsland`
4. Confirm Wayland and XWayland apps start
5. Only then start implementing IME protocol support in `wsland`

If the boot succeeds but apps fail:

1. Inspect system distro logs:
   - `/mnt/wslg/stderr.log`
   - `/mnt/wslg/weston.log` or equivalent compositor logs
2. Check whether `WAYLAND_DISPLAY=wayland-0` is visible in the user distro
3. Check whether `wsland` sent ready notify and accepted RDP/vsock connections

## Most Relevant Files For Future Sessions

### `wslg-flake`

- [Dockerfile](/home/storm/Downloads/wslg-flake/Dockerfile)
- [WSLGd/main.cpp](/home/storm/Downloads/wslg-flake/WSLGd/main.cpp)
- [.github/workflows/build-system-distro.yml](/home/storm/Downloads/wslg-flake/.github/workflows/build-system-distro.yml)
- [build-and-export.sh](/home/storm/Downloads/wslg-flake/build-and-export.sh)
- [flake.nix](/home/storm/Downloads/wslg-flake/flake.nix)

### `wsland`

- [meson.build](/home/storm/Downloads/wsland/meson.build)
- [src/main.c](/home/storm/Downloads/wsland/src/main.c)
- [src/utils/config.c](/home/storm/Downloads/wsland/src/utils/config.c)
- [src/server/server.c](/home/storm/Downloads/wsland/src/server/server.c)
- [src/freerdp/freerdp.c](/home/storm/Downloads/wsland/src/freerdp/freerdp.c)
- [protocol/meson.build](/home/storm/Downloads/wsland/protocol/meson.build)

