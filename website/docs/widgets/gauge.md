---
id: gauge
title: Gauge / LineGauge
---

# Gauge / LineGauge

Two flavours of progress bar: a multi-row block gauge and a single-row line gauge.

## Gauge (block fill)

```zig
tui.widgets.Gauge{
    .ratio       = 0.72,      // 0.0 – 1.0
    .label       = "72%",
    .gauge_style = .{ .fg = .green },
}.render(area, buf);
```

## LineGauge (single row)

```zig
tui.widgets.LineGauge{
    .ratio       = 0.5,
    .label       = "50%",
    .gauge_style = .{ .fg = .blue },
    .line_set    = .rounded,   // .default  .thick  .double  .rounded
}.render(area, buf);
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `ratio` | `f64` | Progress value between `0.0` and `1.0` |
| `label` | `?[]const u8` | Text drawn in the centre of the bar |
| `gauge_style` | `Style` | Style of the filled portion |
| `line_set` | `LineSet` | `LineGauge` only glyph set for the bar |
