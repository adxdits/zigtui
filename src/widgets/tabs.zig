const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

/// A horizontal tab bar.
///
/// Usage:
/// ```zig
/// var tabs = Tabs{
///     .titles = &.{ "Overview", "Details", "Logs" },
///     .selected = 0,
///     .selected_style  = .{ .fg = .yellow, .modifier = .{ .bold = true } },
///     .unselected_style = .{ .fg = .dark_gray },
/// };
/// tabs.render(area, buf);
/// ```
pub const Tabs = struct {
    titles: []const []const u8,
    selected: usize = 0,
    style: Style = .{},
    /// Style applied to the active tab title.
    selected_style: Style = .{},
    /// Style applied to any inactive tab title.
    unselected_style: Style = .{},
    /// Character drawn between tab titles.
    divider: u21 = 0x2502, // │
    /// Padding spaces on each side of a title.
    padding: u16 = 1,

    pub fn render(self: Tabs, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0 or self.titles.len == 0) return;

        var x: u16 = area.x;
        const y = area.y;

        // Fill background
        {
            var fx: u16 = area.x;
            while (fx < area.x + area.width) : (fx += 1) {
                buf.setChar(fx, y, ' ', self.style);
            }
        }

        for (self.titles, 0..) |title, i| {
            if (x >= area.x + area.width) break;

            const is_selected = i == self.selected;
            const tab_style = if (is_selected) self.style.merge(self.selected_style) else self.style.merge(self.unselected_style);

            // Left padding
            var p: u16 = 0;
            while (p < self.padding and x < area.x + area.width) : (p += 1) {
                buf.setChar(x, y, ' ', tab_style);
                x += 1;
            }

            // Title characters
            var view = std.unicode.Utf8View.initUnchecked(title);
            var iter = view.iterator();
            while (iter.nextCodepoint()) |cp| {
                if (x >= area.x + area.width) break;
                buf.setChar(x, y, cp, tab_style);
                x += 1;
            }

            // Right padding
            p = 0;
            while (p < self.padding and x < area.x + area.width) : (p += 1) {
                buf.setChar(x, y, ' ', tab_style);
                x += 1;
            }

            // Divider (skip after last tab)
            if (i + 1 < self.titles.len and x < area.x + area.width) {
                buf.setChar(x, y, self.divider, self.style);
                x += 1;
            }
        }
    }

    /// Move selection to the next tab (wraps around).
    pub fn selectNext(self: *Tabs) void {
        if (self.titles.len == 0) return;
        self.selected = (self.selected + 1) % self.titles.len;
    }

    /// Move selection to the previous tab (wraps around).
    pub fn selectPrevious(self: *Tabs) void {
        if (self.titles.len == 0) return;
        if (self.selected == 0) {
            self.selected = self.titles.len - 1;
        } else {
            self.selected -= 1;
        }
    }
};

test "Tabs selectNext wraps" {
    var tabs = Tabs{ .titles = &.{ "A", "B", "C" }, .selected = 2 };
    tabs.selectNext();
    try std.testing.expectEqual(@as(usize, 0), tabs.selected);
}

test "Tabs selectPrevious wraps" {
    var tabs = Tabs{ .titles = &.{ "A", "B", "C" }, .selected = 0 };
    tabs.selectPrevious();
    try std.testing.expectEqual(@as(usize, 2), tabs.selected);
}
