---
id: sparkline
title: Sparkline
---

# Sparkline

Inline chart rendered with `▁▂▃▄▅▆▇█` block characters. Values are right-aligned so the most recent point is always visible.

## Usage

```zig
const data = [_]f64{ 10, 40, 25, 80, 60, 95, 55, 70 };

tui.widgets.Sparkline{
    .data  = &data,
    .max   = 100.0,   // null → auto-scale to the max value in data
    .style = .{ .fg = .green },
}.render(area, buf);
```

## Multi-row areas

Render into a taller area to fill values upward. Sub-cell block characters provide **8× vertical resolution per row** a four-row sparkline has 32 discrete height levels.

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `data` | `[]const f64` | Data values to display |
| `max` | `?f64` | Scale ceiling `null` for auto |
| `style` | `Style` | Character colour / style |
