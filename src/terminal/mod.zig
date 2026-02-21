const std = @import("std");
const backend = @import("../backend/mod.zig");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Allocator = std.mem.Allocator;
const Backend = backend.Backend;
const KeyboardProtocolOptions = backend.KeyboardProtocolOptions;
const Buffer = render.Buffer;

pub const Error = backend.Error;

pub const Terminal = struct {
    backend_impl: Backend,
    current_buffer: Buffer,
    next_buffer: Buffer,
    hidden_cursor: bool = false,

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

    pub fn deinit(self: *Terminal) void {
        self.backend_impl.disableAlternateScreen() catch {};
        self.backend_impl.exitRawMode() catch {};
        if (self.hidden_cursor) {
            self.backend_impl.showCursor() catch {};
        }
        self.current_buffer.deinit();
        self.next_buffer.deinit();
    }

    pub fn draw(self: *Terminal, ctx: anytype, renderFn: fn (@TypeOf(ctx), *Buffer) anyerror!void) !void {
        // Clear the buffer
        self.next_buffer.clear();

        // Call user render function
        try renderFn(ctx, &self.next_buffer);

        // Flush changes to terminal
        try self.flush();
    }

    pub fn flush(self: *Terminal) !void {
        const alloc = self.current_buffer.allocator;

        // Compute diff between current (displayed) and next (desired) buffers
        var delta = try self.current_buffer.diff(self.next_buffer, alloc);
        defer delta.deinit();

        // Nothing changed — skip the write entirely
        if (delta.updates.items.len == 0) return;

        // Build output buffer
        var output: std.ArrayListUnmanaged(u8) = .empty;
        defer output.deinit(alloc);

        var last_fg: style.Color = .reset;
        var last_bg: style.Color = .reset;
        var last_modifier: style.Modifier = .{};
        var last_x: u16 = std.math.maxInt(u16);
        var last_y: u16 = std.math.maxInt(u16);

        for (delta.updates.items) |update| {
            const cell = update.cell;

            // Move cursor only when not at the expected position
            if (update.y != last_y or update.x != last_x) {
                var cursor_buf: [20]u8 = undefined;
                const cursor_cmd = std.fmt.bufPrint(&cursor_buf, "\x1b[{d};{d}H", .{ update.y + 1, update.x + 1 }) catch continue;
                try output.appendSlice(alloc, cursor_cmd);
            }

            // Apply style changes
            const fg_changed = !cell.fg.eql(last_fg);
            const bg_changed = !cell.bg.eql(last_bg);
            const mod_changed = !cell.modifier.eql(last_modifier);

            if (fg_changed or bg_changed or mod_changed) {
                try output.appendSlice(alloc, "\x1b[0m");
                try appendFgColor(&output, alloc, cell.fg);
                try appendBgColor(&output, alloc, cell.bg);
                try appendModifiers(&output, alloc, cell.modifier);
                last_fg = cell.fg;
                last_bg = cell.bg;
                last_modifier = cell.modifier;
            }

            // Write character
            try appendChar(&output, alloc, cell.char);

            // Track cursor position (cursor advances one column after write)
            last_x = update.x + 1;
            last_y = update.y;
        }

        // Reset style at end
        try output.appendSlice(alloc, "\x1b[0m");

        // Write to backend
        if (output.items.len > 0) {
            try self.backend_impl.write(output.items);
            try self.backend_impl.flush();
        }

        // Swap: current buffer now reflects what is on screen
        @memcpy(self.current_buffer.cells, self.next_buffer.cells);
    }

    // ── Helpers for ANSI output ──────────────────────────────────────

    fn appendFgColor(output: *std.ArrayListUnmanaged(u8), alloc: Allocator, color: style.Color) !void {
        switch (color) {
            .rgb => |rgb| {
                var buf: [24]u8 = undefined;
                const cmd = std.fmt.bufPrint(&buf, "\x1b[38;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }) catch return;
                try output.appendSlice(alloc, cmd);
            },
            .indexed => |idx| {
                var buf: [16]u8 = undefined;
                const cmd = std.fmt.bufPrint(&buf, "\x1b[38;5;{d}m", .{idx}) catch return;
                try output.appendSlice(alloc, cmd);
            },
            .reset => {},
            else => try output.appendSlice(alloc, color.toFg()),
        }
    }

    fn appendBgColor(output: *std.ArrayListUnmanaged(u8), alloc: Allocator, color: style.Color) !void {
        switch (color) {
            .rgb => |rgb| {
                var buf: [24]u8 = undefined;
                const cmd = std.fmt.bufPrint(&buf, "\x1b[48;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }) catch return;
                try output.appendSlice(alloc, cmd);
            },
            .indexed => |idx| {
                var buf: [16]u8 = undefined;
                const cmd = std.fmt.bufPrint(&buf, "\x1b[48;5;{d}m", .{idx}) catch return;
                try output.appendSlice(alloc, cmd);
            },
            .reset => {},
            else => try output.appendSlice(alloc, color.toBg()),
        }
    }

    fn appendModifiers(output: *std.ArrayListUnmanaged(u8), alloc: Allocator, mod: style.Modifier) !void {
        if (mod.bold) try output.appendSlice(alloc, "\x1b[1m");
        if (mod.dim) try output.appendSlice(alloc, "\x1b[2m");
        if (mod.italic) try output.appendSlice(alloc, "\x1b[3m");
        if (mod.underlined) try output.appendSlice(alloc, "\x1b[4m");
        if (mod.slow_blink) try output.appendSlice(alloc, "\x1b[5m");
        if (mod.rapid_blink) try output.appendSlice(alloc, "\x1b[6m");
        if (mod.reversed) try output.appendSlice(alloc, "\x1b[7m");
        if (mod.hidden) try output.appendSlice(alloc, "\x1b[8m");
        if (mod.crossed_out) try output.appendSlice(alloc, "\x1b[9m");
    }

    fn appendChar(output: *std.ArrayListUnmanaged(u8), alloc: Allocator, char: u21) !void {
        if (char < 128) {
            try output.append(alloc, @intCast(char));
        } else {
            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(char, &buf) catch {
                try output.append(alloc, '?');
                return;
            };
            try output.appendSlice(alloc, buf[0..len]);
        }
    }

    pub fn clear(self: *Terminal) !void {
        self.current_buffer.clear();
        self.next_buffer.clear();
        try self.backend_impl.clearScreen();
    }

    pub fn hideCursor(self: *Terminal) !void {
        try self.backend_impl.hideCursor();
        self.hidden_cursor = true;
    }

    pub fn showCursor(self: *Terminal) !void {
        try self.backend_impl.showCursor();
        self.hidden_cursor = false;
    }

    pub fn setCursor(self: *Terminal, x: u16, y: u16) !void {
        try self.backend_impl.setCursor(x, y);
    }

    pub fn enableKeyboardProtocol(self: *Terminal, options: KeyboardProtocolOptions) !void {
        try self.backend_impl.enableKeyboardProtocol(options);
    }

    pub fn disableKeyboardProtocol(self: *Terminal) !void {
        try self.backend_impl.disableKeyboardProtocol();
    }

    pub fn enableMouse(self: *Terminal) !void {
        try self.backend_impl.enableMouse();
    }

    pub fn disableMouse(self: *Terminal) !void {
        try self.backend_impl.disableMouse();
    }

    pub fn getSize(self: *Terminal) !render.Size {
        return try self.backend_impl.getSize();
    }

    pub fn resize(self: *Terminal, size: render.Size) !void {
        try self.current_buffer.resize(size.width, size.height);
        try self.next_buffer.resize(size.width, size.height);
    }
};
