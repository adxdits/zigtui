# Contributing to ZigTUI

Thanks for your interest in contributing. Here's what you need to know.

## Getting started

```bash
git clone https://github.com/adxdits/zigtui.git
cd zigtui
zig build test
```

You'll need Zig 0.15.0 or later.

## Running the examples

```bash
zig build run-dashboard
zig build run-kitty
zig build run-themes
```

Try running these before and after your changes to make sure nothing breaks.

## Project layout

```
src/
  lib.zig              # Public API re-exports
  backend/             # Terminal I/O (ANSI + Windows Console API)
  events/              # Input event types
  graphics/            # Kitty graphics protocol, BMP loading, Unicode fallback
  layout/              # Layout primitives
  render/              # Buffer, Cell, Rect
  style/               # Colors, modifiers, themes
  terminal/            # Terminal state management and drawing
  widgets/             # Block, Paragraph, List, Gauge, Table
examples/
  dashboard.zig        # System monitor demo
  kitty_graphics.zig   # Image rendering demo
  themes_demo.zig      # Theme preview
```

## Making changes

1. Fork the repo and create a branch off `main`.
2. Make your changes. Keep commits focused — one logical change per commit.
3. Run `zig build test` and make sure the examples still work.
4. Open a pull request.

## Code style

- Follow the existing patterns in the codebase.
- No hidden allocations — all allocators are passed explicitly.
- Keep doc comments short and factual. Describe *what*, not *why it's amazing*.
- Use `snake_case` for functions and variables, `PascalCase` for types (standard Zig conventions).

## Adding a widget

Widgets live in `src/widgets/`. To add one:

1. Create a new file in `src/widgets/` (e.g., `sparkline.zig`).
2. Define a struct with the widget's config fields.
3. Add a `render(self, area: Rect, buf: *Buffer) void` method.
4. Re-export it from `src/widgets/mod.zig`.
5. Optionally add an example or extend the dashboard demo.

Look at `src/widgets/gauge.zig` for a minimal example.

## Adding a theme

Themes are defined in `src/style/themes.zig`. Each theme is a `Theme` struct with named colors. Copy an existing one and adjust the palette.

## Reporting bugs

Open an issue with:
- What you expected to happen
- What actually happened
- Your OS, terminal emulator, and Zig version

## License

By contributing, you agree that your contributions will be licensed under the MIT license.
