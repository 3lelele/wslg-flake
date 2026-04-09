# Build And Runtime Notes

## Important Code Changes Already Made

### In `wsland`

Files changed:

- [meson.build](/home/storm/Downloads/wsland/meson.build)
- [include/wsland/utils/config.h](/home/storm/Downloads/wsland/include/wsland/utils/config.h)
- [src/utils/config.c](/home/storm/Downloads/wsland/src/utils/config.c)
- [src/server/server.c](/home/storm/Downloads/wsland/src/server/server.c)

What changed:

1. `wsland` is installed by Meson with `install: true`
2. `wsland` accepts a fixed `WAYLAND_DISPLAY` name from env instead of always auto-allocating
3. `wsland` accepts `WSLGD_NOTIFY_SOCKET` and sends a ready notification to `WSLGd`

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

1. `WSLGd` supports `WSLG_USE_WSLAND=1`
2. When enabled, `WSLGd` launches `/usr/bin/wsland` instead of `/usr/bin/weston`
3. The Docker build builds `vendor/wsland`
4. `rdpapplist` installs a compatibility symlink for `librdpapplist-server.so`
5. `.dockerignore` ignores only the root `.git`, not all nested `.git`
6. GitHub Actions can build `system_x64.vhd` remotely

## GitHub Actions Workflow

Workflow file:

- [.github/workflows/build-system-distro.yml](/home/storm/Downloads/wslg-flake/.github/workflows/build-system-distro.yml)

What it does:

1. Checks out `wslg-flake`
2. Clones:
   `microsoft/FreeRDP-mirror` branch `working`
   `microsoft/weston-mirror` branch `working`
   `microsoft/pulseaudio-mirror` branch `working`
   `https://github.com/3lelele/wsland.git` using input ref or default `master`
3. Downloads Mesa and DirectX-Headers source archives
4. Builds Docker image
5. Exports `system_x64.tar`
6. Converts tar to `system_x64.vhd`
7. Uploads both artifacts

### Current Trigger Policy

The current workflow already behaves close to the desired split:

- `push` runs only on `main`
- `workflow_dispatch` is available for manual builds

Current recommendation:

- keep automatic builds only on `main`
- use manual `workflow_dispatch` for `feature/wsland-ime` or other experimental branches

This means no immediate workflow file change is required just to support the IME branch strategy.

### When Manual Builds Should Be Used

For IME work:

- do not add automatic builds on every IME branch push yet
- only run Actions manually after the base `wsland` integration path is stable enough to validate IME behavior

Reason:

- the current bottleneck is still `wsland` runtime stability
- running full VHD builds for every IME iteration would be expensive and low-signal before the base compositor path is reliable

### Important Detail About Manual Runs

There are two separate cases:

1. If the IME work lives in a `wslg-flake` branch such as `feature/wsland-ime`

- run `workflow_dispatch` from that branch in GitHub Actions

2. If the IME work lives in a `wsland` branch

- use the existing `wsland_ref` input to build that branch manually

Because the workflow already supports both `push` on `main` and manual dispatch with a `wsland_ref` input, it does not currently need to be changed for this branch strategy.

## Confirmed Build Failures And Fixes

### Failure 1: `pulseaudio` Meson version parsing crash

Symptom:

`meson.build:17:33: ERROR: Index 1 out of bounds of array of size 1.`

Cause:

The workflow used a shallow clone for `pulseaudio`, but `git-version-gen` in `meson.build` required fuller Git metadata.

Fix:

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

Fix:

Create a compatibility symlink in `/usr/lib`.

### Failure 3: Docker build context dropped vendor `.git`

Symptom:

Git-based version logic inside Docker failed because nested `.git` directories from `vendor/*` were missing.

Cause:

`.dockerignore` used a broad `.git` rule that also removed nested Git metadata.

Fix:

`.dockerignore` now ignores only top-level Git metadata.

### Failure 4: `wsland` runtime failed to load `librdpapplist-server.so`

Symptom:

`/usr/bin/wsland: error while loading shared libraries: librdpapplist-server.so: cannot open shared object file: No such file or directory`

Cause:

The symlink inside the built system distro pointed at the build-time absolute path:

`/work/build/usr/lib/rdpapplist/librdpapplist-server.so`

instead of a runtime-valid path under `/usr/lib`.

Fix:

In [Dockerfile](/home/storm/Downloads/wslg-flake/Dockerfile), create the symlink as:

```sh
ln -sf rdpapplist/librdpapplist-server.so ${DESTDIR}${PREFIX}/lib/librdpapplist-server.so
```

This becomes a runtime-valid relative symlink after installation.

## How To Use The Generated `system_x64.vhd`

After GitHub Actions successfully builds and you download `system_x64.vhd`:

1. Place it somewhere on Windows, for example:
   `C:\WSL\system_x64.vhd`
2. Put this in `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
systemDistro=C:\\WSL\\system_x64.vhd
```

3. Ensure `%USERPROFILE%\.wslgconfig` contains:

```ini
[system-distro-env]
WSLG_USE_WSLAND=1
```

If you want the extra `wsland` runtime diagnostics enabled during debugging, use:

```ini
[system-distro-env]
WSLG_USE_WSLAND=1
WSLAND_TRACE_RUNTIME=1
```

Keep `WSLAND_TRACE_RUNTIME` unset in normal use to avoid verbose logs.

For visibility debugging, the same `%USERPROFILE%\.wslgconfig` file can also carry these temporary switches:

```ini
[system-distro-env]
WSLG_USE_WSLAND=1
WSLAND_TRACE_RUNTIME=1
WSLAND_DISABLE_GFX_ALPHA=1
WSLAND_DISABLE_LAYERED_STYLE=1
```

Meaning:

- `WSLAND_DISABLE_GFX_ALPHA=1`
  Skip the `RDPGFX_CODECID_ALPHA` surface command and send only the uncompressed pixel surface command.
- `WSLAND_DISABLE_LAYERED_STYLE=1`
  Create the RAIL window without `WS_EX_LAYERED`.

Recommended diagnostic order:

1. Baseline:
   only `WSLG_USE_WSLAND=1` and `WSLAND_TRACE_RUNTIME=1`
2. Alpha command off:
   add `WSLAND_DISABLE_GFX_ALPHA=1`
3. Layered style off:
   remove the previous switch and add `WSLAND_DISABLE_LAYERED_STYLE=1`
4. Both off:
   set both `WSLAND_DISABLE_GFX_ALPHA=1` and `WSLAND_DISABLE_LAYERED_STYLE=1`

Expected log signatures in `/mnt/wslg/stderr.log`:

- normal alpha path:
  `Surface command alpha: ...`
- alpha upload disabled:
  `Surface command alpha skipped: ...`

Leave the `WSLAND_DISABLE_*` switches unset outside targeted debugging so normal behavior remains unchanged.

4. Run from Windows:

```powershell
wsl --shutdown
```

5. Re-enter the WSL distro

At that point WSL should boot using the custom system distro and try to launch `wsland`.

## Recommended Validation Order

If CI build fails again:

1. Fix CI until `system_x64.vhd` artifact is produced
2. Boot the custom system distro
3. Confirm `WSLGd` launches `wsland`
4. Confirm Wayland and XWayland apps start
5. Only then continue IME protocol work in `wsland`

If boot succeeds but apps fail:

1. Inspect:
   `/mnt/wslg/stderr.log`
   `/mnt/wslg/weston.log`
2. Check whether `WAYLAND_DISPLAY=wayland-0` is visible in the user distro
3. Check whether `wsland` sent ready notify and accepted RDP/vsock connections

## Current Runtime Validation Signals

### Expected startup signals

After a good rebuild and `wsl --shutdown`, `/mnt/wslg/stderr.log` should show at least:

```text
Launching wsland compositor (wslg-flake custom build 2026-04-09).
[server] running wayland compositor [ DISPLAY=:0, WAYLAND_DISPLAY=wayland-0 ]
Starting Xwayland on :0
```

These lines prove:

- the custom `WSLGd` build is active
- `%USERPROFILE%\\.wslgconfig` was applied well enough to take the `wsland` branch
- `wsland` survived compositor startup and initialized Xwayland

### Warnings currently known but not yet treated as the primary blocker

The following lines have been observed during successful `wsland` startup and are not, by themselves, proof of the current blocker:

- `drmGetDevices2 failed: No such file or directory`
- `Creating pixman renderer`
- `Xwayland glamor: GBM Wayland interfaces not available`
- `dbus ... XDG_RUNTIME_DIR "/mnt/wslg/runtime-dir" can be written by others (mode 040777)`
- `Version : UNKNOWN(...)` from `rdpgfx`

They still matter, but they do not invalidate the narrower conclusion that `wsland` now launches.

### Additional `wsland` logs added for the next validation round

The `wsland` tree now includes runtime logs for:

- RDPGFX capability advertise and confirm
- activate-time client settings and monitor layout
- output creation
- output-layout binding and work-area application
- Wayland/XWayland map and centering
- RAIL window create/update state
- surface create/map/delete
- frame start/end
- alpha/pixel surface commands
- alpha min/max summary
- frame acknowledge and backlog-driven frame skipping

These logs are gated by `WSLAND_TRACE_RUNTIME=1` in `%USERPROFILE%\.wslgconfig`.

The visibility-specific toggles also come from `%USERPROFILE%\.wslgconfig` under `[system-distro-env]`:

- `WSLAND_DISABLE_GFX_ALPHA=1`
- `WSLAND_DISABLE_LAYERED_STYLE=1`

When testing an actual app launch, use these lines to classify the failure:

- if `RDPGFX caps advertise` never appears, graphics negotiation did not complete
- if capabilities appear but no `Surface created` appears, window-to-surface mapping is failing
- if surfaces appear but no `Start frame` or `Surface command pixels` appears, rendering or damage collection is failing
- if frames are sent but no `Frame acknowledged` appears, the client is not acknowledging delivered frames
- if `Work area applied to output` and `Wayland center` refer to different monitors, output-layout binding is still wrong
- if `Window create` shows a visible window with sane position/size and frames are acknowledged but the window is still invisible, inspect `Surface alpha range`
- if `Surface alpha range` is `min=0 max=0`, the content is effectively being sent as fully transparent
