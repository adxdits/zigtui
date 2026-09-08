const std = @import("std");
const events = @import("../events/mod.zig");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");

const Buffer = render.Buffer;
const KeyEvent = events.KeyEvent;
const MouseEvent = events.MouseEvent;
const Rect = render.Rect;
const Style = style.Style;

pub const RadioItem = struct {
    label: []const u8,
    style: Style = .{},
};

pub const RadioGroup = struct {
    items: []const RadioItem,
    selected: ?usize = null,
    focused: bool = false,
    disabled: bool = false,
    style: Style = .{},
    selected_style: Style = .{},
    focused_style: Style = .{},
    disabled_style: Style = .{},
    selected_symbol: []const u8 = "(*)",
    unselected_symbol: []const u8 = "( )",

    pub fn select(self: *RadioGroup, index: usize) bool {
        if (self.disabled or index >= self.items.len) return false;
        self.selected = index;
        return true;
    }

    pub fn selectNext(self: *RadioGroup) void {
        if (self.disabled or self.items.len == 0) return;
        self.selected = if (self.selected) |selected|
            (selected + 1) % self.items.len
        else
            0;
    }

    pub fn selectPrevious(self: *RadioGroup) void {
        if (self.disabled or self.items.len == 0) return;
        self.selected = if (self.selected) |selected|
            if (selected == 0) self.items.len - 1 else selected - 1
        else
            self.items.len - 1;
    }

    pub fn handleKey(self: *RadioGroup, key: KeyEvent) bool {
        if (self.disabled or !self.focused or self.items.len == 0 or key.kind == .release) return false;

        switch (key.code) {
            .down, .right => self.selectNext(),
            .up, .left => self.selectPrevious(),
            .enter => {
                if (self.selected == null) self.selected = 0;
            },
            .char => |codepoint| {
                if (codepoint != ' ') return false;
                if (self.selected == null) self.selected = 0;
            },
            else => return false,
        }
        return true;
    }

    pub fn handleMouse(self: *RadioGroup, mouse: MouseEvent, area: Rect) bool {
        if (self.disabled or mouse.kind != .down or mouse.button != .left) return false;
        if (!area.contains(mouse.x, mouse.y)) return false;

        const index: usize = mouse.y - area.y;
        return self.select(index);
    }

    pub fn render(self: RadioGroup, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        var row: u16 = 0;
        while (row < area.height) : (row += 1) {
            const index: usize = row;
            var row_style = self.style;
            var written: u16 = 0;

            if (index < self.items.len) {
                const item = self.items[index];
                const is_selected = if (self.selected) |selected| selected == index else false;

                row_style = row_style.merge(item.style);
                if (is_selected) row_style = row_style.merge(self.selected_style);
                if (self.focused and is_selected) row_style = row_style.merge(self.focused_style);
                if (self.disabled) row_style = row_style.merge(self.disabled_style);

                const symbol = if (is_selected) self.selected_symbol else self.unselected_symbol;
                written = buf.putString(area.x, area.y + row, symbol, area.width, row_style);
                if (written < area.width) {
                    buf.setChar(area.x + written, area.y + row, ' ', row_style);
                    written += 1;
                }
                written += buf.putString(area.x + written, area.y + row, item.label, area.width - written, row_style);
            } else if (self.disabled) {
                row_style = row_style.merge(self.disabled_style);
            }

            while (written < area.width) : (written += 1) {
                buf.setChar(area.x + written, area.y + row, ' ', row_style);
            }
        }
    }
};

test "RadioGroup navigates and wraps" {
    const items = [_]RadioItem{
        .{ .label = "Small" },
        .{ .label = "Medium" },
        .{ .label = "Large" },
    };
    var radio = RadioGroup{ .items = &items, .focused = true };

    try std.testing.expect(radio.handleKey(.{ .code = .down }));
    try std.testing.expectEqual(@as(?usize, 0), radio.selected);
    radio.selectPrevious();
    try std.testing.expectEqual(@as(?usize, 2), radio.selected);
    radio.selectNext();
    try std.testing.expectEqual(@as(?usize, 0), radio.selected);
}

test "RadioGroup requires focus and ignores input when disabled" {
    const items = [_]RadioItem{.{ .label = "One" }};
    var radio = RadioGroup{ .items = &items };

    try std.testing.expect(!radio.handleKey(.{ .code = .enter }));
    radio.focused = true;
    try std.testing.expect(radio.handleKey(.{ .code = .{ .char = ' ' } }));
    try std.testing.expectEqual(@as(?usize, 0), radio.selected);
    radio.disabled = true;
    try std.testing.expect(!radio.handleKey(.{ .code = .down }));
}

test "RadioGroup selects a clicked row" {
    const items = [_]RadioItem{
        .{ .label = "One" },
        .{ .label = "Two" },
    };
    var radio = RadioGroup{ .items = &items };
    const area = Rect{ .x = 3, .y = 4, .width = 10, .height = 3 };

    try std.testing.expect(radio.handleMouse(.{ .kind = .down, .button = .left, .x = 5, .y = 5 }, area));
    try std.testing.expectEqual(@as(?usize, 1), radio.selected);
    try std.testing.expect(!radio.handleMouse(.{ .kind = .down, .button = .left, .x = 5, .y = 6 }, area));
}

test "RadioGroup renders selected and unselected rows" {
    const items = [_]RadioItem{
        .{ .label = "One" },
        .{ .label = "Two" },
    };
    const radio = RadioGroup{ .items = &items, .selected = 1 };
    var buf = try Buffer.init(std.testing.allocator, 8, 2);
    defer buf.deinit();

    radio.render(buf.getArea(), &buf);

    const expected = [_][]const u8{ "( ) One ", "(*) Two " };
    for (expected, 0..) |line, row| {
        for (line, 0..) |char, column| {
            try std.testing.expectEqual(@as(u21, char), buf.get(@intCast(column), @intCast(row)).?.char);
        }
    }
}
