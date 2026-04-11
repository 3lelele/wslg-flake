# Feasibility Analysis: Adopting qq1038765585's wsland

Date: 2026-04-11

## Background

WSLG's default Weston compositor (v9.0) has many issues with modern Wayland apps, especially JetBrains IDEs. Issue [microsoft/wslg#1432](https://github.com/microsoft/wslg/issues/1432) reports IntelliJ 2026.1 Wayland rendering problems.

User `qq1038765585` commented that Weston 9.0 is too old and difficult to fix, so they chose to use wlroots to replace Weston entirely. Their GIF shows IntelliJ IDEA working correctly in WSL.

Two repos from qq1038765585:
- https://github.com/qq1038765585/wsland (branch: working)
- https://github.com/qq1038765585/wslg-flake (branch: main)

## Repository Relationship

Our wsland fork and qq's wsland share a common ancestor at commit `ef2f1e5` ("save support wayland/xwayland").

- **qq upstream** (31 commits total, 20 after fork): Added GfxRedir, clipboard, server decoration, wlroots 0.20 upgrade, input fixes, popup positioning
- **Our fork** (49 commits total, 37 after fork): Added extensive RAIL window state alignment with weston rdprail, diagnostic logging, alpha/layered debugging switches

## Core Differences

| Aspect | qq upstream (working) | Our fork (master) |
|---|---|---|
| wlroots version | **0.20** (system dependency) | 0.19.3 (meson subproject) |
| GfxRedir support | **Implemented** - shared memory zero-copy rendering | Not implemented |
| Clipboard | **Implemented** - UTF8/BMP/HTML/RTF | Implemented (same code) |
| RAIL window create | One-shot create+show | Two-step: hidden create -> show transition |
| Window state fields | Concise, direct send | Many weston rdprail alignment fixes |
| Diagnostic switches | None | Many (`WSLAND_DISABLE_*`, `WSLAND_TRACE_RUNTIME`) |
| XWayland cursor | Has fix | No fix |
| Popup positioning | Has taskbar avoidance fix | No fix |
| Build method | DockerfileArch (Arch Linux, system wlroots) | Dockerfile (Azure Linux, subproject wlroots) |
| Window visibility | **Working** (IntelliJ verified in screenshots) | **Broken** - window created/framed/acknowledged but invisible |

## Why qq's Approach Works

### 1. GfxRedir Rendering Path (THE KEY DIFFERENCE)

qq implemented the `GFXREDIR` (Graphics Redirection) channel, which is WSLg's zero-copy rendering path:

- Maps window buffers via shared memory (`/mnt/wslg/shared-memory/`)
- Uses `OpenPool` -> `CreateBuffer` -> `PresentBuffer` for frame delivery
- Completely bypasses the RDPGFX surface command + alpha codec path

Our fork lacks GfxRedir and can only use the RDPGFX path (`SurfaceCommand` + `RDPGFX_CODECID_ALPHA` + `RDPGFX_CODECID_UNCOMPRESSED`), which is the root cause of the invisible window problem - the alpha codec / layered window semantics don't behave as expected with msrdc.exe.

### 2. Simpler RAIL Window State

qq's `wsland_window_update` is straightforward: sets all fields at create time, updates size and show state on resize. The complex hidden-create -> show-transition -> geometry-resend logic we added isn't needed because the GfxRedir path has different compositing behavior on the Windows side.

### 3. wlroots 0.20

Better buffer management and rendering API.

## Feasibility Conclusion

**Fully feasible. qq's upstream code is more mature than our current state.**

Reasons:
1. Window visibility problem is solved - GfxRedir completely bypasses the RDPGFX alpha/layered issue that blocked us
2. Code quality is reasonable - clear architecture, well-separated FreeRDP context layers, complete clipboard
3. Already validated end-to-end - IntelliJ IDEA running correctly in WSL proves the full stack works
4. Aligned with our goals - the ultimate goal is JetBrains IDE + IME; qq's approach already validates JetBrains works

## Actions Taken (2026-04-11)

### wsland repo (`~/Downloads/wsland`)

- Created `archive/our-rail-fixes` branch preserving all 49 of our commits
- Reset `master` branch to qq upstream `working` branch (`540358f`)
- Added `upstream` remote pointing to `https://github.com/qq1038765585/wsland.git`
- Both branches pushed to `origin` (git@github-3lelele:3lelele/wsland.git)

### wslg-flake repo (`~/Downloads/wslg-flake`)

- Created `archive/our-wslg-fixes` branch preserving all 320 of our commits
- Reset `main` branch to qq upstream `main` branch (`8fb0147`)
- Added `upstream` remote pointing to `https://github.com/qq1038765585/wslg-flake.git`
- Both branches pushed to `origin` (git@github-3lelele:3lelele/wslg-flake.git)

## Next Steps Plan

### Step 1: Build and validate the upstream system distro VHD

- Use the existing `DockerfileArch` to build the VHD
- This requires: Arch Linux Docker environment, vendor sources (FreeRDP, pulseaudio, wsland)
- The wsland source will be our `master` branch (now synced with qq's working branch)
- Validate: boot WSL with custom system distro, confirm apps appear visibly on Windows desktop

### Step 2: Verify JetBrains IDEA works

- Install JetBrains IDEA in the WSL user distro
- Launch it and confirm the window is visible and interactive
- This validates the GfxRedir path is working end-to-end

### Step 3: Begin IME implementation in wsland

- Create `feature/wsland-ime` branch in wsland repo
- Implement `text-input-unstable-v3` protocol
- Implement `input-method-unstable-v2` protocol
- Add IME focus lifecycle connected to the existing Wayland surface focus path
- See `ime-plan.md` for the detailed phased plan

### Step 4: Validate IME with fcitx5

- Test that fcitx5 can detect and use the IME protocol
- Verify IME input works in native Wayland apps
- Verify IME works in JetBrains IDEA

## Key Code References (qq's upstream)

### GfxRedir rendering flow
- `src/freerdp/context/gfxredir.c` - GfxRedir channel init and caps negotiation
- `src/adapter/handle.c:296-377` - GfxRedir buffer/surface creation on window resize
- `src/adapter/handle.c:712-752` - GfxRedir PresentBuffer frame delivery
- `src/adapter/handle.c:160-178` - GfxRedir buffer/pool destruction

### RDPGFX rendering flow (fallback)
- `src/freerdp/context/rdpgfx.c` - RDPGFX channel init and caps
- `src/adapter/handle.c:346-376` - RDPGFX surface create/map on resize
- `src/adapter/handle.c:753-855` - RDPGFX alpha codec + uncompressed pixel delivery

### Window detection and RAIL state
- `src/adapter/handle.c:380-515` - `wsland_window_detection()` - scene graph scan, RAIL create/update
- `src/adapter/handle.c:181-295` - `wsland_window_update()` - RAIL WindowCreate/WindowUpdate PDU

### FreeRDP integration
- `src/freerdp/handle.c:200-255` - `xf_peer_activate()` - RDP peer activation, RAIL init, output/keyboard creation
- `src/freerdp/handle.c:33-104` - `rail_sync_window_state()` - initial desktop sync PDUs
- `src/freerdp/peer.c` - peer lifecycle and event loop integration

### Build
- `DockerfileArch` - Arch Linux based build, uses system wlroots 0.20
- `meson.build` - wsland depends on `wlroots-0.20`, `freerdp2`, `freerdp-server2`, `rdpapplist`
- `protocol/meson.build` - generates xdg-shell, cursor-shape, pointer-constraints protocols
