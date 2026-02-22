---
id: block
title: Block
---

# Block

Container widget with an optional border and title. Every other widget renders its content inside a `Block`'s inner area.

## Usage

```zig
tui.widgets.Block{
    .title         = "Panel",
    .borders       = tui.widgets.Borders.ALL,
    .border_style  = .{ .fg = .cyan },
    .title_style   = .{ .fg = .white, .modifier = .{ .bold = true } },
    .border_symbols = tui.widgets.BorderSymbols.rounded(), // .line() .double() .default()
}.render(area, buf);
```

## Getting the inner area

After rendering a bordered block, call `inner` to get the inset area for child widgets:

```zig
const inner = block.inner(area);
// render child widgets into `inner`
```

## Border styles

| Helper | Preview |
|--------|---------|
| `BorderSymbols.default()` | `┌─┐│└─┘` |
| `BorderSymbols.rounded()` | `╭─╮│╰─╯` |
| `BorderSymbols.line()` | `┌─┐│└─┘` (thin) |
| `BorderSymbols.double()` | `╔═╗║╚═╝` |
