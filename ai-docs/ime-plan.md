# IME Plan

## Current Limitation

`wsland` currently does not implement:
- `text-input-unstable-v3`
- `input-method-unstable-v2`
- virtual keyboard plumbing

At time of writing, `protocol/meson.build` only generates:
- `xdg-shell`
- `cursor-shape-v1`
- `pointer-constraints-unstable-v1`

## Current Code Analysis (qq1038765585 upstream)

The wsland input stack is a plain keyboard/pointer compositor path:

- `protocol/meson.build` - no IME-related protocol code generated
- `include/wsland/server.h` - no text-input, input-method, virtual-keyboard, or popup-surface manager/state
- `src/server/server.c` - creates seat and common wlroots managers, but no IME managers
- `src/server/handle.c` - only forwards regular key/modifier events to wlr_seat
- `src/server/wayland.c` - has usable Wayland focus and surface lifecycle hooks, right place to connect IME focus enter/leave
- `src/adapter/adapter.c` - creates keyboard device for RDP peer, physical keyboard delivery present and separate from IME text commit

The missing piece is the compositor-side IME protocol layer between:
- Wayland application <-> `text-input-unstable-v3`
- compositor <-> `input-method-unstable-v2`
- IME popup/preedit UI <-> scene graph / focused surface state

## Recommended Scope

Do not start with XWayland IME support.

First target:
- native Wayland clients only
- `text-input-unstable-v3`
- `input-method-unstable-v2`

Reason:
- JetBrains 2026.x can run as a native Wayland client
- wsland architecture already has a clear Wayland surface focus path
- XWayland IME/XIM bridging is much more complex, postpone

## Branching Strategy

- `master` - synced with qq upstream, for runtime/build/integration fixes
- `feature/wsland-ime` - for IME protocol implementation
- Periodically rebase `feature/wsland-ime` onto `master` as upstream accumulates fixes

## Implementation Plan

### Phase 1: Expose the core IME protocols

- Add `text-input-unstable-v3` to `protocol/meson.build`
- Add `input-method-unstable-v2` to `protocol/meson.build`
- Generate protocol code
- Wire generated headers into `meson.build`
- Create compositor-side manager/state objects in `include/wsland/server.h` and `src/server/server.c`

### Phase 2: Implement seat-level IME state

- Track the currently focused `text-input-v3`
- Track the active `input-method-v2`
- Store pending surrounding text, cursor rectangle, and content type
- Keep IME state attached to the seat/server, not individual windows

### Phase 3: Connect focus lifecycle

- On window focus changes, send `enter` / `leave` for `text-input-v3`
- Activate / deactivate the current input method based on focused surface
- Clear IME state when the focused surface is unmapped or destroyed

Best existing hooks:
- `src/server/handle.c`

Additional cleanup likely needed in:
- `src/server/wayland.c`

### Phase 4: Implement text exchange between app and IME

From application to compositor:
- `enable`, `disable`, `set_surrounding_text`, `set_cursor_rectangle`, `set_content_type`, `commit`

From IME to application:
- preedit string, commit string, delete surrounding text, done / serial synchronization

Recommended: add a dedicated file `src/server/ime.c` to keep IME code separate.

### Phase 5: Implement IME popup surfaces

- Support input method popup surfaces for candidate/preedit UI
- Attach popup surfaces to the scene graph near the focused client surface
- Position using the text cursor rectangle from `text-input-v3`
- Update popup placement on focus changes, window moves, and output/work-area changes

### Phase 6: Optional extensions (only after the above works)

- `virtual-keyboard-v1`
- Keyboard grab integration if required by the chosen IME stack
- XWayland-specific follow-up only after native Wayland works

## Initial Milestone

- `wsland` advertises `text-input-unstable-v3`
- `wsland` advertises `input-method-unstable-v2`
- Focus enter/leave works correctly for the focused Wayland client
- An IME such as `fcitx5` can detect that the focused client supports the expected Wayland IME protocol path

## Files Most Likely To Change

- `protocol/meson.build`
- `meson.build`
- `include/wsland/server.h`
- `src/server/server.c`
- `src/server/handle.c`
- `src/server/wayland.c`
- `src/server/ime.c` (new)

## Prerequisites

- **Must validate window visibility first** - build the upstream VHD, confirm apps appear on Windows desktop, confirm JetBrains IDEA works
- Only then start IME work - it would be wasted effort if the base rendering path is broken
