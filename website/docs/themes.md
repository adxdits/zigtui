---
id: themes
title: Themes
---

# Themes

ZigTUI ships **15 built-in themes**. Each theme exposes helper methods that return pre-configured `Style` values just pass them to any widget.

## Quick start

```zig
const theme = tui.themes.catppuccin_mocha;

tui.widgets.Block{
    .title        = "Dashboard",
    .style        = theme.baseStyle(),
    .border_style = theme.borderFocusedStyle(),
}.render(area, buf);
```

## Available themes

| Identifier | Name |
|------------|------|
| `default` | Default 16-colour |
| `nord` | Nord |
| `dracula` | Dracula |
| `monokai` | Monokai |
| `gruvbox_dark` | Gruvbox Dark |
| `gruvbox_light` | Gruvbox Light |
| `solarized_dark` | Solarized Dark |
| `solarized_light` | Solarized Light |
| `tokyo_night` | Tokyo Night |
| `catppuccin_mocha` | Catppuccin Mocha |
| `catppuccin_latte` | Catppuccin Latte |
| `one_dark` | One Dark |
| `cyberpunk` | Cyberpunk |
| `matrix` | Matrix |
| `high_contrast` | High Contrast |

## Theme style helpers

| Method | Returns |
|--------|---------|
| `baseStyle()` | Background + default text colour |
| `borderFocusedStyle()` | Border style for the focused panel |
| `borderUnfocusedStyle()` | Border style for unfocused panels |
| `highlightStyle()` | List / table selection highlight |
| `titleStyle()` | Bordered block title |

## Preview all themes

Run the bundled demo to see every theme live:

```bash
zig build run-themes
```
