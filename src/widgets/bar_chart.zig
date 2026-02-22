const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

/// A single bar entry (label + value).
pub const Bar = struct {
    label: []const u8 = "",
    value: f64,
    /// Per-bar style override (uses `BarChart.bar_style` when null).
    style: ?Style = null,
};

/// Direction the chart grows toward.
pub const BarDirection = enum { vertical, horizontal };

/// A bar chart widget that supports both vertical and horizontal layouts.
///
/// Vertical example (default):
/// ```zig
/// const bars = [_]Bar{
///     .{ .label = "CPU", .value = 72 },
///     .{ .label = "RAM", .value = 45 },
///     .{ .label = "Net", .value = 91 },
/// };
/// BarChart{
///     .bars      = &bars,
///     .max       = 100,
///     .bar_width = 5,
///     .bar_style = .{ .fg = .cyan },
/// }.render(area, buf);
/// ```
pub const BarChart = struct {
    bars: []const Bar,
    /// Explicit maximum. When null the maximum `value` in `bars` is used.
    max: ?f64 = null,
    direction: BarDirection = .vertical,
    /// Width of each bar in cells (vertical) or height (horizontal).
    bar_width: u16 = 3,
    /// Gap between bars in cells.
    bar_gap: u16 = 1,
    bar_style: Style = .{},
    label_style: Style = .{},
    value_style: Style = .{},
    /// Character used to fill bars.
    bar_char: u21 = 0x2588, // █
    /// Character used for the empty portion of a bar.
    empty_char: u21 = ' ',

    pub fn render(self: BarChart, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0 or self.bars.len == 0) return;

        const max_val = self.resolveMax();
        if (max_val <= 0.0) return;

        switch (self.direction) {
            .vertical => self.renderVertical(area, buf, max_val),
            .horizontal => self.renderHorizontal(area, buf, max_val),
        }
    }

    // ── Vertical layout ───────────────────────────────────────────────────────
    // Bars grow upward from the bottom.  One label row at the bottom, the rest
    // is the chart area.

    fn renderVertical(self: BarChart, area: Rect, buf: *Buffer, max_val: f64) void {
        if (area.height < 2) return;

        const label_row = area.y + area.height - 1;
        const chart_height = area.height - 1; // rows available for bars
        const stride = self.bar_width + self.bar_gap;

        var x: u16 = area.x;
        for (self.bars) |bar| {
            if (x + self.bar_width > area.x + area.width) break;

            const clamped = @max(0.0, @min(max_val, bar.value));
            const filled: u16 = @intFromFloat(clamped / max_val * @as(f64, @floatFromInt(chart_height)));

            const bar_style = bar.style orelse self.bar_style;

            // Draw bar cells from the bottom of the chart area
            var row: u16 = 0;
            while (row < chart_height) : (row += 1) {
                const y = area.y + chart_height - 1 - row;
                const is_filled = row < filled;
                var col: u16 = 0;
                while (col < self.bar_width) : (col += 1) {
                    const ch = if (is_filled) self.bar_char else self.empty_char;
                    const cs = if (is_filled) bar_style else self.bar_style;
                    buf.setChar(x + col, y, ch, cs);
                }
            }

            // Draw label (centred under bar)
            if (bar.label.len > 0) {
                const label_len: u16 = @intCast(@min(bar.label.len, self.bar_width));
                const label_start = x + (self.bar_width - label_len) / 2;
                buf.setStringTruncated(label_start, label_row, bar.label, label_len, self.label_style);
            }

            x += stride;
        }
    }

    // ── Horizontal layout ─────────────────────────────────────────────────────
    // Bars grow rightward.  Labels are in the leftmost column block.

    fn renderHorizontal(self: BarChart, area: Rect, buf: *Buffer, max_val: f64) void {
        // Determine label column width (max label length, capped at 1/3 of area)
        var label_width: u16 = 0;
        for (self.bars) |bar| {
            const lw: u16 = @intCast(@min(bar.label.len, std.math.maxInt(u16)));
            label_width = @max(label_width, lw);
        }
        label_width = @min(label_width, area.width / 3);

        const chart_start_x = area.x + label_width + if (label_width > 0) @as(u16, 1) else @as(u16, 0);
        if (chart_start_x >= area.x + area.width) return;
        const chart_width = area.x + area.width - chart_start_x;

        const stride = self.bar_width + self.bar_gap;
        var y: u16 = area.y;

        for (self.bars) |bar| {
            if (y + self.bar_width > area.y + area.height) break;

            const clamped = @max(0.0, @min(max_val, bar.value));
            const filled: u16 = @intFromFloat(clamped / max_val * @as(f64, @floatFromInt(chart_width)));

            const bar_style = bar.style orelse self.bar_style;

            // Draw label
            if (label_width > 0) {
                buf.setStringTruncated(area.x, y, bar.label, label_width, self.label_style);
            }

            // Draw bar rows
            var row: u16 = 0;
            while (row < self.bar_width) : (row += 1) {
                var col: u16 = 0;
                while (col < chart_width) : (col += 1) {
                    const is_filled = col < filled;
                    const ch = if (is_filled) self.bar_char else self.empty_char;
                    const cs = if (is_filled) bar_style else self.bar_style;
                    buf.setChar(chart_start_x + col, y + row, ch, cs);
                }
            }

            y += stride;
        }
    }

    fn resolveMax(self: BarChart) f64 {
        if (self.max) |m| return m;
        var m: f64 = 0.0;
        for (self.bars) |bar| m = @max(m, bar.value);
        return m;
    }
};

test "BarChart resolves max from data" {
    const bars = [_]Bar{
        .{ .label = "A", .value = 10 },
        .{ .label = "B", .value = 50 },
        .{ .label = "C", .value = 30 },
    };
    const chart = BarChart{ .bars = &bars };
    try std.testing.expectEqual(@as(f64, 50), chart.resolveMax());
}
