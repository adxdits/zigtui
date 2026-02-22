---
id: getting-started
title: Getting Started
sidebar_label: Getting Started
slug: /getting-started
---

# Getting Started

ZigTUI is a TUI (terminal user interface) library for Zig, inspired by [Ratatui](https://github.com/ratatui/ratatui). It works on **Windows 10+**, **Linux**, and **macOS**.

## Requirements

- Zig **0.15.0** or newer
- A terminal emulator (Windows Terminal, Kitty, WezTerm, iTerm2, foot, …)

## Installation

### Recommended: zig fetch

```bash
zig fetch --save git+https://github.com/adxdits/zigtui.git
```

Then wire up the dependency in your `build.zig`:

```zig title="build.zig"
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

### Alternative: Git submodule

```bash
git submodule add https://github.com/adxdits/zigtui.git libs/zigtui
```

```zig title="build.zig"
const zigtui_module = b.addModule("zigtui", .{
    .root_source_file = b.path("libs/zigtui/src/lib.zig"),
});
```

## Quick Start

The minimal loop initialise the backend and terminal, poll for events, then draw:

```zig title="src/main.zig"
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
                    .title = "Hello ZigTUI press 'q' to quit",
                    .borders = tui.widgets.Borders.all(),
                    .border_style = .{ .fg = .cyan },
                }.render(buf.getArea(), buf);
            }
        }.render);
    }
}
```

## Running the examples

```bash
zig build run-dashboard      # System monitor demo
zig build run-kitty          # Image display demo
zig build run-themes         # Theme showcase
zig build run-mouse          # Mouse input demo
zig build run-widgets-demo   # Interactive showcase of all widgets
```
