//! Buffer, Cell, and rendering

const std = @import("std");
const style = @import("../style/mod.zig");
const Allocator = std.mem.Allocator;

/// A single cell in the terminal buffer
pub const Cell = struct {
    char: u21 = ' ',
    fg: style.Color = .reset,
    bg: style.Color = .reset,
    modifier: style.Modifier = .{},

    /// Check if two cells are equal (for diffing)
    pub fn eql(self: Cell, other: Cell) bool {
        return self.char == other.char and
            self.fg.eql(other.fg) and
            self.bg.eql(other.bg) and
            self.modifier.eql(other.modifier);
    }

    /// Reset cell to default state
    pub fn reset(self: *Cell) void {
        self.* = .{};
    }

    /// Set cell character
    pub fn setChar(self: *Cell, char: u21) void {
        self.char = char;
    }

    /// Set cell style
    pub fn setStyle(self: *Cell, s: style.Style) void {
        if (s.fg) |fg| self.fg = fg;
        if (s.bg) |bg| self.bg = bg;
        self.modifier = self.modifier.merge(s.modifier);
    }
};

/// Rectangle area in the terminal
pub const Rect = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,

    /// Get the area of the rectangle
    pub fn area(self: Rect) u32 {
        return @as(u32, self.width) * @as(u32, self.height);
    }

    /// Check if rectangle contains a point
    pub fn contains(self: Rect, px: u16, py: u16) bool {
        return px >= self.x and px < self.x + self.width and
            py >= self.y and py < self.y + self.height;
    }

    /// Get the inner rectangle with margin
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

    /// Split rectangle horizontally at position
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

    /// Split rectangle vertically at position
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

/// Terminal size
pub const Size = struct {
    width: u16,
    height: u16,
};

/// Terminal buffer - represents the state of the terminal
pub const Buffer = struct {
    width: u16,
    height: u16,
    cells: []Cell,
    allocator: Allocator,

    /// Initialize a new buffer
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

    /// Deinitialize buffer
    pub fn deinit(self: *Buffer) void {
        self.allocator.free(self.cells);
    }

    /// Get buffer area as Rect
    pub fn getArea(self: Buffer) Rect {
        return .{ .x = 0, .y = 0, .width = self.width, .height = self.height };
    }

    /// Clear all cells in buffer
    pub fn clear(self: *Buffer) void {
        for (self.cells) |*cell| {
            cell.reset();
        }
    }

    /// Resize buffer
    pub fn resize(self: *Buffer, width: u16, height: u16) !void {
        if (width == self.width and height == self.height) return;

        const new_size = @as(usize, width) * @as(usize, height);
        const new_cells = try self.allocator.alloc(Cell, new_size);
        @memset(new_cells, Cell{});

        // Copy old content to new buffer
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

    /// Get cell at position
    pub fn get(self: *Buffer, x: u16, y: u16) ?*Cell {
        if (x >= self.width or y >= self.height) return null;
        const index = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
        return &self.cells[index];
    }

    /// Set cell at position
    pub fn set(self: *Buffer, x: u16, y: u16, cell: Cell) void {
        if (self.get(x, y)) |c| {
            c.* = cell;
        }
    }

    /// Set cell character at position
    pub fn setChar(self: *Buffer, x: u16, y: u16, char: u21, s: style.Style) void {
        if (self.get(x, y)) |cell| {
            cell.char = char;
            cell.setStyle(s);
        }
    }

    /// Set string at position
    pub fn setString(self: *Buffer, x: u16, y: u16, str: []const u8, s: style.Style) void {
        var px = x;
        var iter = std.unicode.Utf8View.initUnchecked(str).iterator();
        while (iter.nextCodepoint()) |codepoint| {
            if (px >= self.width) break;
            self.setChar(px, y, codepoint, s);
            px += 1;
        }
    }

    /// Set string with truncation at max_width
    pub fn setStringTruncated(self: *Buffer, x: u16, y: u16, str: []const u8, max_width: u16, s: style.Style) void {
        var px = x;
        var written: u16 = 0;
        var iter = std.unicode.Utf8View.initUnchecked(str).iterator();
        
        while (iter.nextCodepoint()) |codepoint| {
            if (px >= self.width or written >= max_width) break;
            self.setChar(px, y, codepoint, s);
            px += 1;
            written += 1;
        }
        
        // Add ellipsis if truncated
        if (iter.nextCodepoint() != null and written > 0 and x + written - 1 < self.width) {
            self.setChar(x + written - 1, y, '…', s);
        }
    }

    /// Fill area with character
    pub fn fillArea(self: *Buffer, area: Rect, char: u21, s: style.Style) void {
        var y = area.y;
        while (y < area.y + area.height and y < self.height) : (y += 1) {
            var x = area.x;
            while (x < area.x + area.width and x < self.width) : (x += 1) {
                self.setChar(x, y, char, s);
            }
        }
    }

    /// Compute diff between two buffers
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

    /// Calculate differences between this buffer and another
    pub fn diff(self: Buffer, other: Buffer, allocator: Allocator) !Diff {
        var result = Diff.init(allocator);
        errdefer result.deinit();

        if (self.width != other.width or self.height != other.height) {
            // Full redraw needed
            for (other.cells, 0..) |cell, i| {
                const x: u16 = @intCast(i % other.width);
                const y: u16 = @intCast(i / other.width);
                try result.updates.append(result.allocator, .{ .x = x, .y = y, .cell = cell });
            }
        } else {
            // Diff cells
            for (self.cells, other.cells, 0..) |old_cell, new_cell, i| {
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
