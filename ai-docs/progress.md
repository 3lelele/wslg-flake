# Progress Log

## Validation Summary

As of `2026-04-09`:

- `%USERPROFILE%\\.wslconfig` points at the custom `system_x64.vhd`
- the effective config file for the running `WSLGd` is `%USERPROFILE%\\.wslgconfig`
- the custom `WSLGd` build is confirmed to be running
- `WSLGd` is confirmed to take the `wsland` branch when `WSLG_USE_WSLAND=1`
- `wsland` startup then failed on a runtime library lookup issue
- that runtime symlink issue has been fixed in the build recipe, but needs rebuild/redeploy validation

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

## Current Blocker

The current known blocker before IME work continues is:

- rebuild and redeploy a VHD that contains commit `26b35d6`
- confirm `wsland` starts without the `librdpapplist-server.so` runtime failure

## Recommended Next Validation

After rebuilding and replacing the VHD:

```sh
sed -n '1,80p' /mnt/wslg/stderr.log
sed -n '1,80p' /mnt/wslg/weston.log
```

Success criteria:

- `stderr.log` shows `Launching wsland compositor (wslg-flake custom build 2026-04-09).`
- the old shared-library error is gone
- `wsland` remains alive long enough to create the expected display/socket path
