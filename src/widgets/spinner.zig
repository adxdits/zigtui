const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

/// The set of frames used for the animation.
pub const SpinnerKind = enum {
    dots,
    line,
    arrow,
    bounce,
    bar,
};

pub const Spinner = struct {
    kind: SpinnerKind = .dots,
    frame: usize = 0,
    style: Style = .{},
    label: ?[]const u8 = null,
    label_style: Style = .{},

    const FRAMES_DOTS = [_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };
    const FRAMES_LINE = [_][]const u8{ "-", "\\", "|", "/" };
    const FRAMES_ARROW = [_][]const u8{ "←", "↖", "↑", "↗", "→", "↘", "↓", "↙" };
    const FRAMES_BOUNCE = [_][]const u8{ "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█", "▉", "▊", "▌", "▍", "▎" };
    const FRAMES_BAR = [_][]const u8{ "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂" };

    fn frames(self: Spinner) []const []const u8 {
        return switch (self.kind) {
            .dots => &FRAMES_DOTS,
            .line => &FRAMES_LINE,
            .arrow => &FRAMES_ARROW,
            .bounce => &FRAMES_BOUNCE,
            .bar => &FRAMES_BAR,
        };
    }

    /// Return the current animation frame string.
    pub fn current(self: Spinner) []const u8 {
        const f = self.frames();
        return f[self.frame % f.len];
    }

    /// Advance the animation by one step.
    pub fn tick(self: *Spinner) void {
        self.frame = (self.frame + 1) % self.frames().len;
    }

    /// Reset to the first frame.
    pub fn reset(self: *Spinner) void {
        self.frame = 0;
    }

    pub fn render(self: Spinner, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        const f = self.current();
        buf.setString(area.x, area.y, f, self.style);

        if (self.label) |lbl| {
            // frame is typically 1-2 display columns; leave 1 space gap
            const frame_cols: u16 = blk: {
                var count: u16 = 0;
                var iter = std.unicode.Utf8View.initUnchecked(f).iterator();
                while (iter.nextCodepoint()) |_| count += 1;
                break :blk count;
            };
            const label_x = area.x + frame_cols + 1;
            if (label_x < area.x + area.width) {
                const available = area.x + area.width - label_x;
                buf.setStringTruncated(label_x, area.y, lbl, available, self.label_style);
            }
        }
    }
};

test "Spinner tick wraps" {
    var sp = Spinner{ .kind = .line };
    // FRAMES_LINE has 4 entries
    sp.frame = 3;
    sp.tick();
    try std.testing.expectEqual(@as(usize, 0), sp.frame);
}

test "Spinner current returns valid string" {
    const sp = Spinner{ .kind = .dots };
    const f = sp.current();
    try std.testing.expect(f.len > 0);
}
