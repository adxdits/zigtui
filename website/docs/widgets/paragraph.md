---
id: paragraph
title: Paragraph
---

# Paragraph

Displays UTF-8 text with optional word-wrap. Ideal for status panels, help text, and message displays.

## Usage

```zig
tui.widgets.Paragraph{
    .text  = "Hello, world!\nSecond line.",
    .style = .{ .fg = .white },
    .wrap  = true,
}.render(area, buf);
```

## Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `text` | `[]const u8` | | UTF-8 content to display |
| `style` | `Style` | `{}` | Text style (fg, bg, modifier) |
| `wrap` | `bool` | `false` | Enable word-wrap |
