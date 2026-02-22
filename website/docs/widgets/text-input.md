---
id: text-input
title: TextInput
---

# TextInput

Comptime-sized, allocation-free single-line text field. The buffer size is a comptime parameter `TextInput(256)` allocates 256 bytes on the stack.

## Declaring state

```zig
// Declare as a field of your application state struct
var input = tui.widgets.TextInput(256){
    .style         = .{ .fg = .white },
    .cursor_style  = .{ .fg = .black, .bg = .white },
    .placeholder   = "Type here…",
    .focused       = true,
};
```

## Handling key events

```zig
switch (event.key.code) {
    .char      => |c| input.insertCodepoint(c),
    .backspace =>     input.deleteBackward(),
    .delete    =>     input.deleteForward(),
    .left      =>     input.moveCursorLeft(),
    .right     =>     input.moveCursorRight(),
    .home      =>     input.moveCursorHome(),
    .end       =>     input.moveCursorEnd(),
    else       => {},
}
```

## Reading the value

```zig
const text: []const u8 = input.value();
```

## Rendering

`TextInput` is one row tall:

```zig
input.render(area, buf);
```
