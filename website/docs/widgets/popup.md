---
id: popup
title: Popup
---

# Popup

Floating overlay that optionally dims the cells behind it, then draws a bordered box. Render your content inside `Popup.innerArea(area)` after calling `render`.

## Area helpers

```zig
// Percentage-based (60 % wide, 40 % tall)
const pop_area = tui.centeredRectPct(terminal_area, 60, 40);

// Fixed size (exactly 50 columns × 10 rows)
const pop_area = tui.centeredRectFixed(terminal_area, 50, 10);
```

## Usage

```zig
const pop = tui.widgets.Popup{
    .title          = " Info ",
    .border_style   = .{ .fg = .cyan },
    .backdrop_style = .{ .fg = .dark_gray }, // style applied to cells behind popup
    .show_backdrop  = true,
};
pop.render(pop_area, buf);

// Render content inside the popup
const inner = tui.widgets.Popup.innerArea(pop_area);
tui.widgets.Paragraph{ .text = "Press any key to close.", .wrap = true }
    .render(inner, buf);
```
