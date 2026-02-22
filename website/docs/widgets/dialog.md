---
id: dialog
title: Dialog
---

# Dialog

A `Popup` with a message body and a row of `[ buttons ]`. Navigate buttons with left/right arrows; confirm with Enter.

## Usage

```zig
var dlg = tui.widgets.Dialog{
    .title                 = " Confirm ",
    .message               = "Are you sure you want to quit?",
    .buttons               = &.{ "Yes", "No" },
    .selected_button       = 1,   // default to "No"
    .border_style          = .{ .fg = .yellow },
    .message_style         = .{ .fg = .white },
    .button_style          = .{ .fg = .white },
    .selected_button_style = .{ .fg = .black, .bg = .yellow, .modifier = .{ .bold = true } },
};

const dlg_area = tui.widgets.Dialog.dialogArea(terminal_area, 56, 9);
dlg.render(dlg_area, buf);
```

## Handling key events

```zig
switch (event.key.code) {
    .left, .back_tab => dlg.selectPreviousButton(),
    .right, .tab     => dlg.selectNextButton(),
    .enter => {
        if (dlg.selected_button == 0) { /* user confirmed */ }
    },
    else => {},
}
```
