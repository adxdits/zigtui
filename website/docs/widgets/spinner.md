---
id: spinner
title: Spinner
---

# Spinner

Animated single-cell loading indicator. Call `tick()` once per frame to advance the animation.

## Usage

```zig
var spinner = tui.widgets.Spinner{
    .kind        = .dots,
    .style       = .{ .fg = .cyan },
    .label       = "Loading…",
    .label_style = .{ .fg = .white },
};

// In the render loop:
spinner.tick();
spinner.render(area, buf);
```

## Other helpers

```zig
spinner.reset();                        // back to frame 0
const frame: []const u8 = spinner.current(); // current frame string
```

## Animation kinds

| Kind | Frames |
|------|--------|
| `dots` | ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏ |
| `line` | `- \ \| /` |
| `arrow` | ← ↖ ↑ ↗ → ↘ ↓ ↙ |
| `bounce` | ▏▎▍▌▋▊▉█▉▊▌▍▎ |
| `bar` | ▁▂▃▄▅▆▇█▇▆▅▄▃▂ |
