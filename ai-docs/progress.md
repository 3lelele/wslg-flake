# Progress Log

## 2026-04-11: Switched to qq1038765585 upstream

### Decision

Abandoned our fork's RAIL alignment / alpha debugging approach in favor of qq1038765585's upstream wsland code. The decisive factor: qq's implementation has **GfxRedir** (Graphics Redirection) support, which provides zero-copy rendering via shared memory and completely bypasses the RDPGFX alpha codec path that caused the invisible-window blocker.

### Actions

- wsland: `archive/our-rail-fixes` branch preserves our 49 commits; `master` reset to upstream `working` (`540358f`)
- wslg-flake: `archive/our-wslg-fixes` branch preserves our 320 commits; `main` reset to upstream `main` (`8fb0147`)
- Both repos pushed to origin

### Current state

Both repos are now synced with qq's upstream. The next milestone is to build the VHD and validate that windows are visible on the Windows desktop.

### Previous progress (2026-04-09 to 2026-04-10)

All previous progress is preserved in `archive/our-rail-fixes` and `archive/our-wslg-fixes` branches. Key findings from that period:

- Custom WSLGd build confirmed running, `wsland` branch selectable via `WSLG_USE_WSLAND=1`
- `wsland` successfully starts Wayland + XWayland
- `weston-terminal` creates RAIL window, maps RDPGFX surface, sends frames, receives acknowledgements
- Window remains invisible on Windows desktop despite all of the above
- Single-factor causes ruled out: `RDPGFX_CODECID_ALPHA`, `WS_EX_LAYERED`, title-only updates, `WINDOW_ORDER_FIELD_OWNER`
- Multiple RAIL window state fixes aligned with `microsoft/weston-mirror` `rdprail.c`
- Root cause identified (retroactively): missing GfxRedir support meant relying on RDPGFX alpha codec path which has incompatible semantics with msrdc.exe

## Current Blocker

None. The upstream code should resolve the invisible-window issue via GfxRedir. Need to build and validate.

## Recommended Next Validation

1. Build `system_x64.vhd` using `DockerfileArch`
2. Boot with the custom system distro
3. Launch a GUI app and confirm it's visible on the Windows desktop
4. Launch JetBrains IDEA and confirm it works
5. Begin IME implementation
