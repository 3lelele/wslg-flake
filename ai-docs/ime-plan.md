# IME Plan

## Current Limitation

This work does not complete JetBrains IME support yet.

`wsland` currently does not implement:

- `text-input-unstable-v3`
- `input-method-unstable-v2`
- virtual keyboard plumbing

At time of writing, [protocol/meson.build](/home/storm/Downloads/wsland/protocol/meson.build) only generates:

- `xdg-shell`
- `pointer-constraints`

## Current Code Analysis

The current `wsland` input stack is still only a plain keyboard/pointer compositor path:

- [protocol/meson.build](/home/storm/Downloads/wsland/protocol/meson.build) does not generate IME-related protocol code
- [include/wsland/server.h](/home/storm/Downloads/wsland/include/wsland/server.h) has no `text-input`, `input-method`, `virtual-keyboard`, or popup-surface manager/state
- [src/server/server.c](/home/storm/Downloads/wsland/src/server/server.c) creates the seat and common wlroots managers, but no IME managers
- [src/server/handle.c](/home/storm/Downloads/wsland/src/server/handle.c) only forwards regular key/modifier events to `wlr_seat`
- [src/server/wayland.c](/home/storm/Downloads/wsland/src/server/wayland.c) already has usable Wayland focus and surface lifecycle hooks, which are the right place to connect IME focus enter/leave handling
- [src/adapter/adapter.c](/home/storm/Downloads/wsland/src/adapter/adapter.c) already creates a keyboard device for the RDP peer, so physical keyboard delivery is present and can remain separate from IME text commit delivery

The missing piece is the compositor-side IME protocol layer between:

- Wayland application <-> `text-input-unstable-v3`
- compositor <-> `input-method-unstable-v2`
- IME popup/preedit UI <-> scene graph / focused surface state

## Recommended Scope

Do not start with XWayland IME support.

The recommended first target is:

- native Wayland clients only
- `text-input-unstable-v3`
- `input-method-unstable-v2`

Reason:

- JetBrains IME only benefits from this if JetBrains is running as a native Wayland client
- the current `wsland` architecture already has a clear Wayland surface focus path
- XWayland IME/XIM bridging is much more complex and should be postponed

## Branching And CI Strategy

Recommended branch split:

- `main` for runtime/build/integration fixes
- `feature/wsland-ime` for IME protocol implementation

Recommended synchronization method:

```sh
git switch feature/wsland-ime
git rebase main
```

Use this periodically as `main` accumulates `wsland` stability fixes.

CI recommendation:

- keep automatic GitHub Actions builds on `main` only
- use `workflow_dispatch` manually for IME branch validation
- do not make the IME branch auto-build on every push until the base compositor path is reliable

This keeps IME work isolated from runtime bring-up work and avoids noisy, expensive VHD rebuilds during early protocol implementation.

## Recommended Implementation Plan

### Phase 1: expose the core IME protocols

- add `text-input-unstable-v3`
- add `input-method-unstable-v2`
- generate protocol code in [protocol/meson.build](/home/storm/Downloads/wsland/protocol/meson.build)
- wire the generated headers into [meson.build](/home/storm/Downloads/wsland/meson.build)
- create compositor-side manager/state objects in [include/wsland/server.h](/home/storm/Downloads/wsland/include/wsland/server.h) and [src/server/server.c](/home/storm/Downloads/wsland/src/server/server.c)

### Phase 2: implement seat-level IME state

- track the currently focused `text-input-v3`
- track the active `input-method-v2`
- store pending surrounding text, cursor rectangle, and content type
- keep IME state attached to the seat/server, not to individual windows

Reason:

- IME protocol state follows seat focus and focused surface, not scene nodes

### Phase 3: connect focus lifecycle

- on window focus changes, send `enter` / `leave` for `text-input-v3`
- activate / deactivate the current input method based on focused surface
- clear IME state when the focused surface is unmapped or destroyed

Best existing hook:

- [src/server/handle.c](/home/storm/Downloads/wsland/src/server/handle.c)

Additional cleanup is likely needed in:

- [src/server/wayland.c](/home/storm/Downloads/wsland/src/server/wayland.c)

### Phase 4: implement text exchange between app and IME

From application to compositor:

- `enable`
- `disable`
- `set_surrounding_text`
- `set_cursor_rectangle`
- `set_content_type`
- `commit`

From IME to application:

- preedit string
- commit string
- delete surrounding text
- done / serial synchronization

Recommended implementation shape:

- add a dedicated file [src/server/ime.c](/home/storm/Downloads/wsland/src/server/ime.c)

This keeps IME protocol code out of the existing pointer/window management files.

### Phase 5: implement IME popup surfaces

- support input method popup surfaces for candidate/preedit UI
- attach popup surfaces to the scene graph near the focused client surface
- position them using the text cursor rectangle supplied via `text-input-v3`
- update popup placement on focus changes, window moves, and output/work-area changes

Without this phase, protocol negotiation may work but the candidate UI may be missing or misplaced.

### Phase 6: consider optional extensions only after the above works

- `virtual-keyboard-v1`
- keyboard grab integration if required by the chosen IME stack
- XWayland-specific follow-up only after native Wayland works

## Suggested Initial Milestone

The first milestone should stay narrow:

- `wsland` advertises `text-input-unstable-v3`
- `wsland` advertises `input-method-unstable-v2`
- focus enter/leave works correctly for the focused Wayland client
- an IME such as `fcitx5` can detect that the focused client supports the expected Wayland IME protocol path

Even if candidate popup positioning and full preedit behavior are still incomplete, that milestone proves the protocol handshake and focus routing are correct.

## Files Most Likely To Change

- [protocol/meson.build](/home/storm/Downloads/wsland/protocol/meson.build)
- [meson.build](/home/storm/Downloads/wsland/meson.build)
- [include/wsland/server.h](/home/storm/Downloads/wsland/include/wsland/server.h)
- [src/server/server.c](/home/storm/Downloads/wsland/src/server/server.c)
- [src/server/handle.c](/home/storm/Downloads/wsland/src/server/handle.c)
- [src/server/wayland.c](/home/storm/Downloads/wsland/src/server/wayland.c)
- [src/server/ime.c](/home/storm/Downloads/wsland/src/server/ime.c)

## Important Assumption

This plan assumes the target application is running as a native Wayland client.

If JetBrains is still running through XWayland, implementing the Wayland IME protocol stack in `wsland` may still not produce usable IME behavior for JetBrains.
