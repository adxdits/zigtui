const std = @import("std");
const style = @import("../style/mod.zig");
const Allocator = std.mem.Allocator;

pub const codepointWidth = @import("width.zig").codepointWidth;
pub const stringWidth = @import("width.zig").stringWidth;
pub const truncateToWidth = @import("width.zig").truncateToWidth;

pub const Cell = struct {
    char: u21 = ' ',
    fg: style.Color = .reset,
    bg: style.Color = .reset,
    modifier: style.Modifier = .{},
    /// Terminal columns this cell occupies. Zero marks the trailing column of a
    /// double-width cell, which carries no glyph of its own.
    width: u2 = 1,

    pub fn eql(self: Cell, other: Cell) bool {
        return self.char == other.char and
            self.width == other.width and
            self.fg.eql(other.fg) and
            self.bg.eql(other.bg) and
            self.modifier.eql(other.modifier);
    }

    pub fn isContinuation(self: Cell) bool {
        return self.width == 0;
    }

    pub fn reset(self: *Cell) void {
        self.* = .{};
    }

    pub fn setChar(self: *Cell, char: u21) void {
        self.char = char;
        self.width = @max(codepointWidth(char), 1);
    }

    pub fn setStyle(self: *Cell, s: style.Style) void {
        if (s.fg) |fg| self.fg = fg;
        if (s.bg) |bg| self.bg = bg;
        self.modifier = self.modifier.merge(s.modifier);
    }
};

pub const Rect = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,

    pub fn area(self: Rect) u32 {
        return @as(u32, self.width) * @as(u32, self.height);
    }

    pub fn contains(self: Rect, px: u16, py: u16) bool {
        return px >= self.x and px < self.x + self.width and
            py >= self.y and py < self.y + self.height;
    }

    pub fn inner(self: Rect, margin: u16) Rect {
        const doubled = margin * 2;
        if (doubled > self.width or doubled > self.height) {
            return .{ .x = self.x, .y = self.y, .width = 0, .height = 0 };
        }
        return .{
            .x = self.x + margin,
            .y = self.y + margin,
            .width = self.width - doubled,
            .height = self.height - doubled,
        };
    }

    pub fn splitHorizontal(self: Rect, at: u16) struct { left: Rect, right: Rect } {
        const split_at = @min(at, self.width);
        return .{
            .left = .{ .x = self.x, .y = self.y, .width = split_at, .height = self.height },
            .right = .{
                .x = self.x + split_at,
                .y = self.y,
                .width = self.width - split_at,
                .height = self.height,
            },
        };
    }

    pub fn splitVertical(self: Rect, at: u16) struct { top: Rect, bottom: Rect } {
        const split_at = @min(at, self.height);
        return .{
            .top = .{ .x = self.x, .y = self.y, .width = self.width, .height = split_at },
            .bottom = .{
                .x = self.x,
                .y = self.y + split_at,
                .width = self.width,
                .height = self.height - split_at,
            },
        };
    }
};

pub const Size = struct {
    width: u16,
    height: u16,
};

pub const Buffer = struct {
    width: u16,
    height: u16,
    cells: []Cell,
    allocator: Allocator,

    pub fn init(allocator: Allocator, width: u16, height: u16) !Buffer {
        const size = @as(usize, width) * @as(usize, height);
        const cells = try allocator.alloc(Cell, size);
        @memset(cells, Cell{});

        return Buffer{
            .width = width,
            .height = height,
            .cells = cells,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Buffer) void {
        self.allocator.free(self.cells);
    }

    pub fn getArea(self: Buffer) Rect {
        return .{ .x = 0, .y = 0, .width = self.width, .height = self.height };
    }

    pub fn clear(self: *Buffer) void {
        for (self.cells) |*cell| {
            cell.reset();
        }
    }

    pub fn resize(self: *Buffer, width: u16, height: u16) !void {
        if (width == self.width and height == self.height) return;

        const new_size = @as(usize, width) * @as(usize, height);
        const new_cells = try self.allocator.alloc(Cell, new_size);
        @memset(new_cells, Cell{});

        const min_width = @min(self.width, width);
        const min_height = @min(self.height, height);

        var y: u16 = 0;
        while (y < min_height) : (y += 1) {
            const old_offset = @as(usize, y) * @as(usize, self.width);
            const new_offset = @as(usize, y) * @as(usize, width);
            @memcpy(
                new_cells[new_offset .. new_offset + min_width],
                self.cells[old_offset .. old_offset + min_width],
            );
        }

        self.allocator.free(self.cells);
        self.cells = new_cells;
        self.width = width;
        self.height = height;
    }

    pub fn get(self: *Buffer, x: u16, y: u16) ?*Cell {
        if (x >= self.width or y >= self.height) return null;
        return self.at(x, y);
    }

    fn at(self: *Buffer, x: u16, y: u16) *Cell {
        return &self.cells[@as(usize, y) * @as(usize, self.width) + @as(usize, x)];
    }

    pub fn set(self: *Buffer, x: u16, y: u16, cell: Cell) void {
        if (self.get(x, y)) |c| {
            c.* = cell;
        }
    }

    /// Blank whichever double-width pair overlaps this column, so a partial
    /// overwrite never leaves a lead without its continuation or vice versa.
    fn breakPairAt(self: *Buffer, x: u16, y: u16) void {
        const cell = self.at(x, y);
        if (cell.isContinuation()) {
            if (x > 0) {
                const lead = self.at(x - 1, y);
                if (lead.width == 2) {
                    lead.char = ' ';
                    lead.width = 1;
                }
            }
            cell.char = ' ';
            cell.width = 1;
        } else if (cell.width == 2 and x + 1 < self.width) {
            const cont = self.at(x + 1, y);
            if (cont.isContinuation()) {
                cont.char = ' ';
                cont.width = 1;
            }
        }
    }

    pub fn setChar(self: *Buffer, x: u16, y: u16, char: u21, s: style.Style) void {
        if (x >= self.width or y >= self.height) return;

        const w = codepointWidth(char);
        if (w == 0) return;

        self.breakPairAt(x, y);

        if (w == 2 and x + 1 >= self.width) {
            const cell = self.at(x, y);
            cell.char = ' ';
            cell.width = 1;
            cell.setStyle(s);
            return;
        }
        if (w == 2) self.breakPairAt(x + 1, y);

        const lead = self.at(x, y);
        lead.char = char;
        lead.width = w;
        lead.setStyle(s);

        if (w == 2) {
            const cont = self.at(x + 1, y);
            cont.* = lead.*;
            cont.char = ' ';
            cont.width = 0;
        }
    }

    /// Write `str` starting at (x, y), stopping at `max_width` columns or the
    /// buffer edge. Returns the number of columns written.
    pub fn putString(self: *Buffer, x: u16, y: u16, str: []const u8, max_width: u16, s: style.Style) u16 {
        if (y >= self.height or x >= self.width) return 0;

        var col: u16 = 0;
        var iter = std.unicode.Utf8View.initUnchecked(str).iterator();
        while (iter.nextCodepoint()) |codepoint| {
            const w = codepointWidth(codepoint);
            if (w == 0) continue;
            if (col + w > max_width) break;
            if (x + col + w > self.width) break;
            self.setChar(x + col, y, codepoint, s);
            col += w;
        }
        return col;
    }

    pub fn setString(self: *Buffer, x: u16, y: u16, str: []const u8, s: style.Style) void {
        _ = self.putString(x, y, str, self.width -| x, s);
    }

    pub fn setStringTruncated(self: *Buffer, x: u16, y: u16, str: []const u8, max_width: u16, s: style.Style) void {
        const room = @min(max_width, self.width -| x);
        if (room == 0) return;

        if (stringWidth(str) <= room) {
            _ = self.putString(x, y, str, room, s);
            return;
        }

        const kept = truncateToWidth(str, room - 1);
        const written = self.putString(x, y, kept, room - 1, s);
        self.setChar(x + written, y, '…', s);
    }

    pub fn fillArea(self: *Buffer, area: Rect, char: u21, s: style.Style) void {
        var y = area.y;
        while (y < area.y + area.height and y < self.height) : (y += 1) {
            var x = area.x;
            while (x < area.x + area.width and x < self.width) : (x += 1) {
                self.setChar(x, y, char, s);
            }
        }
    }

    pub const Diff = struct {
        updates: std.ArrayListUnmanaged(Update) = .empty,
        allocator: Allocator,

        pub const Update = struct {
            x: u16,
            y: u16,
            cell: Cell,
        };

        pub fn init(allocator: Allocator) Diff {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Diff) void {
            self.updates.deinit(self.allocator);
        }
    };

    pub fn diff(self: Buffer, other: Buffer, allocator: Allocator) !Diff {
        var result = Diff.init(allocator);
        errdefer result.deinit();

        if (self.width != other.width or self.height != other.height) {
            for (other.cells, 0..) |cell, i| {
                if (cell.isContinuation()) continue;
                const x: u16 = @intCast(i % other.width);
                const y: u16 = @intCast(i / other.width);
                try result.updates.append(result.allocator, .{ .x = x, .y = y, .cell = cell });
            }
        } else {
            for (self.cells, other.cells, 0..) |old_cell, new_cell, i| {
                if (new_cell.isContinuation()) continue;
                if (!old_cell.eql(new_cell)) {
                    const x: u16 = @intCast(i % self.width);
                    const y: u16 = @intCast(i / self.width);
                    try result.updates.append(result.allocator, .{ .x = x, .y = y, .cell = new_cell });
                }
            }
        }

        return result;
    }
};

test "Cell equality" {
    const c1 = Cell{};
    const c2 = Cell{};
    try std.testing.expect(c1.eql(c2));

    const c3 = Cell{ .char = 'A' };
    try std.testing.expect(!c1.eql(c3));
}

test "Rect operations" {
    const r = Rect{ .x = 10, .y = 10, .width = 20, .height = 20 };
    try std.testing.expect(r.contains(15, 15));
    try std.testing.expect(!r.contains(5, 5));
    try std.testing.expectEqual(@as(u32, 400), r.area());
}

test "Buffer creation and manipulation" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 10, 10);
    defer buf.deinit();

    try std.testing.expectEqual(@as(u16, 10), buf.width);
    try std.testing.expectEqual(@as(u16, 10), buf.height);

    buf.setChar(5, 5, 'X', .{});
    if (buf.get(5, 5)) |cell| {
        try std.testing.expectEqual(@as(u21, 'X'), cell.char);
    }
}

test "wide codepoint claims two columns" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 10, 1);
    defer buf.deinit();

    buf.setString(0, 0, "日本語ab", .{});

    try std.testing.expectEqual(@as(u21, '日'), buf.get(0, 0).?.char);
    try std.testing.expect(buf.get(1, 0).?.isContinuation());
    try std.testing.expectEqual(@as(u21, '本'), buf.get(2, 0).?.char);
    try std.testing.expect(buf.get(3, 0).?.isContinuation());
    try std.testing.expectEqual(@as(u21, '語'), buf.get(4, 0).?.char);
    try std.testing.expect(buf.get(5, 0).?.isContinuation());
    try std.testing.expectEqual(@as(u21, 'a'), buf.get(6, 0).?.char);
    try std.testing.expectEqual(@as(u21, 'b'), buf.get(7, 0).?.char);
}

test "combining marks do not consume a column" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 10, 1);
    defer buf.deinit();

    buf.setString(0, 0, "e\u{0301}x", .{});

    try std.testing.expectEqual(@as(u21, 'e'), buf.get(0, 0).?.char);
    try std.testing.expectEqual(@as(u21, 'x'), buf.get(1, 0).?.char);
}

test "overwriting half of a wide cell blanks its partner" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 10, 1);
    defer buf.deinit();

    buf.setChar(0, 0, '日', .{});
    buf.setChar(1, 0, 'x', .{});

    try std.testing.expectEqual(@as(u21, ' '), buf.get(0, 0).?.char);
    try std.testing.expectEqual(@as(u2, 1), buf.get(0, 0).?.width);
    try std.testing.expectEqual(@as(u21, 'x'), buf.get(1, 0).?.char);

    buf.setChar(3, 0, '本', .{});
    buf.setChar(3, 0, 'y', .{});
    try std.testing.expectEqual(@as(u21, 'y'), buf.get(3, 0).?.char);
    try std.testing.expectEqual(@as(u21, ' '), buf.get(4, 0).?.char);
    try std.testing.expectEqual(@as(u2, 1), buf.get(4, 0).?.width);
}

test "wide codepoint never straddles the right edge" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 3, 1);
    defer buf.deinit();

    try std.testing.expectEqual(@as(u16, 3), buf.putString(0, 0, "a日", 3, .{}));
    try std.testing.expectEqual(@as(u21, '日'), buf.get(1, 0).?.char);
    try std.testing.expect(buf.get(2, 0).?.isContinuation());

    buf.clear();
    try std.testing.expectEqual(@as(u16, 0), buf.putString(2, 0, "日", 3, .{}));

    buf.setChar(2, 0, '日', .{});
    try std.testing.expectEqual(@as(u21, ' '), buf.get(2, 0).?.char);
    try std.testing.expectEqual(@as(u2, 1), buf.get(2, 0).?.width);
}

test "putString reports columns and respects max width" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 20, 1);
    defer buf.deinit();

    try std.testing.expectEqual(@as(u16, 5), buf.putString(0, 0, "hello", 10, .{}));
    try std.testing.expectEqual(@as(u16, 4), buf.putString(0, 0, "日本語", 5, .{}));
    try std.testing.expectEqual(@as(u16, 0), buf.putString(0, 0, "日", 1, .{}));
}

test "truncation leaves room for the ellipsis" {
    const allocator = std.testing.allocator;
    var buf = try Buffer.init(allocator, 20, 1);
    defer buf.deinit();

    buf.setStringTruncated(0, 0, "abcdefgh", 5, .{});
    try std.testing.expectEqual(@as(u21, 'a'), buf.get(0, 0).?.char);
    try std.testing.expectEqual(@as(u21, 'd'), buf.get(3, 0).?.char);
    try std.testing.expectEqual(@as(u21, '…'), buf.get(4, 0).?.char);
}

test "diff skips continuation cells" {
    const allocator = std.testing.allocator;
    var old = try Buffer.init(allocator, 10, 1);
    defer old.deinit();
    var new = try Buffer.init(allocator, 10, 1);
    defer new.deinit();

    new.setString(0, 0, "日本", .{});

    var delta = try old.diff(new, allocator);
    defer delta.deinit();

    try std.testing.expectEqual(@as(usize, 2), delta.updates.items.len);
    try std.testing.expectEqual(@as(u16, 0), delta.updates.items[0].x);
    try std.testing.expectEqual(@as(u16, 2), delta.updates.items[1].x);
}
