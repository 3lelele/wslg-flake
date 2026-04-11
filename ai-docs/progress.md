# Progress Log

## 2026-04-11: Switched to qq1038765585 upstream

### Decision

Abandoned our fork's RAIL alignment / alpha debugging approach in favor of qq1038765585's upstream wsland code. The decisive factor: qq's implementation has **GfxRedir** (Graphics Redirection) support, which provides zero-copy rendering via shared memory and completely bypasses the RDPGFX alpha codec path that caused the invisible-window blocker.

### Actions

- wsland: `archive/our-rail-fixes` branch preserves our 49 commits; `master` reset to upstream `working` (`540358f`)
- wslg-flake: `archive/our-wslg-fixes` branch preserves our 320 commits; `main` reset to upstream `main` (`8fb0147`)
- Both repos pushed to origin
- Added GitHub Actions workflow for building VHD via DockerfileArch
- Fixed two `#RUN` comment bugs in DockerfileArch (build-env and runtime stages)
- Fixed Arch package names: `xcb` → `libxcb`, removed duplicate `xwayland`

### VHD Build Succeeded, Windows Still Invisible

After building VHD from qq's upstream code and booting with it:
- **All windows invisible** — same symptom as before (taskbar icon only, no window)
- Confirmed with: weston-terminal, xeyes, Firefox, IntelliJ IDEA
- Initially thought IDEA was working, but it was the Windows-native IDEA

### Root Cause: GfxRedir Not Activated

**GfxRedir (the zero-copy rendering path) is NOT available on this WSL setup:**
- `/mnt/shared_memory` does not exist — the virtiofs mount point is not created
- `WSL2_SHARED_MEMORY_MOUNT_POINT` env var is not set
- Without shared memory, `config_gfxredir()` in wsland sets `use_gfxredir = false`
- ALL rendering falls back to RDPGFX alpha codec path → same invisible window bug

The GfxRedir path likely works on qq's machine due to different WSL/Windows version or configuration.

### RDPGFX Path Analysis

Compared wsland's RDPGFX rendering with microsoft/weston-mirror rdprail.c. Found multiple mismatches (see `rdpgfx-invisible-window.md` for full details):

1. **Window show state lifecycle wrong**: wsland doesn't do the required HIDE→SHOW two-step transition
2. **WindowCreate missing critical fields**: WND_OFFSET, WND_SIZE, WND_RECTS, VISIBILITY, SHOW, TASKBAR_BUTTON all missing
3. **Window rects use wrong coordinates**: (0,0) origin instead of actual screen position
4. **TaskbarButton semantics inverted**: top-level windows get 0 instead of 1
5. **clientAreaHeight missing title bar adjustment**
6. **Missing MinMaxInfo on show transition**
7. **HiDefRemoteApp not set in peer settings**

## Current Blocker

Same as before: invisible windows when using RDPGFX rendering path. GfxRedir is not available on this WSL version.

## Next Steps

1. **Build baseline VHD using Dockerfile (Azure Linux + weston)** to confirm the environment works with the standard WSLg stack
2. Fix wsland's RDPGFX path based on the 7 issues identified
3. Rebuild and validate
