# WSLg + wsland Integration Notes

## Purpose

This repository adapts the default WSLg Weston compositor path to a `wsland`-based path built on `wlroots`.

Immediate goal:

1. Build a custom WSLg system distro VHD from `wslg-flake`
2. Allow `WSLGd` to launch `wsland` instead of `weston`
3. Keep the existing WSLg RDP/vsock boot path working

Final goal:

- JetBrains IDE startup on native Wayland with IME support

That final IME goal is not finished yet.

## Repositories

### `wslg-flake`

Local path:

`/home/storm/Downloads/wslg-flake`

Remote:

`git@github.com:3lelele/wslg-flake.git`

Main files:

- [Dockerfile](/home/storm/Downloads/wslg-flake/Dockerfile)
- [WSLGd/main.cpp](/home/storm/Downloads/wslg-flake/WSLGd/main.cpp)
- [.github/workflows/build-system-distro.yml](/home/storm/Downloads/wslg-flake/.github/workflows/build-system-distro.yml)
- [build-and-export.sh](/home/storm/Downloads/wslg-flake/build-and-export.sh)
- [flake.nix](/home/storm/Downloads/wslg-flake/flake.nix)

### `wsland`

Local path:

`/home/storm/Downloads/wsland`

Remote:

`git@github.com:3lelele/wsland.git`

Main files:

- [meson.build](/home/storm/Downloads/wsland/meson.build)
- [protocol/meson.build](/home/storm/Downloads/wsland/protocol/meson.build)
- [src/main.c](/home/storm/Downloads/wsland/src/main.c)
- [src/server/server.c](/home/storm/Downloads/wsland/src/server/server.c)
- [src/server/handle.c](/home/storm/Downloads/wsland/src/server/handle.c)
- [src/server/wayland.c](/home/storm/Downloads/wsland/src/server/wayland.c)
- [src/server/xwayland.c](/home/storm/Downloads/wsland/src/server/xwayland.c)
- [src/freerdp/freerdp.c](/home/storm/Downloads/wsland/src/freerdp/freerdp.c)

## Key Windows Config

### `%USERPROFILE%\.wslconfig`

Example:

```ini
[wsl2]
systemDistro=C:\\WSL\\system_x64.vhd
```

### `%USERPROFILE%\.wslgconfig`

Current intended content:

```ini
[system-distro-env]
WSLG_USE_WSLAND=1
```

Important:

- The active `WSLGd` build reads `%USERPROFILE%\\.wslgconfig`
- Do not assume `C:\\ProgramData\\Microsoft\\WSL\\.wslgconfig` is the effective file

After replacing/updating the VHD, run:

```powershell
wsl --shutdown
```

Build first, replace/configure VHD second, shutdown last.

## Current State

Current high-level status:

- custom `WSLGd` build is confirmed to be running
- `WSLGd` can be switched to the `wsland` launch branch
- `wsland` startup exposed a runtime `rdpapplist` symlink issue
- a Dockerfile fix for that runtime symlink has already been committed
- IME support is still not implemented in `wsland`

See detailed status and validation history in:

- [ai-docs/progress.md](/home/storm/Downloads/wslg-flake/ai-docs/progress.md)

## Detailed Notes

Build workflow, known fixes, validation flow, and runtime debugging:

- [ai-docs/build-notes.md](/home/storm/Downloads/wslg-flake/ai-docs/build-notes.md)

IME analysis and implementation plan:

- [ai-docs/ime-plan.md](/home/storm/Downloads/wslg-flake/ai-docs/ime-plan.md)

## Current Commits Of Interest

- `ff65444` `Add WSLGd custom build marker logs`
- `26b35d6` `Fix rdpapplist runtime symlink for wsland`
