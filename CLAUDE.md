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

Optional debugging additions:

```ini
[system-distro-env]
WSLG_USE_WSLAND=1
WSLAND_TRACE_RUNTIME=1
WSLAND_DISABLE_GFX_ALPHA=1
WSLAND_DISABLE_LAYERED_STYLE=1
WSLAND_DISABLE_TITLE_UPDATE=1
WSLAND_DISABLE_OWNER_FIELD=1
```

Meaning:

- `WSLG_USE_WSLAND=1` tells `WSLGd` to launch `wsland` instead of `weston`
- `WSLAND_TRACE_RUNTIME=1` enables detailed `wsland` runtime diagnostics in `/mnt/wslg/stderr.log`
- `WSLAND_DISABLE_GFX_ALPHA=1` skips `RDPGFX_CODECID_ALPHA` uploads and sends only the pixel surface command
- `WSLAND_DISABLE_LAYERED_STYLE=1` creates RAIL windows without `WS_EX_LAYERED`
- `WSLAND_DISABLE_TITLE_UPDATE=1` skips non-create RAIL title update PDUs (diagnostic only)
- `WSLAND_DISABLE_OWNER_FIELD=1` skips `WINDOW_ORDER_FIELD_OWNER` in RAIL window updates (diagnostic only)
- with `WSLAND_TRACE_RUNTIME=1`, `Window create` and `Window update` also log `reason`, `style`, `exstyle`, offsets, client geometry, and rectangle counts for RAIL state debugging

Recommended use:

- leave the two `WSLAND_DISABLE_*` variables unset in normal runs
- only enable them during visibility debugging to isolate alpha-command vs layered-window behavior
- the current "max isolation" debug profile during invisible-window work is:
  `WSLAND_DISABLE_GFX_ALPHA=1`, `WSLAND_DISABLE_LAYERED_STYLE=1`, `WSLAND_DISABLE_TITLE_UPDATE=1`, `WSLAND_DISABLE_OWNER_FIELD=1`

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
- `weston-terminal` is confirmed to create a RAIL window, map an RDPGFX surface, send pixel frames, and receive frame acknowledgements under `wsland`
- the invisible-window issue is no longer suspected to be caused solely by alpha upload, layered style, title-only updates, or owner-field updates; these paths now have dedicated toggles and have been exercised during diagnostics
- multiple `wsland` window-state behaviors have been aligned with `microsoft/weston-mirror` `rdprail.c`, including owner semantics, create/show sequencing, taskbar-state persistence, visibility rect coordinates, and client-area sizing
- IME support is still not implemented in `wsland`

Current branch strategy:

- `main` remains the base integration branch for runtime/build fixes
- `feature/wsland-ime` is reserved for IME protocol work
- IME work should be periodically rebased onto `main`

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
- `b41a58f` `Log detailed RAIL window state transitions`
- `4d9be48` `Add diagnostic switch to skip title-only window updates`
- `17170b6` `Add owner-field diagnostic toggle for RAIL windows`
- `3196ffc` `Align owner/taskbar update semantics with weston rdprail`
- `03d44fd` `Align window-create show/taskbar semantics with weston`
- `d699934` `Send follow-up show update after hidden window create`
- `ec50437` `Fix taskbar state regression in create/title updates`
- `3ace540` `Use absolute rect coordinates for RAIL window visibility`
- `7d8aa56` `Send geometry with initial show sync and restore top-level taskbar state`
- `67837b4` `Align client area height and move updates with weston`
