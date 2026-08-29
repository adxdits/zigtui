# ZigTUI

A TUI library for Zig, inspired by [Ratatui](https://github.com/ratatui/ratatui). Works on Windows, Linux, and macOS.

![ZigTUI Dashboard](dashboard.gif)

## Documentation

**[https://adxdits.github.io/zigtui/](https://adxdits.github.io/zigtui/)** full docs and guides.

## Quick install

```bash
zig fetch --save git+https://github.com/adxdits/zigtui.git
```

```zig
// build.zig
const zigtui = b.dependency("zigtui", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("zigtui", zigtui.module("zigtui"));
```

## Examples

```bash
zig build run-dashboard      # System monitor demo
zig build run-kitty          # Image display demo
zig build run-themes         # Theme showcase
zig build run-mouse          # Mouse input demo
zig build run-widgets-demo   # Interactive showcase of all widgets
```

## Date picker

`DatePicker` provides calendar rendering and keyboard navigation. Arrow keys move by a day or week, Page Up/Down move by month, and Home/End select the first or last day.

```zig
var picker = try zigtui.DatePicker.init(.{
	.year = 2026,
	.month = 8,
	.day = 29,
});

_ = picker.handleKey(key_event);
picker.render(area, buffer);
const selected_date = picker.selected;
```

## License

MIT see [LICENSE](LICENSE)
