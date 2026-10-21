const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;
const stringWidth = render.stringWidth;

pub const ListItem = struct {
    content: []const u8,
    style: Style = .{},
};

pub const List = struct {
    items: []const ListItem,
    style: Style = .{},
    highlight_style: Style = .{},
    highlight_symbol: []const u8 = "> ",
    selected: ?usize = null,
    offset: usize = 0,

    pub fn render(self: List, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;
        if (area.x >= buf.width or area.y >= buf.height) return;

        const width = @min(area.width, buf.width - area.x);
        const height = @min(area.height, buf.height - area.y);
        const symbol_width: u16 = @intCast(@min(stringWidth(self.highlight_symbol), width));
        const available_width = width - symbol_width;

        var y: u16 = 0;
        var idx = self.offset;

        while (y < height and idx < self.items.len) : ({
            y += 1;
            idx += 1;
        }) {
            const item = self.items[idx];
            const is_selected = if (self.selected) |sel| sel == idx else false;

            // Draw highlight symbol
            const symbol_written = if (is_selected)
                buf.putString(area.x, area.y + y, self.highlight_symbol, symbol_width, self.highlight_style)
            else
                0;
            var sx = symbol_written;
            while (sx < symbol_width) : (sx += 1) {
                buf.setChar(area.x + sx, area.y + y, ' ', self.style);
            }

            // Draw item text
            const item_style = if (is_selected)
                self.style.merge(self.highlight_style)
            else
                self.style.merge(item.style);

            const start_x = area.x + symbol_width;
            const text_width = buf.putString(start_x, area.y + y, item.content, available_width, item_style);

            // Fill remaining space
            var fill_x = start_x + text_width;
            while (fill_x < area.x + width) : (fill_x += 1) {
                buf.setChar(fill_x, area.y + y, ' ', item_style);
            }
        }

        // Fill remaining area if we ran out of items
        while (y < height) : (y += 1) {
            var x: u16 = 0;
            while (x < width) : (x += 1) {
                buf.setChar(area.x + x, area.y + y, ' ', self.style);
            }
        }
    }

    pub fn selectNext(self: *List) void {
        if (self.items.len == 0) return;

        if (self.selected) |sel| {
            if (sel + 1 < self.items.len) {
                self.selected = sel + 1;
            }
        } else {
            self.selected = 0;
        }
    }

    pub fn selectPrevious(self: *List) void {
        if (self.items.len == 0) return;

        if (self.selected) |sel| {
            if (sel > 0) {
                self.selected = sel - 1;
            }
        } else {
            self.selected = if (self.items.len > 0) self.items.len - 1 else null;
        }
    }

    pub fn scrollToSelected(self: *List, visible_height: usize) void {
        if (self.selected) |sel| {
            // Scroll down if selected is below visible area
            if (sel >= self.offset + visible_height) {
                self.offset = sel - visible_height + 1;
            }
            // Scroll up if selected is above visible area
            else if (sel < self.offset) {
                self.offset = sel;
            }
        }
    }
};

test "List clips long items without changing neighboring cells" {
    var buf = try Buffer.init(std.testing.allocator, 12, 5);
    defer buf.deinit();
    buf.fillArea(buf.getArea(), '#', .{ .fg = .red });

    const items = [_]ListItem{.{ .content = "abcdefghijklmnop" }};
    const list = List{ .items = &items, .selected = 0 };
    const area = Rect{ .x = 2, .y = 1, .width = 5, .height = 2 };
    list.render(area, &buf);

    for (0..buf.height) |y| {
        for (0..buf.width) |x| {
            if (!area.contains(@intCast(x), @intCast(y))) {
                const cell = buf.get(@intCast(x), @intCast(y)).?;
                try std.testing.expectEqual(@as(u21, '#'), cell.char);
                try std.testing.expect(cell.fg.eql(.red));
            }
        }
    }
    try std.testing.expectEqual(@as(u21, 'a'), buf.get(4, 1).?.char);
    try std.testing.expectEqual(@as(u21, 'c'), buf.get(6, 1).?.char);
    try std.testing.expectEqual(@as(u21, ' '), buf.get(6, 2).?.char);
}

test "List aligns wide highlight symbols and clears after multibyte text" {
    var buf = try Buffer.init(std.testing.allocator, 10, 2);
    defer buf.deinit();
    buf.fillArea(buf.getArea(), '#', .{});

    const items = [_]ListItem{
        .{ .content = "\xC3\xA9" },
        .{ .content = "x" },
    };
    const list = List{
        .items = &items,
        .selected = 0,
        .highlight_symbol = "\xE7\x95\x8C ",
    };
    list.render(buf.getArea(), &buf);

    try std.testing.expectEqual(@as(u21, 0x754C), buf.get(0, 0).?.char);
    try std.testing.expectEqual(@as(u2, 0), buf.get(1, 0).?.width);
    try std.testing.expectEqual(@as(u21, 0xE9), buf.get(3, 0).?.char);
    try std.testing.expectEqual(@as(u21, 'x'), buf.get(3, 1).?.char);
    for (4..10) |x| {
        try std.testing.expectEqual(@as(u21, ' '), buf.get(@intCast(x), 0).?.char);
    }
}

test "List never splits wide items or oversized highlight symbols" {
    var buf = try Buffer.init(std.testing.allocator, 8, 1);
    defer buf.deinit();
    buf.fillArea(buf.getArea(), '#', .{});

    const items = [_]ListItem{.{ .content = "ab\xE7\x95\x8C" }};
    var list = List{ .items = &items, .highlight_symbol = "" };
    list.render(.{ .x = 1, .y = 0, .width = 3, .height = 1 }, &buf);
    try std.testing.expectEqual(@as(u21, 'b'), buf.get(2, 0).?.char);
    try std.testing.expectEqual(@as(u21, ' '), buf.get(3, 0).?.char);
    try std.testing.expectEqual(@as(u21, '#'), buf.get(4, 0).?.char);

    list.selected = 0;
    list.highlight_symbol = "\xE7\x95\x8C";
    list.render(.{ .x = 1, .y = 0, .width = 1, .height = 1 }, &buf);
    try std.testing.expectEqual(@as(u21, ' '), buf.get(1, 0).?.char);
    try std.testing.expectEqual(@as(u21, 'b'), buf.get(2, 0).?.char);

    list.highlight_symbol = ">>>>>>";
    list.render(.{ .x = 1, .y = 0, .width = 2, .height = 1 }, &buf);
    try std.testing.expectEqual(@as(u21, '>'), buf.get(2, 0).?.char);
    try std.testing.expectEqual(@as(u21, ' '), buf.get(3, 0).?.char);
}

test "List clips areas to the buffer and ignores empty or offscreen areas" {
    var buf = try Buffer.init(std.testing.allocator, 4, 2);
    defer buf.deinit();
    const items = [_]ListItem{.{ .content = "abcdef" }};
    const list = List{ .items = &items, .highlight_symbol = "" };
    list.render(.{ .x = 3, .y = 1, .width = 20, .height = 20 }, &buf);
    try std.testing.expectEqual(@as(u21, 'a'), buf.get(3, 1).?.char);

    list.render(.{ .x = 0, .y = 0, .width = 0, .height = 1 }, &buf);
    list.render(.{ .x = 0, .y = 0, .width = 1, .height = 0 }, &buf);
    list.render(.{ .x = 4, .y = 0, .width = 1, .height = 1 }, &buf);
    list.render(.{ .x = 0, .y = 2, .width = 1, .height = 1 }, &buf);
    try std.testing.expectEqual(@as(u21, ' '), buf.get(0, 0).?.char);
    try std.testing.expectEqual(@as(u21, 'a'), buf.get(3, 1).?.char);
}
