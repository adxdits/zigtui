const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

pub const Canvas = struct {
    area: Rect,
    buf: *Buffer,
    /// Default style used when a method-level style is not supplied.
    default_style: Style,

    pub fn init(area: Rect, buf: *Buffer, default_style: Style) Canvas {
        return .{ .area = area, .buf = buf, .default_style = default_style };
    }

    // ── Coordinate helpers ────────────────────────────────────────────────────

    inline fn absX(self: Canvas, x: u16) u16 {
        return self.area.x + x;
    }

    inline fn absY(self: Canvas, y: u16) u16 {
        return self.area.y + y;
    }

    inline fn inBounds(self: Canvas, x: u16, y: u16) bool {
        return x < self.area.width and y < self.area.height;
    }

    // ── Primitives ────────────────────────────────────────────────────────────

    /// Set a single cell.
    pub fn setPixel(self: Canvas, x: u16, y: u16, char: u21, s: Style) void {
        if (!self.inBounds(x, y)) return;
        self.buf.setChar(self.absX(x), self.absY(y), char, s);
    }

    /// Write a UTF-8 string starting at (x, y), clipped to the canvas.
    pub fn drawText(self: Canvas, x: u16, y: u16, text: []const u8, s: Style) void {
        if (!self.inBounds(x, y)) return;
        const available = self.area.width - x;
        self.buf.setStringTruncated(self.absX(x), self.absY(y), text, available, s);
    }

    /// Fill a rectangle with `char`.
    pub fn fillRect(self: Canvas, rect: Rect, char: u21, s: Style) void {
        var ry: u16 = 0;
        while (ry < rect.height) : (ry += 1) {
            const ay = rect.y + ry;
            if (ay >= self.area.height) break;
            var rx: u16 = 0;
            while (rx < rect.width) : (rx += 1) {
                const ax = rect.x + rx;
                if (ax >= self.area.width) break;
                self.buf.setChar(self.absX(ax), self.absY(ay), char, s);
            }
        }
    }

    /// Clear a rectangle (fill with spaces using the canvas default style).
    pub fn clearRect(self: Canvas, rect: Rect) void {
        self.fillRect(rect, ' ', self.default_style);
    }

    /// Draw a horizontal line from (x1, y) to (x2, y).
    pub fn drawHLine(self: Canvas, x1: u16, x2: u16, y: u16, char: u21, s: Style) void {
        if (y >= self.area.height) return;
        const left = @min(x1, x2);
        const right = @min(@max(x1, x2), self.area.width - 1);
        var x = left;
        while (x <= right) : (x += 1) {
            self.buf.setChar(self.absX(x), self.absY(y), char, s);
        }
    }

    /// Draw a vertical line from (x, y1) to (x, y2).
    pub fn drawVLine(self: Canvas, x: u16, y1: u16, y2: u16, char: u21, s: Style) void {
        if (x >= self.area.width) return;
        const top = @min(y1, y2);
        const bottom = @min(@max(y1, y2), self.area.height - 1);
        var y = top;
        while (y <= bottom) : (y += 1) {
            self.buf.setChar(self.absX(x), self.absY(y), char, s);
        }
    }

    /// Draw a line between two arbitrary points using Bresenham's algorithm.
    pub fn drawLine(self: Canvas, x1: u16, y1: u16, x2: u16, y2: u16, char: u21, s: Style) void {
        // Bresenham work in signed integers to handle all octants correctly.
        var sx: i32 = @intCast(x1);
        var sy: i32 = @intCast(y1);
        const ex: i32 = @intCast(x2);
        const ey: i32 = @intCast(y2);

        const dx = @abs(ex - sx);
        const dy = @abs(ey - sy);
        const step_x: i32 = if (sx < ex) 1 else -1;
        const step_y: i32 = if (sy < ey) 1 else -1;
        var err: i32 = @intCast(dx);
        err -= @intCast(dy);

        while (true) {
            if (sx >= 0 and sy >= 0) {
                const ux: u16 = @intCast(sx);
                const uy: u16 = @intCast(sy);
                if (self.inBounds(ux, uy)) {
                    self.buf.setChar(self.absX(ux), self.absY(uy), char, s);
                }
            }

            if (sx == ex and sy == ey) break;

            const e2 = err * 2;
            if (e2 > -@as(i32, @intCast(dy))) {
                err -= @intCast(dy);
                sx += step_x;
            }
            if (e2 < @as(i32, @intCast(dx))) {
                err += @intCast(dx);
                sy += step_y;
            }
        }
    }

    /// Draw an outlined box using box-drawing characters.
    pub fn drawBox(self: Canvas, rect: Rect, s: Style) void {
        if (rect.width < 2 or rect.height < 2) return;
        const x1 = rect.x;
        const y1 = rect.y;
        const x2 = rect.x + rect.width - 1;
        const y2 = rect.y + rect.height - 1;

        self.setPixel(x1, y1, 0x250C, s); // ┌
        self.setPixel(x2, y1, 0x2510, s); // ┐
        self.setPixel(x1, y2, 0x2514, s); // └
        self.setPixel(x2, y2, 0x2518, s); // ┘
        self.drawHLine(x1 + 1, x2 - 1, y1, 0x2500, s); // ─
        self.drawHLine(x1 + 1, x2 - 1, y2, 0x2500, s);
        self.drawVLine(x1, y1 + 1, y2 - 1, 0x2502, s); // │
        self.drawVLine(x2, y1 + 1, y2 - 1, 0x2502, s);
    }

    /// Draw a circle outline using the midpoint circle algorithm.
    /// `cx`, `cy` = centre (canvas-relative); `r` = radius in cells.
    pub fn drawCircle(self: Canvas, cx: u16, cy: u16, r: u16, char: u21, s: Style) void {
        if (r == 0) {
            self.setPixel(cx, cy, char, s);
            return;
        }
        var x: i32 = @intCast(r);
        var y: i32 = 0;
        var err: i32 = 0;
        const icx: i32 = @intCast(cx);
        const icy: i32 = @intCast(cy);

        while (x >= y) {
            // 8-way symmetry
            const pts = [8][2]i32{
                .{ icx + x, icy + y }, .{ icx + y, icy + x },
                .{ icx - y, icy + x }, .{ icx - x, icy + y },
                .{ icx - x, icy - y }, .{ icx - y, icy - x },
                .{ icx + y, icy - x }, .{ icx + x, icy - y },
            };
            for (pts) |pt| {
                if (pt[0] >= 0 and pt[1] >= 0) {
                    const px: u16 = @intCast(pt[0]);
                    const py: u16 = @intCast(pt[1]);
                    self.setPixel(px, py, char, s);
                }
            }
            y += 1;
            err += 2 * y + 1;
            if (2 * (err - x) + 1 > 0) {
                x -= 1;
                err -= 2 * x - 1;
            }
        }
    }
};

test "Canvas drawLine does not panic" {
    const alloc = std.testing.allocator;
    var buf = try render.Buffer.init(alloc, 40, 20);
    defer buf.deinit();
    const area = buf.getArea();
    var cv = Canvas.init(area, &buf, .{});
    cv.drawLine(0, 0, 39, 19, '*', .{});
    cv.drawBox(.{ .x = 1, .y = 1, .width = 10, .height = 5 }, .{});
}
