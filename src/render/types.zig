const style = @import("../style/mod.zig");

pub const Cell = struct {
    char: u21 = ' ',
    fg: style.Color = .reset,
    bg: style.Color = .reset,
    modifier: style.Modifier = .{},

    pub fn eql(self: Cell, other: Cell) bool {
        return self.char == other.char and
            self.fg.eql(other.fg) and
            self.bg.eql(other.bg) and
            self.modifier.eql(other.modifier);
    }

    pub fn reset(self: *Cell) void {
        self.* = .{};
    }

    pub fn setChar(self: *Cell, char: u21) void {
        self.char = char;
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
