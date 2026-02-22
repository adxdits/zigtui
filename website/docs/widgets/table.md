---
id: table
title: Table
---

# Table

Tabular data renderer with fixed or auto-sized columns, header row, and selection highlight.

## Usage

```zig
const cols = [_]tui.widgets.Column{
    .{ .header = "Name" },
    .{ .header = "CPU",  .width = 6 },
    .{ .header = "Mem",  .width = 8 },
};

const rows = [_]tui.widgets.Row{
    .{ .cells = &.{ "zig",    "12%", "156 MB"  } },
    .{ .cells = &.{ "chrome", "15%", "2048 MB" } },
};

tui.widgets.Table{
    .columns         = &cols,
    .rows            = &rows,
    .header_style    = .{ .fg = .cyan, .modifier = .{ .bold = true } },
    .selected_style  = .{ .fg = .black, .bg = .cyan },
    .selected        = 0,
}.render(area, buf);
```

## Column sizing

- Set `.width` on a `Column` for a fixed pixel width.
- Leave `.width = null` to let the column auto-size based on content.

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `columns` | `[]const Column` | Column headers and widths |
| `rows` | `[]const Row` | Data rows |
| `header_style` | `Style` | Style applied to the header row |
| `selected_style` | `Style` | Style applied to the selected row |
| `selected` | `?usize` | Index of the highlighted row |
