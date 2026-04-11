# RDPGFX Invisible Window Analysis

Date: 2026-04-11

## Symptom

After building VHD from qq1038765585's upstream code (DockerfileArch), all GUI windows (weston-terminal, xeyes, Firefox, IntelliJ IDEA) exhibit the same problem:

- Taskbar shows a `msrdc.exe` icon for each window
- No visible window content on the Windows desktop
- Clicking the taskbar icon produces no response

This is the same invisible-window symptom encountered with our previous fork.

## Environment

```
WSL version: 2.7.1.0
Kernel: 6.6.114.1-1
WSLg version: 1.0.73
MSRDC version: 1.2.6676
Windows: 10.0.26220.8148
```

Build: DockerfileArch on Arch Linux base, wsland commit `540358f`.

## Key Finding: GfxRedir Not Activated

The GfxRedir (Graphics Redirection) zero-copy rendering path is NOT active. Evidence:

1. `/mnt/wslg/wlog.log` shows accepted channels: `conctrl, rdpdr, rdpsnd, rail, rail_wi, rail_ri, cliprdr, drdynvc` — no `rdpgfx` or `gfxredir` as static channels (these are dynamic channels opened via drdynvc, so this alone is not conclusive)

2. **Shared memory is NOT mounted**: `/mnt/shared_memory` does not exist, `WSL2_SHARED_MEMORY_MOUNT_POINT` env var is not set. WSLGd requires this to activate GfxRedir (see `src/freerdp/freerdp.c:169-195`, `config_gfxredir()`)

3. Without shared memory, `use_gfxredir = false` in wsland, so ALL rendering falls back to the RDPGFX alpha codec path

4. RDPGFX channel IS working (caps advertised in stderr.log), but the RDPGFX rendering path has the invisible-window bug

**Conclusion**: The GfxRedir path that qq's code relies on for working windows is not available on this WSL version/configuration. The RDPGFX fallback path has the same invisible-window bug we encountered before.

## Why GfxRedir Isn't Available

GfxRedir requires:
1. `WSL2_SHARED_MEMORY_OB_DIRECTORY` env var to be set by the WSL runtime
2. WSLGd to mount virtiofs at `/mnt/shared_memory`
3. wsland to verify it can allocate shared memory in that mount

Without the shared memory mount point, `config_gfxredir()` sets `use_gfxredir = false`.

This may work on qq's machine but not ours because of WSL version differences, Windows build differences, or WSL configuration differences.

## RDPGFX Path Root Cause Analysis

Comparison between wsland's RDPGFX path and microsoft/weston-mirror's rdprail.c reveals multiple mismatches:

### Issue 1 (HIGHEST): Window Show State Lifecycle

**Weston**: Creates windows with `showState = WINDOW_HIDE`, then sends a separate WindowUpdate with `showState = WINDOW_SHOW`.

**Wsland** (`src/adapter/handle.c:188-209`): The create branch does NOT include `WINDOW_ORDER_FIELD_SHOW`. The show state is only set in the resize branch (`:222-226`). If create fires without resize, the window is never shown. Even when both fire together, WINDOW_SHOW is sent in the WindowCreate PDU itself — msrdc.exe expects the two-step hide-then-show lifecycle.

### Issue 2 (HIGH): WindowCreate Missing Critical Fields

**Weston** (`rdprail.c:1656-1712`) includes ALL of these in WindowCreate:
- STYLE, OWNER, SHOW, TASKBAR_BUTTON, CLIENT_AREA_OFFSET, CLIENT_AREA_SIZE
- WND_OFFSET, WND_CLIENT_DELTA, WND_SIZE, WND_RECTS, VIS_OFFSET, VISIBILITY

**Wsland** (`handle.c:188-209`) only includes:
- STYLE, OWNER, CLIENT_AREA_OFFSET, WND_CLIENT_DELTA, VIS_OFFSET

Missing: WND_OFFSET, WND_SIZE, WND_RECTS, VISIBILITY, CLIENT_AREA_SIZE, SHOW, TASKBAR_BUTTON

### Issue 3 (HIGH): Window Rects Use Wrong Coordinates

**Weston** uses actual screen position for window_rect/vis_rect (rdprail.c:1651-1654).

**Wsland** (`handle.c:236-252`) uses `(0, 0)` as origin for all rects. The RDP client may calculate incorrect position/clipping.

### Issue 4 (MEDIUM): TaskbarButton Semantics Inverted

**Weston**: `TaskbarButton = 1` on create (show in taskbar while hidden), `TaskbarButton = 0` on show (window is visible).

**Wsland** (`handle.c:226`): `TaskbarButton = data->window->parent_id ? 1 : 0` — inverted logic for top-level windows.

### Issue 5 (MEDIUM): clientAreaHeight Missing Title Bar Adjustment

**Weston** (`rdprail.c:2413-2414`): subtracts 8 from clientAreaHeight when not fullscreen.

**Wsland** (`handle.c:229-230`): sets clientAreaHeight equal to full window height.

### Issue 6 (MEDIUM): Missing MinMaxInfo on Show Transition

**Weston** sends MinMaxInfo when transitioning HIDE → SHOW (rdprail.c:2251-2253).

**Wsland** only sends MinMaxInfo on create (handle.c:280-294).

### Issue 7 (LOWER): HiDefRemoteApp Not Set

**Weston** guards window creation on `settings->HiDefRemoteApp` being TRUE.

**Wsland** never sets `HiDefRemoteApp = TRUE` in peer settings.

## Two Possible Paths Forward

### Path A: Fix the RDPGFX rendering path in wsland

Apply fixes for Issues 1-7 above in `src/adapter/handle.c` and `src/freerdp/peer.c`. This would make wsland work without GfxRedir, which is necessary since GfxRedir is not available on all WSL configurations.

This is essentially what we were doing in our `archive/our-rail-fixes` branch — aligning RAIL window state with weston's rdprail.c. The difference now is we have a clearer understanding of which specific fields and lifecycle steps matter.

### Path B: Try building with the original Dockerfile (Azure Linux + weston baseline)

Create a GitHub Action using the original `Dockerfile` to build a standard WSLg VHD with weston. This serves as a baseline test:
- If the weston-based VHD shows windows correctly → confirms the issue is wsland-specific
- If it also doesn't show windows → the issue is environmental, not wsland-specific

The Dockerfile uses Azure Linux and builds: DirectX-Headers, mesa, pulseaudio, FreeRDP, weston, WSLGd.

### Recommended: Both paths

1. Build baseline VHD with Dockerfile (weston) to confirm the environment works
2. Fix wsland's RDPGFX path based on Issues 1-7
3. Rebuild wsland VHD with DockerfileArch and verify

## GfxRedir Activation Requirements

For future reference, GfxRedir activation requires:

1. WSL runtime sets `WSL2_SHARED_MEMORY_OB_DIRECTORY` env var
2. WSLGd reads this and mounts virtiofs at `/mnt/shared_memory`
3. WSLGd sets `WSL2_SHARED_MEMORY_MOUNT_POINT=/mnt/shared_memory`
4. WSLGd passes `/wslgsharedmemorypath:` to msrdc.exe
5. wsland's `config_gfxredir()` reads `WSL2_SHARED_MEMORY_MOUNT_POINT`
6. wsland verifies it can allocate shared memory at that mount point
7. Only then does `freerdp->use_gfxredir = true`

If any step fails, GfxRedir is disabled and all rendering falls back to RDPGFX alpha codec.
