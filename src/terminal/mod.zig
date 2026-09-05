const std = @import("std");
const backend = @import("../backend/mod.zig");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Allocator = std.mem.Allocator;
const Backend = backend.Backend;
const KeyboardProtocolOptions = backend.KeyboardProtocolOptions;
const Buffer = render.Buffer;

pub const Error = backend.Error;
pub const restore = @import("restore.zig");

/// Turning autowrap off keeps a glyph in the last column from scrolling the
/// screen, which would otherwise desynchronize every tracked cursor position.
const enter_sequence = "\x1b[?7l";
const exit_sequence = "\x1b[?7h";

/// Terminals that understand this hold the frame back until it is complete;
/// the rest ignore the private mode. Either way the frame is never torn.
const sync_begin = "\x1b[?2026h";
const sync_end = "\x1b[?2026l";

pub const Terminal = struct {
    backend_impl: Backend,
    current_buffer: Buffer,
    next_buffer: Buffer,
    output: std.ArrayListUnmanaged(u8) = .empty,
    hidden_cursor: bool = false,

    pub fn init(allocator: Allocator, backend_impl: Backend) !Terminal {
        const size = try backend_impl.getSize();

        var current = try Buffer.init(allocator, size.width, size.height);
        errdefer current.deinit();

        var next = try Buffer.init(allocator, size.width, size.height);
        errdefer next.deinit();

        try backend_impl.enterRawMode();
        errdefer backend_impl.exitRawMode() catch {};

        try backend_impl.enableAlternateScreen();
        errdefer backend_impl.disableAlternateScreen() catch {};

        try backend_impl.clearScreen();
        try backend_impl.write(enter_sequence);
        try backend_impl.flush();

        return Terminal{
            .backend_impl = backend_impl,
            .current_buffer = current,
            .next_buffer = next,
        };
    }

    pub fn deinit(self: *Terminal) void {
        if (self.hidden_cursor) {
            self.backend_impl.showCursor() catch {};
        }
        self.backend_impl.write(exit_sequence) catch {};
        self.backend_impl.flush() catch {};
        self.backend_impl.disableAlternateScreen() catch {};
        self.backend_impl.exitRawMode() catch {};
        self.output.deinit(self.current_buffer.allocator);
        self.current_buffer.deinit();
        self.next_buffer.deinit();
    }

    pub fn draw(self: *Terminal, ctx: anytype, renderFn: fn (@TypeOf(ctx), *Buffer) anyerror!void) !void {
        self.next_buffer.clear();
        try renderFn(ctx, &self.next_buffer);
        try self.flush();
    }

    pub fn flush(self: *Terminal) !void {
        const alloc = self.current_buffer.allocator;
        const next = &self.next_buffer;

        const full_redraw = self.current_buffer.width != next.width or
            self.current_buffer.height != next.height;
        if (full_redraw) try self.current_buffer.resize(next.width, next.height);

        self.output.clearRetainingCapacity();

        var last_fg: style.Color = .reset;
        var last_bg: style.Color = .reset;
        var last_modifier: style.Modifier = .{};
        var style_known = false;
        var last_x: u16 = std.math.maxInt(u16);
        var last_y: u16 = std.math.maxInt(u16);

        var y: u16 = 0;
        while (y < next.height) : (y += 1) {
            var x: u16 = 0;
            while (x < next.width) {
                const cell = next.cells[@as(usize, y) * @as(usize, next.width) + @as(usize, x)];
                const advance: u16 = @max(cell.width, 1);

                if (cell.isContinuation()) {
                    x += 1;
                    continue;
                }
                if (!full_redraw and cell.eql(self.current_buffer.cells[@as(usize, y) * @as(usize, next.width) + @as(usize, x)])) {
                    x += advance;
                    continue;
                }

                if (x != last_x or y != last_y) {
                    var cursor_buf: [24]u8 = undefined;
                    const cursor_cmd = std.fmt.bufPrint(&cursor_buf, "\x1b[{d};{d}H", .{ y + 1, x + 1 }) catch unreachable;
                    try self.output.appendSlice(alloc, cursor_cmd);
                }

                if (!style_known or
                    !cell.fg.eql(last_fg) or
                    !cell.bg.eql(last_bg) or
                    !cell.modifier.eql(last_modifier))
                {
                    try appendSgr(&self.output, alloc, cell.fg, cell.bg, cell.modifier);
                    last_fg = cell.fg;
                    last_bg = cell.bg;
                    last_modifier = cell.modifier;
                    style_known = true;
                }

                try appendChar(&self.output, alloc, cell.char);

                last_x = x + advance;
                last_y = y;
                x += advance;
            }
        }

        if (self.output.items.len == 0) return;

        try self.output.appendSlice(alloc, "\x1b[0m");
        try self.backend_impl.write(sync_begin);
        try self.backend_impl.write(self.output.items);
        try self.backend_impl.write(sync_end);
        try self.backend_impl.flush();

        @memcpy(self.current_buffer.cells, next.cells);
    }

    fn appendSgr(
        output: *std.ArrayListUnmanaged(u8),
        alloc: Allocator,
        fg: style.Color,
        bg: style.Color,
        mod: style.Modifier,
    ) !void {
        var buf: [96]u8 = undefined;
        var n: usize = 0;

        const prefix = "\x1b[0";
        @memcpy(buf[0..prefix.len], prefix);
        n = prefix.len;

        n += appendColorParams(buf[n..], fg, 0);
        n += appendColorParams(buf[n..], bg, 10);

        var codes: [9]u8 = undefined;
        for (mod.ansiParams(&codes)) |code| {
            n += (std.fmt.bufPrint(buf[n..], ";{d}", .{code}) catch unreachable).len;
        }

        buf[n] = 'm';
        n += 1;

        try output.appendSlice(alloc, buf[0..n]);
    }

    fn appendColorParams(buf: []u8, color: style.Color, offset: u8) usize {
        return switch (color) {
            .rgb => |rgb| (std.fmt.bufPrint(buf, ";{d};2;{d};{d};{d}", .{ 38 + offset, rgb.r, rgb.g, rgb.b }) catch unreachable).len,
            .indexed => |idx| (std.fmt.bufPrint(buf, ";{d};5;{d}", .{ 38 + offset, idx }) catch unreachable).len,
            .reset => 0,
            else => (std.fmt.bufPrint(buf, ";{d}", .{color.ansiBase().? + offset}) catch unreachable).len,
        };
    }

    fn appendChar(output: *std.ArrayListUnmanaged(u8), alloc: Allocator, char: u21) !void {
        if (char < 128) {
            try output.append(alloc, @intCast(char));
            return;
        }
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(char, &buf) catch {
            try output.append(alloc, '?');
            return;
        };
        try output.appendSlice(alloc, buf[0..len]);
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
        self.invalidate();
    }

    /// Forget what is believed to be on screen, so the next flush repaints every
    /// cell. Needed after a resize, since the terminal reflows on its own.
    pub fn invalidate(self: *Terminal) void {
        @memset(self.current_buffer.cells, .{ .char = 0 });
    }
};
