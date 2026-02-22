const std = @import("std");
const render = @import("../render/mod.zig");
const style_mod = @import("../style/mod.zig");
const widgets_mod = @import("mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style_mod.Style;
const Block = widgets_mod.Block;
const Borders = widgets_mod.Borders;
const BorderSymbols = widgets_mod.BorderSymbols;
const Paragraph = widgets_mod.Paragraph;

/// `percent_x` and `percent_y` are clamped to [0, 100].
pub fn centeredRectPct(area: Rect, percent_x: u8, percent_y: u8) Rect {
    const px = @min(percent_x, 100);
    const py = @min(percent_y, 100);
    const w: u16 = @intCast(@as(u32, area.width) * px / 100);
    const h: u16 = @intCast(@as(u32, area.height) * py / 100);
    return centeredRectFixed(area, w, h);
}

/// Return a `Rect` centred within `area` with exact `width` × `height`.
pub fn centeredRectFixed(area: Rect, width: u16, height: u16) Rect {
    const w = @min(width, area.width);
    const h = @min(height, area.height);
    return .{
        .x = area.x + (area.width - w) / 2,
        .y = area.y + (area.height - h) / 2,
        .width = w,
        .height = h,
    };
}

pub const Popup = struct {
    title: ?[]const u8 = null,
    style: Style = .{},
    border_style: Style = .{},
    title_style: Style = .{},
    border_symbols: BorderSymbols = BorderSymbols.rounded(),
    /// When true, grey out the cells behind the popup area before drawing.
    show_backdrop: bool = true,
    backdrop_style: Style = .{},

    pub fn render(self: Popup, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        // Dim the backdrop
        if (self.show_backdrop) {
            var y = area.y;
            while (y < area.y + area.height and y < buf.height) : (y += 1) {
                var x = area.x;
                while (x < area.x + area.width and x < buf.width) : (x += 1) {
                    if (buf.get(x, y)) |cell| {
                        cell.setStyle(self.backdrop_style);
                    }
                }
            }
        }

        // Draw bordered block
        const blk = Block{
            .title = self.title,
            .borders = Borders.ALL,
            .style = self.style,
            .border_style = self.border_style,
            .title_style = self.title_style,
            .border_symbols = self.border_symbols,
        };
        blk.render(area, buf);
    }

    /// The content area inside the popup's border.
    pub fn innerArea(area: Rect) Rect {
        const blk = Block{ .borders = Borders.ALL };
        return blk.inner(area);
    }
};

pub const Dialog = struct {
    message: []const u8 = "",
    title: ?[]const u8 = null,
    buttons: []const []const u8 = &.{"OK"},
    selected_button: usize = 0,
    style: Style = .{},
    title_style: Style = .{},
    message_style: Style = .{},
    button_style: Style = .{},
    selected_button_style: Style = .{},
    border_style: Style = .{},
    border_symbols: BorderSymbols = BorderSymbols.rounded(),
    show_backdrop: bool = true,
    backdrop_style: Style = .{},

    /// Compute a sensible dialog area given an outer area and desired dimensions.
    pub fn dialogArea(area: Rect, width: u16, height: u16) Rect {
        return centeredRectFixed(area, width, height);
    }

    pub fn render(self: Dialog, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        // Backdrop + border
        const pop = Popup{
            .title = self.title,
            .style = self.style,
            .border_style = self.border_style,
            .title_style = self.title_style,
            .border_symbols = self.border_symbols,
            .show_backdrop = self.show_backdrop,
            .backdrop_style = self.backdrop_style,
        };
        pop.render(area, buf);

        const inner = Popup.innerArea(area);
        if (inner.width == 0 or inner.height == 0) return;

        // Message (leave bottom row(s) for buttons)
        const button_rows: u16 = 1;
        const msg_height = if (inner.height > button_rows) inner.height - button_rows else 0;
        if (msg_height > 0) {
            const para = Paragraph{
                .text = self.message,
                .style = self.message_style,
                .wrap = true,
            };
            para.render(
                .{ .x = inner.x, .y = inner.y, .width = inner.width, .height = msg_height },
                buf,
            );
        }

        // Buttons row (centred)
        if (self.buttons.len > 0) {
            const btn_y = inner.y + inner.height - button_rows;
            self.renderButtons(inner.x, btn_y, inner.width, buf);
        }
    }

    fn renderButtons(self: Dialog, x: u16, y: u16, available_width: u16, buf: *Buffer) void {
        // Measure total button row width: [ Label ]  with 1 space gap
        var total_width: u16 = 0;
        for (self.buttons, 0..) |btn, i| {
            const btn_w: u16 = @intCast(@min(btn.len + 4, std.math.maxInt(u16))); // "[ label ]"
            total_width += btn_w;
            if (i + 1 < self.buttons.len) total_width += 1; // gap
        }

        var start_x = x;
        if (total_width < available_width) {
            start_x = x + (available_width - total_width) / 2;
        }

        var bx = start_x;
        for (self.buttons, 0..) |btn, i| {
            if (bx >= x + available_width) break;
            const is_sel = i == self.selected_button;
            const bs = if (is_sel) self.button_style.merge(self.selected_button_style) else self.button_style;

            const btn_str_len: u16 = @intCast(@min(btn.len, std.math.maxInt(u16)));
            const btn_w = btn_str_len + 4;
            const avail = if (bx + btn_w <= x + available_width) btn_w else (x + available_width - bx);

            if (avail >= 2) {
                buf.setChar(bx, y, '[', bs);
                buf.setChar(bx + 1, y, ' ', bs);
                if (avail > 3) {
                    buf.setStringTruncated(bx + 2, y, btn, avail - 3, bs);
                }
                if (avail >= 2) {
                    const close_x = @min(bx + btn_w - 2, x + available_width - 2);
                    buf.setChar(close_x, y, ' ', bs);
                    buf.setChar(close_x + 1, y, ']', bs);
                }
            }

            bx += btn_w + 1;
        }
    }

    pub fn selectNextButton(self: *Dialog) void {
        if (self.buttons.len == 0) return;
        self.selected_button = (self.selected_button + 1) % self.buttons.len;
    }

    pub fn selectPreviousButton(self: *Dialog) void {
        if (self.buttons.len == 0) return;
        if (self.selected_button == 0) {
            self.selected_button = self.buttons.len - 1;
        } else {
            self.selected_button -= 1;
        }
    }
};

test "centeredRectPct produces correct geometry" {
    const area = Rect{ .x = 0, .y = 0, .width = 100, .height = 40 };
    const r = centeredRectPct(area, 50, 50);
    try std.testing.expectEqual(@as(u16, 50), r.width);
    try std.testing.expectEqual(@as(u16, 20), r.height);
    try std.testing.expectEqual(@as(u16, 25), r.x);
    try std.testing.expectEqual(@as(u16, 10), r.y);
}

test "Dialog button cycling" {
    var dlg = Dialog{ .buttons = &.{ "Yes", "No", "Cancel" } };
    dlg.selectNextButton();
    try std.testing.expectEqual(@as(usize, 1), dlg.selected_button);
    dlg.selectPreviousButton();
    try std.testing.expectEqual(@as(usize, 0), dlg.selected_button);
    dlg.selectPreviousButton(); // wraps
    try std.testing.expectEqual(@as(usize, 2), dlg.selected_button);
}
