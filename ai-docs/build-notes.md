# Build And Runtime Notes

## Current Build: qq1038765585 upstream

### Build method: DockerfileArch

The upstream uses `DockerfileArch` which builds on Arch Linux with system packages:

Key dependencies (all from Arch packages):
- `wlroots0.20` - system package, not subproject build
- `xorg-xwayland` - system package
- `meson`, `ninja`, `cmake`, `clang`, `pkg-config` - build tools
- `cairo`, `pixman`, `libxkbcommon`, `openssl`, `xcb`, `pango` - rendering/input
- `wayland-protocols` - protocol XMLs

Build order:
1. PulseAudio (from vendor/pulseaudio)
2. Mesa (from vendor/mesa)
3. FreeRDP (from vendor/FreeRDP or vendor/freerdp)
4. rdpapplist (from rdpapplist/)
5. wsland (from vendor/wsland) - uses system wlroots 0.20
6. WSLGd (from WSLGd/)

### WSLGd changes (vs microsoft/wslg upstream)

qq's WSLGd always launches `/usr/bin/wsland` instead of `/usr/bin/weston`:
- No `WSLG_USE_WSLAND` toggle needed - wsland is the default
- Passes `-s wayland-0` for fixed socket name
- Passes `-l` for log file path
- Sends ready notification via `WSLAND_NOTIFY_SOCKET`

### wsland meson.build dependencies

```
dep_wlroots = dependency('wlroots-0.20', version : '>=0.20.0')
dep_xwayland = dependency('xwayland', version : '>=24.1.9')
dep_winpr = dependency('winpr2', version : '>=2.4.0')
dep_freerdp = dependency('freerdp2', version : '>=2.4.0')
dep_freerdp_server = dependency('freerdp-server2', version : '>=2.4.0')
dep_rdpapplist = dependency('rdpapplist', version: '>= 2.0.0', required: false)
dep_wayland_server = dependency('wayland-server', version : '>= 1.24.0')
dep_xkbcommon = dependency('xkbcommon', version : '>=1.11.0')
dep_openssl = dependency('openssl', version: '>= 1.1.1')
dep_pixman = dependency('pixman-1', version : '>=0.46.4')
dep_xcb = dependency('xcb', version : '>=1.17.0')
dep_xcb_icccm = dependency('xcb-icccm', version : '>=0.4.2')
```

Note: wlroots is a system dependency (`wlroots-0.20`), NOT a subproject wrap. This differs from our old approach.

### Protocol support

Current protocols generated in `protocol/meson.build`:
- `xdg-shell` (stable)
- `cursor-shape-v1` (staging)
- `pointer-constraints-unstable-v1` (unstable)

NOT yet supported:
- `text-input-unstable-v3`
- `input-method-unstable-v2`
- `virtual-keyboard-v1`

## How To Build The VHD

Using DockerfileArch:

```bash
# Prepare vendor sources
cd ~/Downloads/wslg-flake
git clone --branch working https://github.com/microsoft/FreeRDP-mirror.git vendor/FreeRDP
git clone --branch working https://github.com/microsoft/pulseaudio-mirror.git vendor/pulseaudio
git -C vendor/pulseaudio fetch --tags --force
# wsland source from our repo
cp -r ~/Downloads/wsland vendor/wsland
# Mesa source
# Download from https://gitlab.freedesktop.org/mesa/mesa/-/archive/mesa-24.2.7/mesa-mesa-24.2.7.tar.gz

# Build Docker image
docker build -f DockerfileArch -t wslg-arch .

# Export and convert to VHD
# See build-and-export.sh for the export/conversion process
```

## How To Use The Generated VHD

1. Place `system_x64.vhd` on Windows, e.g. `C:\WSL\system_x64.vhd`
2. In `%USERPROFILE%\.wslconfig`:
   ```ini
   [wsl2]
   systemDistro=C:\\WSL\\system_x64.vhd
   ```
3. No `.wslgconfig` changes needed - wsland is the default compositor in this build
4. Run `wsl --shutdown` then re-enter WSL

## Confirmed Build Failures And Fixes (from previous phase)

See `archive/our-wslg-fixes` branch for historical build issues. Key ones that may still apply:

1. **pulseaudio shallow clone crash** - need `git fetch --tags --force`
2. **librdpapplist-server.so symlink** - must use relative path, not build-time absolute path
3. **.dockerignore** - must only ignore root `.git`, not nested ones
