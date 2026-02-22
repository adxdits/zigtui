---
id: bar-chart
title: BarChart
---

# BarChart

Vertical or horizontal bar chart with optional per-bar style overrides.

## Usage

```zig
const bars = [_]tui.widgets.Bar{
    .{ .label = "Jan", .value = 42 },
    .{ .label = "Feb", .value = 75, .style = .{ .fg = .yellow } },
    .{ .label = "Mar", .value = 31 },
};

tui.widgets.BarChart{
    .bars        = &bars,
    .max         = 100,          // null → auto-scale
    .direction   = .vertical,   // or .horizontal
    .bar_width   = 5,
    .bar_gap     = 1,
    .bar_style   = .{ .fg = .cyan },
    .bar_char    = '█',
    .empty_char  = '░',
}.render(area, buf);
```

## Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `bars` | `[]const Bar` | | Data bars |
| `max` | `?u64` | `null` | Scale ceiling |
| `direction` | `.vertical` / `.horizontal` | `.vertical` | Chart orientation |
| `bar_width` | `u16` | `3` | Width of each bar (vertical mode) |
| `bar_gap` | `u16` | `1` | Gap between bars |
| `bar_char` | `u21` | `'█'` | Filled cell character |
| `empty_char` | `u21` | `' '` | Empty cell character |
