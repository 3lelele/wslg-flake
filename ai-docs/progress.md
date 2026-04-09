# Progress Log

## Validation Summary

As of `2026-04-09`:

- `%USERPROFILE%\\.wslconfig` points at the custom `system_x64.vhd`
- the effective config file for the running `WSLGd` is `%USERPROFILE%\\.wslgconfig`
- the custom `WSLGd` build is confirmed to be running
- `WSLGd` is confirmed to take the `wsland` branch when `WSLG_USE_WSLAND=1`
- the previous `librdpapplist-server.so` runtime lookup failure is fixed in the rebuilt image
- `wsland` now starts, initializes Wayland/Xwayland, and stays alive past compositor startup
- additional `wsland` runtime logs were added for RDPGFX capability negotiation, surface lifecycle, and frame acknowledgement
- the extra `wsland` runtime diagnostics are now gated behind `WSLAND_TRACE_RUNTIME=1`
- visibility diagnostics can now also be steered from `%USERPROFILE%\\.wslgconfig` with `WSLAND_DISABLE_GFX_ALPHA=1` and `WSLAND_DISABLE_LAYERED_STYLE=1`
- a real Wayland app (`weston-terminal`) is confirmed to create a window, create/map a surface, send frames, and receive frame acknowledgements
- output layout/work-area mismatches were identified and fixed in `wsland`
- the current remaining suspicion is no longer startup, routing, or ack; it is window visibility at the final composition/presentation layer, with alpha handling now the leading suspect

## Timeline

### Stage 1: user distro environment looked correct

Observed inside Arch:

```sh
echo "$WAYLAND_DISPLAY"   # wayland-0
echo "$DISPLAY"           # :0
echo "$PULSE_SERVER"      # unix:/mnt/wslg/PulseServer
```

This proved WSLg environment injection was active, but did not prove `wsland` was in use.

### Stage 2: logs showed Weston was still launching

Evidence from `/mnt/wslg/stderr.log`:

```text
[00:27:28.935] <5>WSLGd: main:420: Launching weston compositor.
```

Evidence from `/mnt/wslg/weston.log`:

```text
Command line: /usr/bin/weston --backend=rdp-backend.so --modules=wslgd-notify.so --xwayland --socket=wayland-0 --shell=rdprail-shell.so --log=/mnt/wslg/weston.log --logger-scopes=log,rdp-backend,rdprail-shell
```

Conclusion at that point:

- display/audio injection worked
- custom compositor path had not taken effect yet

### Stage 3: added a custom `WSLGd` build marker

Commit:

- `ff65444` `Add WSLGd custom build marker logs`

Purpose:

- prove whether the running system distro really contains the modified `WSLGd`
- log the observed value of `WSLG_USE_WSLAND`

Expected marker lines:

```text
Custom build marker: wslg-flake custom build 2026-04-09
WSLG_USE_WSLAND=1
Launching wsland compositor (wslg-flake custom build 2026-04-09).
```

### Stage 4: custom `WSLGd` confirmed, but env file location mattered

Observed later:

```text
[01:01:15.760] <5>WSLGd: main:427: Launching weston compositor (wslg-flake custom build 2026-04-09).
```

This proved the custom VHD was running, but the `wsland` branch still was not selected.

Root cause:

- the active `WSLGd` reads `%USERPROFILE%\\.wslgconfig`
- it should not be assumed that `C:\\ProgramData\\Microsoft\\WSL\\.wslgconfig` is the active source

### Stage 5: `WSLGd` finally launched `wsland`

Observed:

```text
[01:04:08.351] <5>WSLGd: main:424: Launching wsland compositor (wslg-flake custom build 2026-04-09).
```

This was the first successful proof that:

- the custom `WSLGd` branch worked
- the config was propagated correctly

### Stage 6: `wsland` failed at runtime on `rdpapplist`

Observed immediately after launch:

```text
/usr/bin/wsland: error while loading shared libraries: librdpapplist-server.so: cannot open shared object file: No such file or directory
```

Inspection from the system distro showed:

```sh
ls -l /usr/lib/librdpapplist-server.so
ls -l /usr/lib/rdpapplist/librdpapplist-server.so
ldd /usr/bin/wsland | grep rdpapplist
```

and the broken symlink was:

```text
/usr/lib/librdpapplist-server.so -> /work/build/usr/lib/rdpapplist/librdpapplist-server.so
```

while the real runtime library existed at:

```text
/usr/lib/rdpapplist/librdpapplist-server.so
```

`ldd` confirmed:

```text
librdpapplist-server.so => not found
```

### Stage 7: fixed the runtime symlink in the build recipe

Commit:

- `26b35d6` `Fix rdpapplist runtime symlink for wsland`

Fix:

- changed the Dockerfile symlink target from a build-time absolute path to a runtime-valid relative path

### Stage 8: rebuilt image validated, `wsland` now starts

Observed from `/mnt/wslg/stderr.log`:

```text
[09:43:53.381] <5>WSLGd: main:433: Launching wsland compositor (wslg-flake custom build 2026-04-09).
00:00:00.000 [INFO] [backend/headless/backend.c:60] Creating headless backend
00:00:00.000 [ERROR] [render/wlr_renderer.c:100] drmGetDevices2 failed: No such file or directory
00:00:00.000 [INFO] [render/pixman/renderer.c:328] Creating pixman renderer
00:00:00.008 [INFO] [../src/server/server.c:303] [server] running wayland compositor [ DISPLAY=:0, WAYLAND_DISPLAY=wayland-0 ]
00:00:00.112 [INFO] [xwayland/server.c:107] Starting Xwayland on :0
```

This proved:

- the rebuilt image no longer hits the old `librdpapplist-server.so` loader failure
- `WSLGd` launches `wsland`
- `wsland` survives long enough to initialize Wayland and Xwayland

Remaining warnings seen during this stage:

- wlroots falls back to the pixman renderer after `drmGetDevices2 failed`
- several `rdpgfx` capability versions are logged as `UNKNOWN(...)`
- dbus still warns about `XDG_RUNTIME_DIR` mode `040777`

### Stage 9: added targeted `wsland` runtime diagnostics

Additional logs were added in the `wsland` tree to make the next validation round much more precise.

Coverage added:

- RDPGFX capability advertise and confirm
- peer activate settings and monitor layout
- output creation
- surface create/map/delete lifecycle
- frame send, pixel upload, and frame acknowledge
- backlog-based frame skipping

Control:

- enable with `WSLAND_TRACE_RUNTIME=1` in `%USERPROFILE%\\.wslgconfig`
- leave it unset for normal use to keep logs quiet

These logs are intended to answer the next blocking question:

- is `wsland` successfully negotiating graphics and sending frames to the RDP client, or only reaching compositor startup

### Stage 10: `weston-terminal` proved the base remoting path is alive

Observed from `/mnt/wslg/stderr.log` after launching `weston-terminal`:

```text
Wayland map: title=Wayland Terminal ...
Window create: id=1 ... show=5 ... size=726x587 ...
Surface created: window_id=1 surface_id=1 size=726x587
Surface mapped: window_id=1 surface_id=1 mapped=726x587 target=726x587
Start frame: frame_id=3 windows=1
Frame acknowledged: frame_id=3 current=5
```

This proved:

- a real Wayland toplevel is created inside `wsland`
- the corresponding RAIL window is created with a visible state
- an RDPGFX surface is created and mapped
- frames are sent
- the Windows side acknowledges those frames

At this stage the problem was no longer:

- compositor startup
- missing window creation
- missing surface creation
- lack of frame delivery
- lack of frame acknowledgement

### Stage 11: output layout and work-area binding bug found and fixed

Earlier diagnostic logs showed an output/work-area mismatch, for example:

```text
Work area update: pos=3840,0 size=1920x1032
Work area applied to output: monitor=0,0 3840x2160
Wayland center: ... output=3840,0 1920x1080 work=0,0 3840x2112 ...
```

Root cause:

- `wlr_output_layout_add_auto(...)` placed outputs in a layout that did not preserve the remote monitor coordinates
- `wsland_output_create()` emitted `new_output` before monitor geometry had been assigned

Fixes made in `wsland`:

- bind outputs into `wlr_output_layout` using the explicit remote monitor coordinates
- initialize `output->monitor` before output registration

After the fix, logs became consistent:

```text
Bind output layout: name=wsland-1 monitor=3840,0 1920x1080
Bind output layout: name=wsland-2 monitor=0,0 3840x2160
Work area update: pos=3840,0 size=1920x1032
Work area applied to output: monitor=3840,0 1920x1080
Work area update: pos=0,0 size=3840x2112
Work area applied to output: monitor=0,0 3840x2160
Wayland center: title=Wayland Terminal output=0,0 3840x2160 work=0,0 3840x2112 ...
```

This removed output-layout mismatch as the primary suspect.

### Stage 12: current leading suspicion is alpha/layered presentation

Current state after the output-layout fix:

- `weston-terminal` is still not visible on the Windows desktop
- it still appears in the taskbar
- RAIL window creation, surface mapping, frame sending, and frame acknowledgement all continue to succeed

Current leading hypothesis:

- the final visibility problem is likely in alpha handling or layered-window semantics rather than in startup, geometry, or transport

Additional diagnostic support added:

- `WSLAND_TRACE_RUNTIME=1` now also enables `Surface alpha range: ... min=... max=...`
- `WSLAND_DISABLE_GFX_ALPHA=1` skips the `RDPGFX_CODECID_ALPHA` upload path
- `WSLAND_DISABLE_LAYERED_STYLE=1` removes `WS_EX_LAYERED` from the created RAIL window

This should distinguish:

- fully transparent content (`min=0 max=0`)
- fully opaque content (`min=255 max=255`)
- mixed alpha content (`min=0 max=255` or similar)

These toggles are set in `%USERPROFILE%\\.wslgconfig` under:

```ini
[system-distro-env]
WSLG_USE_WSLAND=1
WSLAND_TRACE_RUNTIME=1
```

and then optionally:

```ini
WSLAND_DISABLE_GFX_ALPHA=1
WSLAND_DISABLE_LAYERED_STYLE=1
```

## Current Blocker

The current known blocker before IME work continues is:

- determine why a window that is already created, mapped, framed, and acknowledged still does not become visible on the Windows desktop
- validate whether the remaining issue is in alpha handling / layered presentation semantics

## Recommended Next Validation

After rebuilding `wsland` with the latest runtime logs and replacing the VHD:

```sh
sed -n '1,80p' /mnt/wslg/stderr.log
sed -n '1,80p' /mnt/wslg/weston.log
```

Success criteria:

- `stderr.log` shows `Launching wsland compositor (wslg-flake custom build 2026-04-09).`
- the old shared-library error is gone
- `stderr.log` shows `running wayland compositor` and `Starting Xwayland on :0`
- when an app is launched, the log shows `Window create`, `Surface created`, `Surface mapped`, `Start frame`, and `Frame acknowledged`
- `Bind output layout`, `Work area update`, and `Wayland center` are internally consistent for the same monitor
- `Surface alpha range` identifies whether the window content is being sent as transparent or opaque
