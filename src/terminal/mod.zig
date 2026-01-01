//! Terminal module - High-level terminal interface

const std = @import("std");
const backend = @import("../backend/mod.zig");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Allocator = std.mem.Allocator;
const Backend = backend.Backend;
const Buffer = render.Buffer;

pub const Error = backend.Error;

/// Terminal - manages terminal state and rendering
pub const Terminal = struct {
    backend_impl: Backend,
    current_buffer: Buffer,
    next_buffer: Buffer,
    hidden_cursor: bool = false,

    /// Initialize terminal with backend
    pub fn init(allocator: Allocator, backend_impl: Backend) !Terminal {
        // Get initial size
        const size = try backend_impl.getSize();

        // Create buffers
        var current = try Buffer.init(allocator, size.width, size.height);
        errdefer current.deinit();

        var next = try Buffer.init(allocator, size.width, size.height);
        errdefer next.deinit();

        // Setup terminal
        try backend_impl.enterRawMode();
        errdefer backend_impl.exitRawMode() catch {};

        try backend_impl.enableAlternateScreen();
        errdefer backend_impl.disableAlternateScreen() catch {};

        try backend_impl.clearScreen();

        return Terminal{
            .backend_impl = backend_impl,
            .current_buffer = current,
            .next_buffer = next,
        };
    }

    /// Deinitialize terminal
    pub fn deinit(self: *Terminal) void {
        self.backend_impl.disableAlternateScreen() catch {};
        self.backend_impl.exitRawMode() catch {};
        if (self.hidden_cursor) {
            self.backend_impl.showCursor() catch {};
        }
        self.current_buffer.deinit();
        self.next_buffer.deinit();
    }

    /// Draw frame using render function
    pub fn draw(self: *Terminal, ctx: anytype, renderFn: fn (@TypeOf(ctx), *Buffer) anyerror!void) !void {
        // Clear the buffer
        self.next_buffer.clear();

        // Call user render function
        try renderFn(ctx, &self.next_buffer);

        // Flush changes to terminal
        try self.flush();
    }

    /// Flush buffered changes to terminal
    pub fn flush(self: *Terminal) !void {
        const alloc = self.current_buffer.allocator;

        // Build output buffer
        var output: std.ArrayListUnmanaged(u8) = .empty;
        defer output.deinit(alloc);

        // Move cursor to home position first
        try output.appendSlice(alloc, "\x1b[H");

        var last_fg: style.Color = .reset;
        var last_bg: style.Color = .reset;
        var last_modifier: style.Modifier = .{};

        var y: u16 = 0;
        while (y < self.next_buffer.height) : (y += 1) {
            // Move to start of line
            var cursor_buf: [16]u8 = undefined;
            const cursor_cmd = std.fmt.bufPrint(&cursor_buf, "\x1b[{d};1H", .{y + 1}) catch continue;
            try output.appendSlice(alloc, cursor_cmd);

            var x: u16 = 0;
            while (x < self.next_buffer.width) : (x += 1) {
                const cell = self.next_buffer.get(x, y) orelse continue;

                // Check if style changed
                const fg_changed = !cell.fg.eql(last_fg);
                const bg_changed = !cell.bg.eql(last_bg);
                const mod_changed = !cell.modifier.eql(last_modifier);

                if (fg_changed or bg_changed or mod_changed) {
                    // Reset and apply new style
                    try output.appendSlice(alloc, "\x1b[0m");

                    // Apply foreground
                    if (cell.fg != .reset) {
                        if (cell.fg == .rgb) {
                            const rgb = cell.fg.rgb;
                            var fg_buf: [24]u8 = undefined;
                            const fg_cmd = std.fmt.bufPrint(&fg_buf, "\x1b[38;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }) catch continue;
                            try output.appendSlice(alloc, fg_cmd);
                        } else {
                            try output.appendSlice(alloc, cell.fg.toFg());
                        }
                    }

                    // Apply background
                    if (cell.bg != .reset) {
                        if (cell.bg == .rgb) {
                            const rgb = cell.bg.rgb;
                            var bg_buf: [24]u8 = undefined;
                            const bg_cmd = std.fmt.bufPrint(&bg_buf, "\x1b[48;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }) catch continue;
                            try output.appendSlice(alloc, bg_cmd);
                        } else {
                            try output.appendSlice(alloc, cell.bg.toBg());
                        }
                    }

                    // Apply modifiers
                    if (cell.modifier.bold) try output.appendSlice(alloc, "\x1b[1m");
                    if (cell.modifier.italic) try output.appendSlice(alloc, "\x1b[3m");
                    if (cell.modifier.underlined) try output.appendSlice(alloc, "\x1b[4m");
                    if (cell.modifier.reversed) try output.appendSlice(alloc, "\x1b[7m");

                    last_fg = cell.fg;
                    last_bg = cell.bg;
                    last_modifier = cell.modifier;
                }

                // Write character (ASCII only for Windows compatibility)
                if (cell.char < 128) {
                    const byte: u8 = @intCast(cell.char);
                    try output.append(alloc, byte);
                } else {
                    // For Unicode, encode as UTF-8
                    var char_buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(cell.char, &char_buf) catch {
                        try output.append(alloc, '?');
                        continue;
                    };
                    try output.appendSlice(alloc, char_buf[0..len]);
                }
            }
        }

        // Reset style at end
        try output.appendSlice(alloc, "\x1b[0m");

        // Write to backend
        if (output.items.len > 0) {
            try self.backend_impl.write(output.items);
            try self.backend_impl.flush();
        }

        // Copy next buffer to current for next frame comparison
        @memcpy(self.current_buffer.cells, self.next_buffer.cells);
    }

    /// Clear terminal
    pub fn clear(self: *Terminal) !void {
        self.current_buffer.clear();
        self.next_buffer.clear();
        try self.backend_impl.clearScreen();
    }

    /// Hide cursor
    pub fn hideCursor(self: *Terminal) !void {
        try self.backend_impl.hideCursor();
        self.hidden_cursor = true;
    }

    /// Show cursor
    pub fn showCursor(self: *Terminal) !void {
        try self.backend_impl.showCursor();
        self.hidden_cursor = false;
    }

    /// Set cursor position
    pub fn setCursor(self: *Terminal, x: u16, y: u16) !void {
        try self.backend_impl.setCursor(x, y);
    }

    /// Get terminal size
    pub fn getSize(self: *Terminal) !render.Size {
        return try self.backend_impl.getSize();
    }

    /// Resize terminal buffers
    pub fn resize(self: *Terminal, size: render.Size) !void {
        try self.current_buffer.resize(size.width, size.height);
        try self.next_buffer.resize(size.width, size.height);
    }
};
