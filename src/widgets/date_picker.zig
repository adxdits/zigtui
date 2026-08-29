const std = @import("std");
const events = @import("../events/mod.zig");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");

const Buffer = render.Buffer;
const KeyEvent = events.KeyEvent;
const Rect = render.Rect;
const Style = style.Style;

pub const Date = struct {
    year: u16,
    month: u8,
    day: u8,

    pub fn isValid(self: Date) bool {
        return self.year > 0 and self.month >= 1 and self.month <= 12 and
            self.day >= 1 and self.day <= daysInMonth(self.year, self.month);
    }
};

pub const DatePicker = struct {
    selected: Date,
    style: Style = .{},
    header_style: Style = .{},
    weekday_style: Style = .{},
    selected_style: Style = .{},
    outside_style: Style = .{},

    pub fn init(date: Date) !DatePicker {
        if (!date.isValid()) return error.InvalidDate;
        return .{ .selected = date };
    }

    pub fn handleKey(self: *DatePicker, key: KeyEvent) bool {
        if (key.kind == .release) return false;
        switch (key.code) {
            .left => self.moveDays(-1),
            .right => self.moveDays(1),
            .up => self.moveDays(-7),
            .down => self.moveDays(7),
            .page_up => self.moveMonths(-1),
            .page_down => self.moveMonths(1),
            .home => self.selected.day = 1,
            .end => self.selected.day = daysInMonth(self.selected.year, self.selected.month),
            else => return false,
        }
        return true;
    }

    pub fn moveDays(self: *DatePicker, delta: i8) void {
        var remaining = delta;
        while (remaining < 0) : (remaining += 1) self.previousDay();
        while (remaining > 0) : (remaining -= 1) self.nextDay();
    }

    pub fn moveMonths(self: *DatePicker, delta: i8) void {
        var month_index = @as(i32, self.selected.year) * 12 + @as(i32, self.selected.month) - 1 + delta;
        if (month_index < 12) month_index = 12;
        self.selected.year = @intCast(@divFloor(month_index, 12));
        self.selected.month = @intCast(@mod(month_index, 12) + 1);
        self.selected.day = @min(self.selected.day, daysInMonth(self.selected.year, self.selected.month));
    }

    pub fn render(self: DatePicker, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;
        fill(area, buf, self.style);

        var title_buf: [32]u8 = undefined;
        const title = std.fmt.bufPrint(&title_buf, "{s} {d}", .{ monthNames[self.selected.month - 1], self.selected.year }) catch return;
        const title_width: u16 = @intCast(@min(title.len, area.width));
        const title_x = area.x + (area.width - title_width) / 2;
        buf.setString(title_x, area.y, title[0..title_width], self.style.merge(self.header_style));

        if (area.height < 2) return;
        const weekdays = "Su Mo Tu We Th Fr Sa";
        buf.setString(area.x, area.y + 1, weekdays[0..@min(weekdays.len, area.width)], self.style.merge(self.weekday_style));
        if (area.height < 3) return;

        const first_weekday = weekday(self.selected.year, self.selected.month, 1);
        const month_days = daysInMonth(self.selected.year, self.selected.month);
        var day: u8 = 1;
        while (day <= month_days) : (day += 1) {
            const position = @as(u16, first_weekday) + day - 1;
            const row = position / 7;
            const column = position % 7;
            const y = area.y + 2 + row;
            const x = area.x + column * 3;
            if (y >= area.y + area.height or x >= area.x + area.width) continue;

            var day_buf: [2]u8 = .{ ' ', ' ' };
            if (day >= 10) day_buf[0] = '0' + day / 10;
            day_buf[1] = '0' + day % 10;
            const day_style = if (day == self.selected.day) self.style.merge(self.selected_style) else self.style;
            buf.setString(x, y, day_buf[0..@min(day_buf.len, area.x + area.width - x)], day_style);
        }
    }

    fn nextDay(self: *DatePicker) void {
        if (self.selected.day < daysInMonth(self.selected.year, self.selected.month)) {
            self.selected.day += 1;
        } else {
            self.selected.day = 1;
            self.moveMonths(1);
        }
    }

    fn previousDay(self: *DatePicker) void {
        if (self.selected.day > 1) {
            self.selected.day -= 1;
        } else if (self.selected.month > 1 or self.selected.year > 1) {
            self.moveMonths(-1);
            self.selected.day = daysInMonth(self.selected.year, self.selected.month);
        }
    }
};

pub fn isLeapYear(year: u16) bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}

pub fn daysInMonth(year: u16, month: u8) u8 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => 0,
    };
}

fn weekday(year: u16, month: u8, day: u8) u8 {
    var y: i32 = year;
    const offsets = [_]u8{ 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 };
    if (month < 3) y -= 1;
    return @intCast(@mod(y + @divFloor(y, 4) - @divFloor(y, 100) + @divFloor(y, 400) + offsets[month - 1] + day, 7));
}

fn fill(area: Rect, buf: *Buffer, cell_style: Style) void {
    var y = area.y;
    while (y < area.y + area.height and y < buf.height) : (y += 1) {
        var x = area.x;
        while (x < area.x + area.width and x < buf.width) : (x += 1) {
            buf.setChar(x, y, ' ', cell_style);
        }
    }
}

const monthNames = [_][]const u8{
    "January", "February", "March",     "April",   "May",      "June",
    "July",    "August",   "September", "October", "November", "December",
};

test "Date validates leap days" {
    try std.testing.expect((Date{ .year = 2024, .month = 2, .day = 29 }).isValid());
    try std.testing.expect(!(Date{ .year = 2025, .month = 2, .day = 29 }).isValid());
}

test "DatePicker moves across month boundaries" {
    var picker = try DatePicker.init(.{ .year = 2024, .month = 2, .day = 28 });
    picker.moveDays(1);
    try std.testing.expectEqual(Date{ .year = 2024, .month = 2, .day = 29 }, picker.selected);
    picker.moveDays(1);
    try std.testing.expectEqual(Date{ .year = 2024, .month = 3, .day = 1 }, picker.selected);
}

test "DatePicker clamps day while changing month" {
    var picker = try DatePicker.init(.{ .year = 2025, .month = 1, .day = 31 });
    picker.moveMonths(1);
    try std.testing.expectEqual(Date{ .year = 2025, .month = 2, .day = 28 }, picker.selected);
}

test "DatePicker handles navigation keys" {
    var picker = try DatePicker.init(.{ .year = 2025, .month = 8, .day = 29 });
    try std.testing.expect(picker.handleKey(.{ .code = .right }));
    try std.testing.expectEqual(@as(u8, 30), picker.selected.day);
    try std.testing.expect(picker.handleKey(.{ .code = .page_down }));
    try std.testing.expectEqual(@as(u8, 9), picker.selected.month);
}
