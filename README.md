# ZigTUI

A TUI library for Zig, inspired by [Ratatui](https://github.com/ratatui/ratatui). Works on Windows, Linux, and macOS.

![ZigTUI Dashboard](dashboard.gif)

## Features

- Cell-based diffing (only redraws what changed)
- Widgets: Block, Paragraph, List, Gauge, Table, Tabs, Sparkline, BarChart, TextInput, Spinner, Tree, Canvas, Popup, Dialog
- Mouse support (SGR mode on Unix, native Console API on Windows)
- 15 built-in themes (Nord, Dracula, Gruvbox, Catppuccin, Tokyo Night, etc.)
- Kitty Graphics Protocol support with Unicode fallback
- No hidden allocations

## Requirements

- Zig 0.15.0+
- Windows 10+ / Linux / macOS

## Installation

```bash
zig fetch --save git+https://github.com/adxdits/zigtui.git
```

```zig
// build.zig
const zigtui = b.dependency("zigtui", .{ .target = target, .optimize = optimize });

const exe = b.addExecutable(.{
    .name = "myapp",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigtui", .module = zigtui.module("zigtui") },
        },
    }),
});
```

<details>
<summary>Alternative: Git submodule</summary>

```bash
git submodule add https://github.com/adxdits/zigtui.git libs/zigtui
```

```zig
const zigtui_module = b.addModule("zigtui", .{
    .root_source_file = b.path("libs/zigtui/src/lib.zig"),
});
```
</details>

## Quick Start

```zig
const std = @import("std");
const tui = @import("zigtui");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var backend = try tui.backend.init(allocator);
    defer backend.deinit();

    var terminal = try tui.terminal.Terminal.init(allocator, backend.interface());
    defer terminal.deinit();

    try terminal.hideCursor();
    defer terminal.showCursor() catch {};

    var running = true;
    while (running) {
        const event = try backend.interface().pollEvent(100);
        if (event == .key) {
            if (event.key.code == .esc or (event.key.code == .char and event.key.code.char == 'q'))
                running = false;
        }

        try terminal.draw({}, struct {
            fn render(_: void, buf: *tui.render.Buffer) !void {
                tui.widgets.Block{
                    .title = "Hello ZigTUI — press 'q' to quit",
                    .borders = tui.widgets.Borders.all(),
                    .border_style = .{ .fg = .cyan },
                }.render(buf.getArea(), buf);
            }
        }.render);
    }
}
```

## Widgets

### Block
Container with an optional border and title. All other widgets render inside a `Block`.

```zig
tui.widgets.Block{
    .title = "Panel",
    .borders = tui.widgets.Borders.ALL,
    .border_style = .{ .fg = .cyan },
    .title_style = .{ .fg = .white, .modifier = .{ .bold = true } },
    .border_symbols = tui.widgets.BorderSymbols.rounded(), // or .line() .double() .default()
}.render(area, buf);

// Get the inner area after accounting for borders
const inner = block.inner(area);
```

### Paragraph
Displays UTF-8 text with optional word-wrap.

```zig
tui.widgets.Paragraph{
    .text = "Hello, world!\nSecond line.",
    .style = .{ .fg = .white },
    .wrap = true,
}.render(area, buf);
```

### List
Scrollable list with optional selection highlight.

```zig
const items = [_]tui.widgets.ListItem{
    .{ .content = "Item one" },
    .{ .content = "Item two", .style = .{ .fg = .yellow } },
};
var list = tui.widgets.List{
    .items = &items,
    .selected = 0,
    .highlight_style = .{ .fg = .black, .bg = .cyan },
    .highlight_symbol = "▶ ",
};
list.render(area, buf);

// Navigation (call once per key event)
list.selectNext();
list.selectPrevious();
list.scrollToSelected(area.height); // keep selection visible
```

### Gauge / LineGauge
Progress bars — block-fill or single-line.

```zig
// Block gauge (multi-row)
tui.widgets.Gauge{
    .ratio = 0.72,         // 0.0 – 1.0
    .label = "72%",
    .gauge_style = .{ .fg = .green },
}.render(area, buf);

// Single-line gauge
tui.widgets.LineGauge{
    .ratio = 0.5,
    .label = "50%",
    .gauge_style = .{ .fg = .blue },
    .line_set = .rounded,  // .default .thick .double .rounded
}.render(area, buf);
```

### Table
Tabular data with auto-sized or fixed columns.

```zig
const cols = [_]tui.widgets.Column{
    .{ .header = "Name" },
    .{ .header = "CPU",  .width = 6 },
    .{ .header = "Mem",  .width = 8 },
};
const rows = [_]tui.widgets.Row{
    .{ .cells = &.{ "zig",    "12%", "156 MB" } },
    .{ .cells = &.{ "chrome", "15%", "2048 MB" } },
};
tui.widgets.Table{
    .columns = &cols,
    .rows    = &rows,
    .header_style   = .{ .fg = .cyan, .modifier = .{ .bold = true } },
    .selected_style = .{ .fg = .black, .bg = .cyan },
    .selected = 0,
}.render(area, buf);
```

---

### Tabs
Horizontal tab bar. One row tall; pair with a separator and a content area.

```zig
const titles = [_][]const u8{ "Overview", "Logs", "Settings" };
var tabs = tui.widgets.Tabs{
    .titles           = &titles,
    .selected         = 0,
    .selected_style   = .{ .fg = .cyan, .modifier = .{ .bold = true } },
    .unselected_style = .{ .fg = .dark_gray },
    .divider          = '│',  // u21 — default is │ (U+2502)
    .padding          = 1,    // spaces on each side of a title
};
tabs.render(area, buf);

// Navigation
tabs.selectNext();       // wraps around
tabs.selectPrevious();
```

### Sparkline
Single inline chart using ▁▂▃▄▅▆▇█ block characters. Right-aligned; shows the most recent values.

```zig
const data = [_]f64{ 10, 40, 25, 80, 60, 95, 55, 70 };
tui.widgets.Sparkline{
    .data  = &data,
    .max   = 100.0,   // null = auto-scale to data maximum
    .style = .{ .fg = .green },
}.render(area, buf);
```

The widget supports multi-row areas — values fill upward using sub-cell block characters for 8× vertical resolution per row.

### BarChart
Vertical or horizontal bar chart. Labels appear below (vertical) or to the left (horizontal).

```zig
const bars = [_]tui.widgets.Bar{
    .{ .label = "Jan", .value = 42 },
    .{ .label = "Feb", .value = 75, .style = .{ .fg = .yellow } }, // per-bar style override
    .{ .label = "Mar", .value = 31 },
};
tui.widgets.BarChart{
    .bars      = &bars,
    .max       = 100,                       // null = auto
    .direction = .vertical,                 // or .horizontal
    .bar_width = 5,
    .bar_gap   = 1,
    .bar_style = .{ .fg = .cyan },
    .bar_char  = '█',
    .empty_char = '░',
}.render(area, buf);
```

### TextInput
Comptime-sized, allocation-free single-line text field. The buffer size is a comptime parameter; `TextInput(256)` uses 256 bytes on the stack.

```zig
// Declare as part of your app state
var input = tui.widgets.TextInput(256){
    .style         = .{ .fg = .white },
    .cursor_style  = .{ .fg = .black, .bg = .white },
    .placeholder   = "Type here…",
    .focused       = true,
};

// Feed key events
switch (event.key.code) {
    .char      => |c| input.insertCodepoint(c),
    .backspace =>     input.deleteBackward(),
    .delete    =>     input.deleteForward(),
    .left      =>     input.moveCursorLeft(),
    .right     =>     input.moveCursorRight(),
    .home      =>     input.moveCursorHome(),
    .end       =>     input.moveCursorEnd(),
    else       => {},
}

// Read the current value
const text: []const u8 = input.value();

// Render (one row tall)
input.render(area, buf);
```

### Spinner
Animated single-cell loading indicator. Call `tick()` once per render frame.

```zig
var spinner = tui.widgets.Spinner{
    .kind         = .dots,          // .dots .line .arrow .bounce .bar
    .style        = .{ .fg = .cyan },
    .label        = "Loading…",
    .label_style  = .{ .fg = .white },
};

// In the event/render loop:
spinner.tick();
spinner.render(area, buf);

// Other helpers
spinner.reset();               // back to frame 0
const frame: []const u8 = spinner.current(); // current frame string
```

| Kind | Frames |
|------|--------|
| `dots` | ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ |
| `line` | `- \ \| /` |
| `arrow` | ←↖↑↗→↘↓↙ |
| `bounce` | ▏▎▍▌▋▊▉█▉▊▌▍▎ |
| `bar` | ▁▂▃▄▅▆▇█▇▆▅▄▃▂ |

### Tree
Hierarchical collapsible list. Selection is a flat visible-row index.

> **Important:** if `TreeNode` children slices point into fields of your state struct, build the tree *after* the state variable is in its final stack slot (not inside an `init()` function that returns by value). See `examples/widgets_demo.zig` for the correct pattern.

```zig
// Declare child arrays as fields of your state struct
var src_children = [_]tui.widgets.TreeNode{
    .{ .label = "main.zig" },
    .{ .label = "lib.zig" },
};
var root_nodes = [_]tui.widgets.TreeNode{
    .{ .label = "src/", .children = &src_children, .expanded = true },
    .{ .label = "build.zig" },
};

var tree = tui.widgets.Tree{
    .roots            = &root_nodes,
    .selected         = 0,
    .highlight_style  = .{ .fg = .black, .bg = .cyan },
    .indent           = 2,
    .expanded_symbol  = "▼ ",
    .collapsed_symbol = "▶ ",
    .leaf_symbol      = "  ",
};
tree.render(area, buf);

// Navigation
tree.selectNext();
tree.selectPrevious();

// Toggle expanded state of selected node (pass a mutable slice)
tree.toggleSelectedNode(&root_nodes);

// Count of currently visible rows
const visible: usize = tree.visibleCount();
```

### Canvas
Low-level drawing context. All coordinates are relative to the `area` origin.

```zig
var cv = tui.widgets.Canvas.init(area, buf, .{ .fg = .white });

cv.setPixel(5, 3, '*', .{ .fg = .yellow });
cv.drawText(1, 1, "hello", .{ .fg = .green });
cv.drawHLine(0, 10, 4, '─', .{ .fg = .gray });
cv.drawVLine(0, 0, 5, '│', .{ .fg = .gray });
cv.drawLine(0, 0, 19, 9, '\\', .{ .fg = .dark_gray }); // Bresenham
cv.fillRect(.{ .x = 2, .y = 2, .width = 8, .height = 4 }, '░', .{ .fg = .blue });
cv.clearRect(.{ .x = 2, .y = 2, .width = 8, .height = 4 });
cv.drawBox(.{ .x = 0, .y = 0, .width = 20, .height = 8 }, .{ .fg = .cyan }); // ┌─┐│└┘
cv.drawCircle(10, 5, 4, 'o', .{ .fg = .magenta }); // midpoint circle
```

### Popup
Floating overlay that optionally dims the cells behind it, then draws a bordered box. Render your content inside `Popup.innerArea(area)` after calling `render`.

```zig
// Helpers for computing the overlay area
const pop_area = tui.centeredRectPct(terminal_area, 60, 40);  // 60% wide, 40% tall
const pop_area = tui.centeredRectFixed(terminal_area, 50, 10); // exact 50×10

const pop = tui.widgets.Popup{
    .title          = " Info ",
    .border_style   = .{ .fg = .cyan },
    .backdrop_style = .{ .fg = .dark_gray }, // applied to cells behind popup
    .show_backdrop  = true,
};
pop.render(pop_area, buf);

// Render content inside the popup
const inner = tui.widgets.Popup.innerArea(pop_area);
tui.widgets.Paragraph{ .text = "Press any key to close.", .wrap = true }
    .render(inner, buf);
```

### Dialog
A `Popup` with a message body and a row of `[ buttons ]`. Navigate buttons with left/right; confirm with Enter.

```zig
var dlg = tui.widgets.Dialog{
    .title                = " Confirm ",
    .message              = "Are you sure you want to quit?",
    .buttons              = &.{ "Yes", "No" },
    .selected_button      = 1,                          // default to "No"
    .border_style         = .{ .fg = .yellow },
    .message_style        = .{ .fg = .white },
    .button_style         = .{ .fg = .white },
    .selected_button_style = .{ .fg = .black, .bg = .yellow, .modifier = .{ .bold = true } },
};

// Compute a centred area (e.g. 56 wide, 9 tall)
const dlg_area = tui.widgets.Dialog.dialogArea(terminal_area, 56, 9);
dlg.render(dlg_area, buf);

// Handle key events
switch (event.key.code) {
    .left, .back_tab => dlg.selectPreviousButton(),
    .right, .tab     => dlg.selectNextButton(),
    .enter => {
        if (dlg.selected_button == 0) { /* confirmed */ }
    },
    else => {},
}
```

## Themes

![Themes](theme.gif)

```zig
const theme = tui.themes.catppuccin_mocha;

tui.widgets.Block{
    .title = "Dashboard",
    .style = theme.baseStyle(),
    .border_style = theme.borderFocusedStyle(),
};
```

**Available:** `default`, `nord`, `dracula`, `monokai`, `gruvbox_dark`, `gruvbox_light`, `solarized_dark`, `solarized_light`, `tokyo_night`, `catppuccin_mocha`, `catppuccin_latte`, `one_dark`, `cyberpunk`, `matrix`, `high_contrast`

Run `zig build run-themes` to preview all themes.

## Examples

```bash
zig build run-dashboard      # System monitor demo
zig build run-kitty          # Image display demo
zig build run-themes         # Theme showcase
zig build run-mouse          # Mouse input demo
zig build run-widgets-demo   # Interactive showcase of all new widgets
```

## Kitty Graphics

Display images in terminals that support the [Kitty Graphics Protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/). Falls back to Unicode blocks automatically.

```zig
var gfx = tui.Graphics.init(allocator);
defer gfx.deinit();

var bmp = try tui.graphics.bmp.loadFile(allocator, "image.bmp");
const image = tui.Image{ .data = bmp.data, .width = bmp.width, .height = bmp.height, .format = .rgba };

if (gfx.supportsImages()) {
    if (try gfx.drawImage(image, .{ .x = 0, .y = 0 })) |seq| try backend.write(seq);
} else {
    gfx.renderImageToBuffer(image, buffer, area); // Unicode fallback
}
```

**Supported:** Kitty, WezTerm, foot, Konsole (partial)  
**Fallback:** Windows Terminal, iTerm2, Terminal.app

## Platform Support

| Platform | Terminal | Notes |
|----------|----------|-------|
| Windows 10+ | Windows Terminal, WezTerm | Native Console API |
| Linux | Any ANSI-compatible | POSIX termios |
| macOS | Kitty, WezTerm, Terminal.app | POSIX termios |

## License

MIT

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.
