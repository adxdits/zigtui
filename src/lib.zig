//! ZigTUI - Terminal UI Library for Zig
//! Inspired by Ratatui, designed for performance and safety

const std = @import("std");

// Core modules
pub const backend = @import("backend/mod.zig");
pub const terminal = @import("terminal/mod.zig");
pub const render = @import("render/mod.zig");
pub const layout = @import("layout/mod.zig");
pub const widgets = @import("widgets/mod.zig");
pub const style = @import("style/mod.zig");
pub const events = @import("events/mod.zig");
pub const graphics = @import("graphics/mod.zig");

// Re-export commonly used types
pub const Terminal = terminal.Terminal;
pub const Buffer = render.Buffer;
pub const Cell = render.Cell;
pub const Rect = render.Rect;
pub const Color = style.Color;
pub const Style = style.Style;
pub const Modifier = style.Modifier;
pub const Event = events.Event;
pub const KeyEvent = events.KeyEvent;
pub const KeyCode = events.KeyCode;
pub const Backend = backend.Backend;
pub const NativeBackend = backend.NativeBackend;

// Graphics types
pub const Graphics = graphics.Graphics;
pub const KittyGraphics = graphics.KittyGraphics;
pub const Image = graphics.Image;
pub const ImageWidget = graphics.ImageWidget;

/// Initialize the native backend for the current platform.
/// Convenience function that automatically selects WindowsBackend or AnsiBackend.
pub const init = backend.init;

test {
    std.testing.refAllDecls(@This());
}
