---
id: choice-controls
title: Choice Controls
---

# Choice Controls

`Checkbox` and `RadioGroup` provide allocation-free boolean and single-choice inputs with keyboard and mouse support.

## Checkbox

```zig
var notifications = tui.widgets.Checkbox{
    .label = "Enable desktop notifications",
    .checked = true,
    .focused = true,
    .checked_style = .{ .fg = .green, .modifier = .{ .bold = true } },
    .focused_style = .{ .bg = .dark_gray },
};

if (event == .key) {
    _ = notifications.handleKey(event.key);
}
if (event == .mouse) {
    _ = notifications.handleMouse(event.mouse, checkbox_area);
}

notifications.render(checkbox_area, buf);
const enabled = notifications.checked;
```

Space and Enter toggle a focused checkbox. A left click anywhere inside its render area also toggles it.

## RadioGroup

```zig
const density_options = [_]tui.widgets.RadioItem{
    .{ .label = "Compact" },
    .{ .label = "Comfortable" },
    .{ .label = "Spacious" },
};

var density = tui.widgets.RadioGroup{
    .items = &density_options,
    .selected = 1,
    .focused = true,
    .selected_style = .{ .fg = .cyan, .modifier = .{ .bold = true } },
    .focused_style = .{ .bg = .dark_gray },
};

if (event == .key) {
    _ = density.handleKey(event.key);
}
if (event == .mouse) {
    _ = density.handleMouse(event.mouse, radio_area);
}

density.render(radio_area, buf);
const selected_index = density.selected;
```

The arrow keys move and wrap the selection. Space or Enter selects the first item when no value is selected. A left click selects the item on that row.

## Focus and disabled state

Set `focused` when your application routes keyboard events to a control. Mouse input does not require focus. Setting `disabled` prevents keyboard and mouse changes while applying `disabled_style` during rendering.

Both widgets support custom selected and unselected symbols:

```zig
notifications.checked_symbol = "[yes]";
notifications.unchecked_symbol = "[no ]";

density.selected_symbol = "(*)";
density.unselected_symbol = "( )";
```

`Checkbox` occupies one row. `RadioGroup` renders one item per row and clips to the supplied area.