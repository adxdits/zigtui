---
id: kitty-graphics
title: Kitty Graphics
---

# Kitty Graphics

ZigTUI can display BMP images in terminals that support the [Kitty Graphics Protocol](https://sw.kowidgoyal.net/kitty/graphics-protocol/). It automatically falls back to Unicode block-rendering on unsupported terminals.

## Usage

```zig
var gfx = tui.Graphics.init(allocator);
defer gfx.deinit();

// Load a BMP file
var bmp = try tui.graphics.bmp.loadFile(allocator, "image.bmp");
defer bmp.deinit(allocator);

const image = tui.Image{
    .data   = bmp.data,
    .width  = bmp.width,
    .height = bmp.height,
    .format = .rgba,
};

if (gfx.supportsImages()) {
    // Native protocol rendering
    if (try gfx.drawImage(image, .{ .x = 0, .y = 0 })) |seq| {
        try backend.write(seq);
    }
} else {
    // Unicode block fallback
    gfx.renderImageToBuffer(image, buffer, area);
}
```

## Terminal support

| Terminal | Support |
|----------|---------|
| Kitty | Full |
| WezTerm | Full |
| foot | Full |
| Konsole | Partial |
| Windows Terminal | Unicode fallback |
| iTerm2 | Unicode fallback |
| Terminal.app | Unicode fallback |

## Demo

```bash
zig build run-kitty
```
