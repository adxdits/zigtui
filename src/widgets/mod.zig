
//! Widgets module - Reusable UI components

const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

/// Widget trait - all widgets implement this interface
pub const Widget = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        render: *const fn (ptr: *anyopaque, area: Rect, buf: *Buffer) void,
    };

    pub fn render(self: Widget, area: Rect, buf: *Buffer) void {
        self.vtable.render(self.ptr, area, buf);
    }
};

/// Border flags
pub const Borders = packed struct {
    top: bool = false,
    bottom: bool = false,
    left: bool = false,
    right: bool = false,

    pub const NONE = Borders{};
    pub const ALL = Borders{ .top = true, .bottom = true, .left = true, .right = true };
    pub const TOP = Borders{ .top = true };
    pub const BOTTOM = Borders{ .bottom = true };
    pub const LEFT = Borders{ .left = true };
    pub const RIGHT = Borders{ .right = true };

    pub fn all() Borders {
        return ALL;
    }

    pub fn none() Borders {
        return NONE;
    }
};

/// Block widget - container with borders and title
pub const Block = struct {
    title: ?[]const u8 = null,
    borders: Borders = Borders.NONE,
    style: Style = .{},
    border_style: Style = .{},
    title_style: Style = .{},

    pub fn render(self: Block, area: Rect, buf: *Buffer) void {
        // Safety check: skip rendering if area is too small
        if (area.width == 0 or area.height == 0) return;

        // Fill background
        var y = area.y;
        while (y < area.y + area.height and y < buf.height) : (y += 1) {
            var x = area.x;
            while (x < area.x + area.width and x < buf.width) : (x += 1) {
                if (buf.get(x, y)) |cell| {
                    cell.setStyle(self.style);
                }
            }
        }

        // Draw borders
        if (self.borders.top or self.borders.bottom or self.borders.left or self.borders.right) {
            self.renderBorders(area, buf);
        }

        // Draw title
        if (self.title) |title| {
            if (self.borders.top and area.width > 2) {
                const title_x = area.x + 1;
                const title_y = area.y;
                const max_width = @min(title.len, area.width - 2);
                buf.setString(title_x, title_y, title[0..max_width], self.title_style.merge(self.border_style));
            }
        }
    }

    fn renderBorders(self: Block, area: Rect, buf: *Buffer) void {
        const symbols = BorderSymbols.default();

        // Corners
        if (self.borders.top and self.borders.left) {
            buf.setChar(area.x, area.y, symbols.top_left, self.border_style);
        }
        if (self.borders.top and self.borders.right and area.width > 0) {
            buf.setChar(area.x + area.width - 1, area.y, symbols.top_right, self.border_style);
        }
        if (self.borders.bottom and self.borders.left and area.height > 0) {
            buf.setChar(area.x, area.y + area.height - 1, symbols.bottom_left, self.border_style);
        }
        if (self.borders.bottom and self.borders.right and area.width > 0 and area.height > 0) {
            buf.setChar(area.x + area.width - 1, area.y + area.height - 1, symbols.bottom_right, self.border_style);
        }

        // Horizontal borders
        if (self.borders.top) {
            var x = area.x + 1;
            while (x < area.x + area.width - 1) : (x += 1) {
                buf.setChar(x, area.y, symbols.horizontal, self.border_style);
            }
        }
        if (self.borders.bottom and area.height > 0) {
            var x = area.x + 1;
            while (x < area.x + area.width - 1) : (x += 1) {
                buf.setChar(x, area.y + area.height - 1, symbols.horizontal, self.border_style);
            }
        }

        // Vertical borders
        if (self.borders.left) {
            var y = area.y + 1;
            while (y < area.y + area.height - 1) : (y += 1) {
                buf.setChar(area.x, y, symbols.vertical, self.border_style);
            }
        }
        if (self.borders.right and area.width > 0) {
            var y = area.y + 1;
            while (y < area.y + area.height - 1) : (y += 1) {
                buf.setChar(area.x + area.width - 1, y, symbols.vertical, self.border_style);
            }
        }
    }

    /// Get inner area (excluding borders)
    pub fn inner(self: Block, area: Rect) Rect {
        var inner_area = area;

        if (self.borders.left) {
            inner_area.x += 1;
            if (inner_area.width > 0) inner_area.width -= 1;
        }
        if (self.borders.right and inner_area.width > 0) {
            inner_area.width -= 1;
        }
        if (self.borders.top) {
            inner_area.y += 1;
            if (inner_area.height > 0) inner_area.height -= 1;
        }
        if (self.borders.bottom and inner_area.height > 0) {
            inner_area.height -= 1;
        }

        return inner_area;
    }
};

/// Border symbols
pub const BorderSymbols = struct {
    top_left: u21,
    top_right: u21,
    bottom_left: u21,
    bottom_right: u21,
    horizontal: u21,
    vertical: u21,

    /// ASCII borders - works on all terminals including Windows
    pub fn default() BorderSymbols {
        return .{
            .top_left = '+',
            .top_right = '+',
            .bottom_left = '+',
            .bottom_right = '+',
            .horizontal = '-',
            .vertical = '|',
        };
    }

    /// Unicode line drawing borders
    pub fn line() BorderSymbols {
        return .{
            .top_left = 0x250C, // ┌
            .top_right = 0x2510, // ┐
            .bottom_left = 0x2514, // └
            .bottom_right = 0x2518, // ┘
            .horizontal = 0x2500, // ─
            .vertical = 0x2502, // │
        };
    }

    pub fn rounded() BorderSymbols {
        return .{
            .top_left = 0x256D, // ╭
            .top_right = 0x256E, // ╮
            .bottom_left = 0x2570, // ╰
            .bottom_right = 0x256F, // ╯
            .horizontal = 0x2500, // ─
            .vertical = 0x2502, // │
        };
    }

    pub fn double() BorderSymbols {
        return .{
            .top_left = 0x2554, // ╔
            .top_right = 0x2557, // ╗
            .bottom_left = 0x255A, // ╚
            .bottom_right = 0x255D, // ╝
            .horizontal = 0x2550, // ═
            .vertical = 0x2551, // ║
        };
    }
};

/// Paragraph widget - multi-line text
pub const Paragraph = struct {
    text: []const u8,
    style: Style = .{},
    wrap: bool = true,

    pub fn render(self: Paragraph, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        var y_offset: u16 = 0;
        var x_offset: u16 = 0;
        var view = std.unicode.Utf8View.initUnchecked(self.text);
        var iter = view.iterator();

        while (iter.nextCodepoint()) |codepoint| {
            if (y_offset >= area.height) break;

            if (codepoint == '\n') {
                y_offset += 1;
                x_offset = 0;
                continue;
            }

            if (x_offset >= area.width) {
                if (self.wrap) {
                    y_offset += 1;
                    x_offset = 0;
                } else {
                    // Skip to next line
                    while (iter.nextCodepoint()) |c| {
                        if (c == '\n') break;
                    }
                    y_offset += 1;
                    x_offset = 0;
                    continue;
                }
            }

            if (y_offset < area.height) {
                buf.setChar(area.x + x_offset, area.y + y_offset, codepoint, self.style);
                x_offset += 1;
            }
        }
    }
};

test "Block inner area calculation" {
    const block = Block{ .borders = Borders.ALL };
    const area = Rect{ .x = 0, .y = 0, .width = 10, .height = 10 };
    const inner_area = block.inner(area);

    try std.testing.expectEqual(@as(u16, 1), inner_area.x);
    try std.testing.expectEqual(@as(u16, 1), inner_area.y);
    try std.testing.expectEqual(@as(u16, 8), inner_area.width);
    try std.testing.expectEqual(@as(u16, 8), inner_area.height);
}

// Re-export widget types
pub const List = @import("list.zig").List;
pub const ListItem = @import("list.zig").ListItem;
pub const Gauge = @import("gauge.zig").Gauge;
pub const LineGauge = @import("gauge.zig").LineGauge;
pub const Table = @import("table.zig").Table;
pub const TableBuilder = @import("table.zig").TableBuilder;
pub const Row = @import("table.zig").Row;
pub const Column = @import("table.zig").Column;

