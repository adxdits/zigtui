# ZigTUI

A Terminal User Interface (TUI) library for Zig, inspired by Ratatui. Build beautiful, interactive terminal applications with a simple, composable API.

**The first full-featured cross-platform TUI framework for Zig - works seamlessly on Windows and Linux.**

![ZigTUI System Monitor Dashboard](dashboard.gif)

*System Monitor Dashboard Example - Real-time CPU, memory, disk usage with interactive process list and CPU history sparkline*

## Features

- Cross-platform support (Windows and Linux)
- Cell-based rendering with diff algorithm for efficient updates
- Constraint-based layouts
- Composable widgets (Block, Paragraph, List, Gauge, Table)
- Keyboard and mouse event handling
- ANSI color and text styling support
- Explicit memory management (no hidden allocations)

## Requirements

- Zig 0.15.0 or later
- Windows 10+ or Linux with a terminal that supports ANSI escape sequences

## Installation

### Option 1: Zig fetch

Fetch the zigTUI module:

```bash
zig fetch --save git+https://github.com/adxdits/zigtui.git
```

Then in your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import ZigTUI module
    const zigtui = b.dependency("zigtui", .{
        .target = target,
        .optimize = optimize,
    });

    // Your executable
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

    b.installArtifact(exe);
}
```

### Option 2: Git Submodule

Add ZigTUI as a submodule to your project:

```bash
git submodule add https://github.com/yourusername/zigtui.git libs/zigtui
```

Then in your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import ZigTUI module
    const zigtui_module = b.addModule("zigtui", .{
        .root_source_file = b.path("libs/zigtui/src/lib.zig"),
    });

    // Your executable
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigtui", .module = zigtui_module },
            },
        }),
    });

    b.installArtifact(exe);
}
```

### Option 3: Copy Source Files

Copy the `src/` folder into your project and import directly:

```zig
const tui = @import("path/to/zigtui/src/lib.zig");
```

## Quick Start

Here is a minimal example that displays a box and exits when you press 'q':

```zig
const std = @import("std");
const tui = @import("zigtui");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize backend (platform-specific)
    var backend = if (@import("builtin").os.tag == .windows)
        try tui.backend.WindowsBackend.init(allocator)
    else
        try tui.backend.AnsiBackend.init(allocator);
    defer backend.deinit();

    // Initialize terminal
    var terminal = try tui.terminal.Terminal.init(allocator, backend.interface());
    defer terminal.deinit();

    // Hide cursor
    try terminal.hideCursor();

    // Main loop
    var running = true;
    while (running) {
        // Poll for events (100ms timeout)
        const event = try backend.interface().pollEvent(100);

        // Handle input
        switch (event) {
            .key => |key| {
                switch (key.code) {
                    .char => |c| {
                        if (c == 'q') running = false;
                    },
                    .esc => running = false,
                    else => {},
                }
            },
            else => {},
        }

        // Draw UI
        try terminal.draw({}, struct {
            fn render(_: void, buf: *tui.render.Buffer) !void {
                const area = buf.getArea();
                const block = tui.widgets.Block{
                    .title = "Hello ZigTUI - Press 'q' to quit",
                    .borders = tui.widgets.Borders.all(),
                    .border_style = tui.style.Style{ .fg = .cyan },
                };
                block.render(area, buf);
            }
        }.render);
    }

    try terminal.showCursor();
}
```

## API Reference

### Backend

The backend handles platform-specific terminal operations. The library automatically selects the correct backend for your platform:

```zig
// Automatic platform detection (recommended)
var backend = try tui.backend.init(allocator);
defer backend.deinit();
```

You can also use the `NativeBackend` type alias if you need the type explicitly:

```zig
var backend: tui.backend.NativeBackend = try tui.backend.init(allocator);
```

Or select a specific backend manually if needed:

```zig
// Windows only
var backend = try tui.backend.WindowsBackend.init(allocator);

// Linux/macOS only
var backend = try tui.backend.AnsiBackend.init(allocator);
```

### Terminal

The terminal manages the screen buffer and rendering:

```zig
var terminal = try tui.terminal.Terminal.init(allocator, backend.interface());
defer terminal.deinit();

// Draw a frame
try terminal.draw(context, renderFunction);

// Cursor control
try terminal.hideCursor();
try terminal.showCursor();
try terminal.setCursor(x, y);

// Get terminal size
const size = try terminal.getSize();
```

### Events

Poll for keyboard, mouse, and resize events:

```zig
const event = try backend.interface().pollEvent(timeout_ms);

switch (event) {
    .key => |key| {
        // key.code: KeyCode (.char, .enter, .esc, .up, .down, .left, .right, etc.)
        // key.modifiers: KeyModifiers (.ctrl, .alt, .shift)
    },
    .resize => |size| {
        // size.width, size.height
    },
    .focus_gained => {},
    .focus_lost => {},
    .none => {},
    else => {},
}
```

### Widgets

#### Block

A container with optional border and title:

```zig
const block = tui.widgets.Block{
    .title = "My Title",
    .borders = tui.widgets.Borders.all(),  // or .none(), .TOP, .BOTTOM, etc.
    .style = tui.style.Style{ .fg = .white, .bg = .black },
    .border_style = tui.style.Style{ .fg = .cyan },
    .title_style = tui.style.Style{ .fg = .yellow },
};
block.render(area, buf);
```

#### Paragraph

Display text with optional wrapping:

```zig
const paragraph = tui.widgets.Paragraph{
    .text = "Hello, world!",
    .style = tui.style.Style{ .fg = .white },
    .wrap = true,
};
paragraph.render(area, buf);
```

#### List

A scrollable list of items:

```zig
const items = [_]tui.widgets.ListItem{
    .{ .content = "Item 1" },
    .{ .content = "Item 2" },
    .{ .content = "Item 3" },
};
const list = tui.widgets.List{
    .items = &items,
    .selected = 0,
    .highlight_style = tui.style.Style{ .bg = .blue },
};
list.render(area, buf);
```

#### Gauge

A progress bar:

```zig
const gauge = tui.widgets.Gauge{
    .ratio = 0.75,  // 0.0 to 1.0
    .label = "75%",
    .gauge_style = tui.style.Style{ .fg = .green },
};
gauge.render(area, buf);
```

#### Table

Display tabular data:

```zig
const table = tui.widgets.Table{
    .header = &[_]tui.widgets.Column{
        .{ .title = "Name", .width = 20 },
        .{ .title = "Value", .width = 10 },
    },
    .rows = &rows,
};
table.render(area, buf);
```

### Styles

Apply colors and text modifiers:

```zig
const style = tui.style.Style{
    .fg = .red,           // Foreground color
    .bg = .black,         // Background color
    .modifier = tui.style.Modifier{
        .bold = true,
        .italic = true,
        .underlined = true,
    },
};
```

Available colors:
- Basic: `.black`, `.red`, `.green`, `.yellow`, `.blue`, `.magenta`, `.cyan`, `.white`, `.gray`
- Light variants: `.light_red`, `.light_green`, `.light_yellow`, `.light_blue`, `.light_magenta`, `.light_cyan`
- RGB: `.{ .rgb = .{ .r = 255, .g = 128, .b = 0 } }`
- Indexed (256 colors): `.{ .indexed = 42 }`
- Reset to default: `.reset`

### Buffer Operations

Direct buffer manipulation:

```zig
// Set a character at position
buf.setChar(x, y, 'X', style);

// Set a string at position
buf.setString(x, y, "Hello", style);

// Fill an area
buf.fillArea(rect, ' ', style);

// Get a cell
if (buf.get(x, y)) |cell| {
    cell.char = 'A';
    cell.setStyle(style);
}
```

### Layout

Use the Rect structure for positioning:

```zig
const area = tui.render.Rect{
    .x = 0,
    .y = 0,
    .width = 40,
    .height = 10,
};

// Get inner area with margin
const inner = area.inner(1);

// Split horizontally
const split = area.splitHorizontal(20);
// split.left, split.right

// Split vertically
const vsplit = area.splitVertical(5);
// vsplit.top, vsplit.bottom
```

## Examples

Build and run the dashboard example:

```bash
# Build examples
zig build examples

# Run the system monitor dashboard
zig build run-dashboard
```

## Platform Notes

### Windows

- Requires Windows 10 or later for Virtual Terminal support
- Uses native Windows Console API for input handling
- ANSI escape sequences are enabled automatically

### Linux

- Works with any terminal that supports ANSI escape sequences
- Uses POSIX termios for raw mode
- Tested on common terminals (xterm, gnome-terminal, alacritty, kitty)

## Project Structure

```
zigtui/
├── src/
│   ├── lib.zig           # Main library entry point
│   ├── backend/
│   │   ├── mod.zig       # Backend interface
│   │   ├── windows.zig   # Windows console backend
│   │   └── ansi.zig      # ANSI/POSIX backend
│   ├── terminal/
│   │   └── mod.zig       # Terminal management
│   ├── render/
│   │   └── mod.zig       # Buffer and rendering
│   ├── widgets/
│   │   ├── mod.zig       # Widget definitions
│   │   ├── gauge.zig     # Gauge widget
│   │   ├── list.zig      # List widget
│   │   └── table.zig     # Table widget
│   ├── style/
│   │   └── mod.zig       # Colors and styles
│   ├── layout/
│   │   └── mod.zig       # Layout system
│   └── events/
│       └── mod.zig       # Event handling
├── examples/
│   └── dashboard.zig     # System monitor dashboard
├── build.zig             # Build configuration
└── README.md
```

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.
