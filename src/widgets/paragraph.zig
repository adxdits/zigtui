const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

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
