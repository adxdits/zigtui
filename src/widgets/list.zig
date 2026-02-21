const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

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

        const symbol_width: u16 = @intCast(std.unicode.utf8CountCodepoints(self.highlight_symbol) catch 0);
        const available_width = if (area.width > symbol_width) area.width - symbol_width else 0;

        var y: u16 = 0;
        var idx = self.offset;

        while (y < area.height and idx < self.items.len) : ({
            y += 1;
            idx += 1;
        }) {
            const item = self.items[idx];
            const is_selected = if (self.selected) |sel| sel == idx else false;

            // Draw highlight symbol
            if (is_selected and symbol_width > 0) {
                buf.setString(area.x, area.y + y, self.highlight_symbol, self.highlight_style);
            } else if (symbol_width > 0) {
                // Draw spaces for alignment
                var sx: u16 = 0;
                while (sx < symbol_width) : (sx += 1) {
                    buf.setChar(area.x + sx, area.y + y, ' ', self.style);
                }
            }

            // Draw item text
            const item_style = if (is_selected)
                self.style.merge(self.highlight_style)
            else
                self.style.merge(item.style);

            const start_x = area.x + symbol_width;
            buf.setString(start_x, area.y + y, item.content, item_style);

            // Fill remaining space
            const text_len: u16 = @intCast(@min(item.content.len, available_width));
            var fill_x = start_x + text_len;
            while (fill_x < area.x + area.width) : (fill_x += 1) {
                buf.setChar(fill_x, area.y + y, ' ', item_style);
            }
        }

        // Fill remaining area if we ran out of items
        while (y < area.height) : (y += 1) {
            var x: u16 = 0;
            while (x < area.width) : (x += 1) {
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
