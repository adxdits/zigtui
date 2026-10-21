---
id: list
title: List
---

# List

Scrollable, selectable list widget with optional highlight.

## Usage

```zig
const items = [_]tui.widgets.ListItem{
    .{ .content = "Item one" },
    .{ .content = "Item two", .style = .{ .fg = .yellow } },
};

var list = tui.widgets.List{
    .items           = &items,
    .selected        = 0,
    .highlight_style = .{ .fg = .black, .bg = .cyan },
    .highlight_symbol = "▶ ",
};
list.render(area, buf);
```

Item text and highlight symbols are clipped to the render area's width, without
splitting wide characters or drawing into neighboring panels. Highlight alignment
and trailing padding use terminal display columns rather than UTF-8 byte counts.

## Navigation

Call these once per key event to move the selection:

```zig
list.selectNext();
list.selectPrevious();
list.scrollToSelected(area.height); // keep selected row visible
```

## `ListItem` fields

| Field | Type | Description |
|-------|------|-------------|
| `content` | `[]const u8` | Display text |
| `style` | `Style` | Per-item style override |
