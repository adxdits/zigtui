const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

/// Block characters used to represent 8 discrete height levels.
const BLOCK_CHARS = [8]u21{ 0x2581, 0x2582, 0x2583, 0x2584, 0x2585, 0x2586, 0x2587, 0x2588 };

pub const Sparkline = struct {
    /// Data points. Values outside [0, max] are clamped.
    data: []const f64,
    /// Explicit maximum value. When null the maximum of `data` is used.
    max: ?f64 = null,
    style: Style = .{},
    /// If true, a single blank cell is shown when `data` is empty.
    show_empty: bool = false,

    pub fn render(self: Sparkline, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;
        if (self.data.len == 0) return;

        // Determine the data window to display (right-aligned, at most `area.width` points)
        const count = @min(self.data.len, @as(usize, area.width));
        const start = self.data.len - count;
        const slice = self.data[start..];

        // Determine max value
        var max_val = self.max orelse blk: {
            var m: f64 = slice[0];
            for (slice[1..]) |v| m = @max(m, v);
            break :blk m;
        };
        if (max_val <= 0.0) max_val = 1.0;

        // We only occupy the bottom `area.height` rows.
        // Each column maps to one data point.
        for (slice, 0..) |v, i| {
            if (i >= area.width) break;
            const clamped = @max(0.0, @min(max_val, v));
            // Map value to a cell bar height across `area.height` rows using block chars.
            // Total levels = area.height * 8 (8 sub-levels per row).
            const total_levels: f64 = @as(f64, @floatFromInt(area.height)) * 8.0;
            const level: usize = @intFromFloat(clamped / max_val * total_levels);

            const x: u16 = area.x + @as(u16, @intCast(i));

            // Render from the bottom row upward
            var row: u16 = 0;
            while (row < area.height) : (row += 1) {
                const y = area.y + area.height - 1 - row; // bottom-up
                const row_base_level = row * 8; // full levels contributed by rows below

                if (level <= row_base_level) {
                    // This row is completely empty
                    buf.setChar(x, y, ' ', self.style);
                } else {
                    const remaining = level - row_base_level;
                    if (remaining >= 8) {
                        // This row is completely filled
                        buf.setChar(x, y, BLOCK_CHARS[7], self.style);
                    } else {
                        // Partial fill
                        buf.setChar(x, y, BLOCK_CHARS[remaining - 1], self.style);
                    }
                }
            }
        }
    }
};

test "Sparkline renders without panic" {
    const alloc = std.testing.allocator;
    var buf = try render.Buffer.init(alloc, 20, 4);
    defer buf.deinit();
    const data = [_]f64{ 0, 1, 2, 3, 4, 5, 6, 7, 8 };
    const sp = Sparkline{ .data = &data };
    sp.render(.{ .x = 0, .y = 0, .width = 20, .height = 4 }, &buf);
}
