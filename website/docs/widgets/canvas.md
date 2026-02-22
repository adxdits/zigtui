---
id: canvas
title: Canvas
---

# Canvas

Low-level drawing context. All coordinates are relative to the top-left corner of the supplied `area`.

## Initialisation

```zig
var cv = tui.widgets.Canvas.init(area, buf, .{ .fg = .white });
```

## Drawing primitives

```zig
// Single cell
cv.setPixel(5, 3, '*', .{ .fg = .yellow });

// Text
cv.drawText(1, 1, "hello", .{ .fg = .green });

// Lines
cv.drawHLine(0, 10, 4,  '─', .{ .fg = .gray });      // horizontal
cv.drawVLine(0, 0,  5,  '│', .{ .fg = .gray });      // vertical
cv.drawLine(0, 0, 19, 9, '\\', .{ .fg = .dark_gray }); // Bresenham diagonal

// Rectangles
cv.fillRect(.{ .x = 2, .y = 2, .width = 8, .height = 4 }, '░', .{ .fg = .blue });
cv.clearRect(.{ .x = 2, .y = 2, .width = 8, .height = 4 });
cv.drawBox(.{  .x = 0, .y = 0, .width = 20, .height = 8 }, .{ .fg = .cyan }); // ┌─┐│└┘

// Circle (midpoint algorithm)
cv.drawCircle(10, 5, 4, 'o', .{ .fg = .magenta });
```
