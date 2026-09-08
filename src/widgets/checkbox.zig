const std = @import("std");
const events = @import("../events/mod.zig");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");

const Buffer = render.Buffer;
const KeyEvent = events.KeyEvent;
const MouseEvent = events.MouseEvent;
const Rect = render.Rect;
const Style = style.Style;

pub const Checkbox = struct {
    label: []const u8,
    checked: bool = false,
    focused: bool = false,
    disabled: bool = false,
    style: Style = .{},
    checked_style: Style = .{},
    focused_style: Style = .{},
    disabled_style: Style = .{},
    checked_symbol: []const u8 = "[x]",
    unchecked_symbol: []const u8 = "[ ]",

    pub fn toggle(self: *Checkbox) void {
        if (!self.disabled) self.checked = !self.checked;
    }

    pub fn handleKey(self: *Checkbox, key: KeyEvent) bool {
        if (self.disabled or !self.focused or key.kind == .release) return false;

        switch (key.code) {
            .enter => self.toggle(),
            .char => |codepoint| {
                if (codepoint != ' ') return false;
                self.toggle();
            },
            else => return false,
        }
        return true;
    }

    pub fn handleMouse(self: *Checkbox, mouse: MouseEvent, area: Rect) bool {
        if (self.disabled or mouse.kind != .down or mouse.button != .left) return false;
        if (!area.contains(mouse.x, mouse.y)) return false;

        self.toggle();
        return true;
    }

    pub fn render(self: Checkbox, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        var base_style = self.style;
        if (self.focused) base_style = base_style.merge(self.focused_style);
        if (self.disabled) base_style = base_style.merge(self.disabled_style);

        const symbol = if (self.checked) self.checked_symbol else self.unchecked_symbol;
        const symbol_style = if (self.checked)
            base_style.merge(self.checked_style)
        else
            base_style;

        var written = buf.putString(area.x, area.y, symbol, area.width, symbol_style);
        if (written < area.width) {
            buf.setChar(area.x + written, area.y, ' ', base_style);
            written += 1;
        }
        written += buf.putString(area.x + written, area.y, self.label, area.width - written, base_style);

        while (written < area.width) : (written += 1) {
            buf.setChar(area.x + written, area.y, ' ', base_style);
        }
    }
};

test "Checkbox handles keyboard input while focused" {
    var checkbox = Checkbox{ .label = "Updates", .focused = true };

    try std.testing.expect(checkbox.handleKey(.{ .code = .{ .char = ' ' } }));
    try std.testing.expect(checkbox.checked);
    try std.testing.expect(checkbox.handleKey(.{ .code = .enter }));
    try std.testing.expect(!checkbox.checked);
    try std.testing.expect(!checkbox.handleKey(.{ .code = .{ .char = 'x' } }));
}

test "Checkbox ignores input when disabled or unfocused" {
    var checkbox = Checkbox{ .label = "Updates" };

    try std.testing.expect(!checkbox.handleKey(.{ .code = .enter }));
    checkbox.focused = true;
    checkbox.disabled = true;
    try std.testing.expect(!checkbox.handleKey(.{ .code = .enter }));
    try std.testing.expect(!checkbox.checked);
}

test "Checkbox handles left mouse clicks inside its area" {
    var checkbox = Checkbox{ .label = "Updates" };
    const area = Rect{ .x = 2, .y = 3, .width = 12, .height = 1 };

    try std.testing.expect(checkbox.handleMouse(.{ .kind = .down, .button = .left, .x = 4, .y = 3 }, area));
    try std.testing.expect(checkbox.checked);
    try std.testing.expect(!checkbox.handleMouse(.{ .kind = .down, .button = .left, .x = 4, .y = 4 }, area));
    try std.testing.expect(!checkbox.handleMouse(.{ .kind = .down, .button = .right, .x = 4, .y = 3 }, area));
}

test "Checkbox renders its selected symbol and truncated label" {
    var buf = try Buffer.init(std.testing.allocator, 7, 1);
    defer buf.deinit();

    const checkbox = Checkbox{ .label = "Ship it", .checked = true };
    checkbox.render(buf.getArea(), &buf);

    const expected = "[x] Shi";
    for (expected, 0..) |char, index| {
        try std.testing.expectEqual(@as(u21, char), buf.get(@intCast(index), 0).?.char);
    }
}
