---
id: events
title: Events and Input
---

# Events and Input

Each pass through your main loop asks the backend for the next event, updates your state, and draws a frame.

```zig
const std = @import("std");
const tui = @import("zigtui");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var backend = try tui.backend.init(allocator, init.io);
    defer backend.deinit();

    var terminal = try tui.Terminal.init(allocator, backend.interface());
    defer terminal.deinit();

    var running = true;
    while (running) {
        const event = try backend.interface().pollEvent(100);
        switch (event) {
            .key => |key| {
                if (key.code == .esc or key.isChar('q')) running = false;
            },
            .resize => |size| try terminal.resize(.{ .width = size.width, .height = size.height }),
            else => {},
        }

        try terminal.draw({}, render);
    }
}

fn render(_: void, buf: *tui.Buffer) !void {
    const hint = tui.Paragraph{ .text = "Press q to quit" };
    hint.render(buf.getArea(), buf);
}
```

`pollEvent(timeout_ms)` waits up to `timeout_ms` for input, then returns `.none`. The timeout also sets how often the loop redraws when nothing happens, so keep it short when something on screen animates, such as a `Spinner`.

## Event

| Variant | Meaning |
| --- | --- |
| `.key` | A key was pressed. See [Keys](#keys) |
| `.mouse` | A mouse button, movement, or wheel event, once enabled. See [Mouse](#mouse) |
| `.resize` | The terminal changed size. Call `terminal.resize` so the next frame repaints fully |
| `.focus_gained`, `.focus_lost` | The terminal window gained or lost focus. Only the Windows backend reports these |
| `.paste` | Pasted bytes, when bracketed paste is enabled on the Linux/macOS backend. See [Bracketed paste](#bracketed-paste) |
| `.none` | The timeout passed with nothing to report |

`Event` also has the shortcuts `event.isChar('q')`, `event.isKey(.enter)`, and `event.isResize()`.

## Keys

A `KeyEvent` has a `code`, the `modifiers` held, and a `kind`:

```zig
.key => |key| switch (key.code) {
    .char => |c| {
        if (key.modifiers.ctrl and c == 's') save();
    },
    .enter => submit(),
    .up => list.selectPrevious(),
    .down => list.selectNext(),
    .f => |n| {
        if (n == 1) show_help = true;
    },
    else => {},
},
```

| `KeyCode` | Key |
| --- | --- |
| `.char` | A printable character, as a Unicode codepoint |
| `.enter`, `.tab`, `.back_tab`, `.backspace`, `.delete`, `.insert`, `.esc` | Editing keys. `.back_tab` is Shift+Tab |
| `.left`, `.right`, `.up`, `.down` | Arrow keys |
| `.home`, `.end`, `.page_up`, `.page_down` | Navigation keys |
| `.f` | A function key, where `.{ .f = 1 }` is F1 |
| `.caps_lock`, `.num_lock`, `.scroll_lock`, `.print_screen`, `.pause`, `.menu` | Reported with the [Kitty keyboard protocol](#kitty-keyboard-protocol) |
| `.functional` | Any other key the Kitty keyboard protocol reports, by its protocol number |

`key.modifiers` has `shift`, `ctrl`, and `alt` fields, with the shortcuts `key.isCtrl()`, `key.isAlt()`, and `key.isShift()`. The Kitty keyboard protocol also fills in `super`, `hyper`, `meta`, `caps_lock`, and `num_lock`.

On Linux and macOS, Ctrl plus a letter arrives as the lowercase letter with `ctrl` set. Terminals send the same bytes for some pairs of keys, so without the Kitty keyboard protocol you cannot tell them apart:

- Ctrl+I is Tab.
- Ctrl+M and Ctrl+J are Enter.
- Alt plus a key is the Esc byte followed by that key, so pressing Esc and then a key within the escape timeout reads as Alt plus that key.

### The Esc key

A terminal sends the Esc key as the same byte that begins arrow keys, function keys, and mouse reports. When that byte arrives alone, the Linux and macOS backend waits `escape_timeout_ms` (50 by default) for the rest of a sequence. If nothing follows, it reports `.esc`. Esc therefore arrives about 50 ms after the press, while every other key arrives immediately.

Over a slow connection such as SSH, a sequence can arrive in pieces more than 50 ms apart. An arrow key then shows up as Esc followed by characters like `[` and `A`. Raise the timeout to fix this. The field exists only on the Linux and macOS backend, so guard it in cross-platform code:

```zig
var backend = try tui.backend.init(allocator, init.io);
if (@import("builtin").os.tag != .windows) backend.escape_timeout_ms = 150;
```

With the Kitty keyboard protocol, Esc has its own sequence and needs no wait. The Windows backend reads keys from the console directly, so it never waits.

### Kitty keyboard protocol

Terminals such as Kitty, WezTerm, foot, and Ghostty can report keys without the ambiguities above. Ask for it after creating the terminal, and fall back to regular input where it isn't supported:

```zig
terminal.enableKeyboardProtocol(.{ .mode = .kitty, .detect_support = true }) catch |err| switch (err) {
    error.UnsupportedTerminal => {},
    else => return err,
};
defer terminal.disableKeyboardProtocol() catch {};
```

`.flags` selects what the terminal reports, as a bit set from the protocol:

| Flag | Effect |
| --- | --- |
| `1` | Report ambiguous keys, such as Esc and Ctrl+I, as distinct sequences. Used when `.flags` is 0 |
| `2` | Report repeats and releases, not only presses |
| `8` | Report every key as a sequence, including modifier keys pressed on their own |

With flag `2`, check `key.kind` so a key isn't handled twice:

```zig
.key => |key| {
    if (key.kind != .release) handleKey(key);
},
```

Without it, every key event is a `.press`. The Windows backend does not support the protocol and returns `error.UnsupportedTerminal`.

## Bracketed paste

Enable bracketed paste after creating the terminal:

```zig
terminal.enableBracketedPaste() catch |err| switch (err) {
    error.UnsupportedTerminal => {}, // Native Windows console input.
    else => return err,
};
defer terminal.disableBracketedPaste() catch {};
```

This is opt-in and requires raw mode. On terminals supporting bracketed paste,
each paste arrives as one `.paste` event instead of individual key events:

```zig
switch (event) {
    .paste => |bytes| {
        // Handle or copy the bytes before calling pollEvent again.
        handlePaste(bytes);
    },
    .key => |key| handleKey(key),
    else => {},
}
```

The slice belongs to the backend and is valid until the next `pollEvent` call
or backend deinitialization. Copy it with your allocator if you need it longer.
Newlines, control characters, and UTF-8 bytes are preserved verbatim, not
interpreted as shortcuts. Validate or filter the bytes as appropriate for your
application, especially when inserting into a single-line text input.

The Linux/macOS backend accepts at most **1 MiB (1,048,576 bytes)** per paste.
`pollEvent` returns `error.PasteTooLarge` if the payload exceeds that limit.
Allocation failures return `error.OutOfMemory`. In either case, the backend
discards the remaining payload through the paste's end marker before processing
ordinary keys again. No partial paste event is emitted.

Incomplete pastes survive polling timeouts without becoming key events.
Disabling bracketed paste during a paste also discards through its end marker.
Normal terminal/backend teardown and panic/signal restoration disable the mode.

The native Windows backend returns `error.UnsupportedTerminal` when enabling
bracketed paste; disabling it is a no-op. Terminals that do not support the mode
continue reporting pasted text as ordinary key events.

## Mouse

Mouse events are off until you enable them:

```zig
try terminal.enableMouse();
defer terminal.disableMouse() catch {};
```

A `MouseEvent` has a `kind`, a `button`, the `x` and `y` of the cell under the pointer, and the `modifiers` held. Coordinates start at 0 in the top-left corner, the same as `Buffer` and `Rect`.

| `kind` | Meaning |
| --- | --- |
| `.down`, `.up` | A button was pressed or released. `button` is `.left`, `.right`, or `.middle` |
| `.moved` | The pointer moved, with or without a button held |
| `.scroll_up`, `.scroll_down` | The wheel turned |
| `.drag` | Not reported by any backend yet. Motion with a button held arrives as `.moved` |

`button` is only meaningful for `.down` and `.up`. Once enabled, `.moved` events arrive whenever the pointer moves over the terminal, so ignore them if you don't need them.

To find what was clicked, keep the `Rect`s from your last draw and test them with `contains`:

```zig
.mouse => |mouse| {
    if (mouse.kind == .down and mouse.button == .left and app.list_area.contains(mouse.x, mouse.y)) {
        const row = app.list.offset + (mouse.y - app.list_area.y);
        if (row < app.list.items.len) app.list.selected = row;
    }
},
```

`Checkbox` and `RadioGroup` do this for you through `handleMouse(mouse, area)`. See [Choice Controls](./widgets/choice-controls.md).

While mouse reporting is on, most terminals only select text when you hold Shift as you drag.
