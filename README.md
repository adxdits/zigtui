# ZigTUI

A TUI library for Zig, inspired by [Ratatui](https://github.com/ratatui/ratatui). Works on Windows, Linux, and macOS.

https://github.com/user-attachments/assets/38e06b92-b664-4b3d-b9ec-1c24ce596a91

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

## Layout

Constraints are solved against the full extent, and the solved sizes never
overflow the area they are given.

```zig
const layout = zigtui.Layout{
    .direction = .vertical,
    .constraints = &.{ .{ .fixed = 3 }, .{ .fill = 1 }, .{ .fixed = 1 } },
};

var rows: [3]zigtui.Rect = undefined;
_ = layout.splitInto(area, &rows);
```

| Constraint | Meaning |
| --- | --- |
| `.fixed` / `.length` | exactly n cells |
| `.percentage` / `.ratio` | a share of the full extent |
| `.min` | a floor, and absorbs leftover space when no `.fill` is present |
| `.max` | a ceiling, and gives space back first when space runs short |
| `.fill` | takes leftover space, split by weight against other `.fill`s |

`splitInto` writes into storage you own and needs no allocator; `split` keeps
the allocating form. Space left over by constraints that cannot stretch stays
unallocated, so use `.fill` for the pane that should take up the slack.

## Leaving the terminal usable

Signal handlers are installed when raw mode is entered, so `SIGINT`, `SIGTERM`
and a segfault all restore the terminal before the process dies. Opt into the
matching panic handler from your root source file:

```zig
pub const panic = zigtui.panic;
```

## Unicode

Buffer cells track display width, so CJK and emoji occupy the two columns they
actually take up on screen, and combining marks take none. Measure text with
`zigtui.stringWidth` and cut it with `zigtui.truncateToWidth`.

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
