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

These logs are intended to answer the next blocking question:

- is `wsland` successfully negotiating graphics and sending frames to the RDP client, or only reaching compositor startup

## Current Blocker

The current known blocker before IME work continues is:

- validate that a real Wayland/X11 application is remoted correctly after `wsland` startup
- determine whether any remaining failure is in RDPGFX capability negotiation, surface mapping, or frame delivery

## Recommended Next Validation

After rebuilding `wsland` with the new runtime logs and replacing the VHD:

```sh
sed -n '1,80p' /mnt/wslg/stderr.log
sed -n '1,80p' /mnt/wslg/weston.log
```

Success criteria:

- `stderr.log` shows `Launching wsland compositor (wslg-flake custom build 2026-04-09).`
- the old shared-library error is gone
- `stderr.log` shows `running wayland compositor` and `Starting Xwayland on :0`
- when an app is launched, the log shows `RDPGFX caps advertise`, `Surface created`, `Start frame`, and `Frame acknowledged`
