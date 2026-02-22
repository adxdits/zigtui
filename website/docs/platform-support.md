---
id: platform-support
title: Platform Support
---

# Platform Support

ZigTUI works on Windows, Linux, and macOS with no extra dependencies.

## Compatibility matrix

| Platform | Terminals | Backend |
|----------|-----------|---------|
| **Windows 10+** | Windows Terminal, WezTerm | Native Console API (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`) |
| **Linux** | Any ANSI-compatible | POSIX termios + ANSI escape sequences |
| **macOS** | Kitty, WezTerm, Terminal.app, iTerm2 | POSIX termios + ANSI escape sequences |

## Mouse support

Mouse events use **SGR mode** (`\x1b[?1006h`) on Unix-like systems and the native **Console API** on Windows. You get click, scroll, and drag events with cell-accurate coordinates on all platforms.

## Kitty Graphics

See the [Kitty Graphics](./kitty-graphics.md) page for image display support per terminal.

## Requirements

- Zig **0.15.0** or newer  
- Windows: **Windows 10** build 1909 or newer (for VT processing and SGR mouse)
