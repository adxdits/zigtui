const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

pub const Gauge = struct {
    ratio: f64,
    label: ?[]const u8 = null,
    style: Style = .{},
    gauge_style: Style = .{},
    use_unicode: bool = true,

    pub fn render(self: Gauge, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        // Clamp ratio
        const ratio = @max(0.0, @min(1.0, self.ratio));
        const filled_width = @as(usize, @intFromFloat(@as(f64, @floatFromInt(area.width)) * ratio));

        // Render each row
        var y: u16 = 0;
        while (y < area.height) : (y += 1) {
            const is_middle_row = (y == area.height / 2);

            var x: u16 = 0;
            while (x < area.width) : (x += 1) {
                const is_filled = x < filled_width;
                const cell_style = if (is_filled) self.gauge_style else self.style;

                // Draw label in middle row
                if (is_middle_row and self.label != null) {
                    const label = self.label.?;
                    const label_start = (area.width - @min(label.len, area.width)) / 2;

                    if (x >= label_start and x < label_start + label.len) {
                        const char_idx = x - label_start;
                        if (char_idx < label.len) {
                            buf.setChar(area.x + x, area.y + y, label[char_idx], cell_style);
                            continue;
                        }
                    }
                }

                // Draw progress character
                const char: u21 = if (self.use_unicode) '█' else '#';
                const fill_char: u21 = if (is_filled) char else ' ';
                buf.setChar(area.x + x, area.y + y, fill_char, cell_style);
            }
        }
    }

    pub fn percent(pct: u8) Gauge {
        return .{
            .ratio = @as(f64, @floatFromInt(@min(pct, 100))) / 100.0,
        };
    }
};

pub const LineGauge = struct {
    ratio: f64,
    label: ?[]const u8 = null,
    style: Style = .{},
    gauge_style: Style = .{},
    line_set: LineSet = .default,

    pub const LineSet = enum {
        default,
        thick,
        double,
        rounded,

        fn chars(self: LineSet) struct { filled: u21, empty: u21 } {
            return switch (self) {
                .default => .{ .filled = '━', .empty = '─' },
                .thick => .{ .filled = '█', .empty = '░' },
                .double => .{ .filled = '═', .empty = '─' },
                .rounded => .{ .filled = '●', .empty = '○' },
            };
        }
    };

    pub fn render(self: LineGauge, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        const ratio = @max(0.0, @min(1.0, self.ratio));
        const chars_set = self.line_set.chars();

        // Calculate label width
        const label_len: u16 = if (self.label) |l| @intCast(@min(l.len, area.width)) else 0;
        const gauge_width = if (area.width > label_len + 1) area.width - label_len - 1 else 0;
        const filled_width = @as(usize, @intFromFloat(@as(f64, @floatFromInt(gauge_width)) * ratio));

        // Draw label
        if (self.label) |label| {
            buf.setString(area.x, area.y, label, self.style);
            if (label_len < label.len) {
                // Add ellipsis if truncated
                if (label_len > 0) {
                    buf.setChar(area.x + label_len - 1, area.y, '…', self.style);
                }
            }
        }

        // Draw gauge
        const gauge_start = area.x + label_len + if (label_len > 0) @as(u16, 1) else @as(u16, 0);
        var x: u16 = 0;
        while (x < gauge_width) : (x += 1) {
            const is_filled = x < filled_width;
            const char = if (is_filled) chars_set.filled else chars_set.empty;
            const cell_style = if (is_filled) self.gauge_style else self.style;
            const px = gauge_start + x;
            if (px < buf.width and area.y < buf.height) {
                buf.setChar(px, area.y, char, cell_style);
            }
        }
    }

    pub fn percent(pct: u8) LineGauge {
        return .{
            .ratio = @as(f64, @floatFromInt(@min(pct, 100))) / 100.0,
        };
    }
};
