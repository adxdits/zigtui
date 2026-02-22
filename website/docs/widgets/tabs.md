---
id: tabs
title: Tabs
---

# Tabs

Horizontal tab bar one row tall. Pair it with a separator line and a content area below.

## Usage

```zig
const titles = [_][]const u8{ "Overview", "Logs", "Settings" };

var tabs = tui.widgets.Tabs{
    .titles           = &titles,
    .selected         = 0,
    .selected_style   = .{ .fg = .cyan, .modifier = .{ .bold = true } },
    .unselected_style = .{ .fg = .dark_gray },
    .divider          = '│',   // U+2502 drawn between tab titles
    .padding          = 1,     // spaces on each side of a title
};
tabs.render(area, buf);
```

## Navigation

```zig
tabs.selectNext();      // wraps around to index 0
tabs.selectPrevious();
```
