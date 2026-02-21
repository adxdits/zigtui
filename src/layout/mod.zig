const std = @import("std");
const render = @import("../render/mod.zig");
const Rect = render.Rect;
const Allocator = std.mem.Allocator;

pub const Constraint = union(enum) {
    fixed: u16,
    min: u16,
    max: u16,
    percentage: u8,
    ratio: struct { numerator: u32, denominator: u32 },
    length: u16,

    pub fn apply(self: Constraint, available: u16) u16 {
        return switch (self) {
            .fixed => |f| @min(f, available),
            .min => |m| @min(m, available),
            .max => |m| @min(m, available),
            .percentage => |p| blk: {
                const pct = @min(p, 100);
                break :blk @intCast((@as(u32, available) * pct) / 100);
            },
            .ratio => |r| blk: {
                if (r.denominator == 0) break :blk 0;
                break :blk @intCast((@as(u32, available) * r.numerator) / r.denominator);
            },
            .length => |l| @min(l, available),
        };
    }
};

pub const Direction = enum {
    horizontal,
    vertical,
};

pub const Margin = struct {
    left: u16 = 0,
    right: u16 = 0,
    top: u16 = 0,
    bottom: u16 = 0,

    pub const NONE = Margin{};
    pub const ALL_1 = Margin{ .left = 1, .right = 1, .top = 1, .bottom = 1 };
    pub const ALL_2 = Margin{ .left = 2, .right = 2, .top = 2, .bottom = 2 };

    pub fn apply(self: Margin, rect: Rect) Rect {
        const horizontal = self.left + self.right;
        const vertical = self.top + self.bottom;

        if (horizontal > rect.width or vertical > rect.height) {
            return .{ .x = rect.x, .y = rect.y, .width = 0, .height = 0 };
        }

        return .{
            .x = rect.x + self.left,
            .y = rect.y + self.top,
            .width = rect.width - horizontal,
            .height = rect.height - vertical,
        };
    }
};

pub const Alignment = enum {
    left,
    center,
    right,
};

pub const LayoutBuilder = struct {
    _direction: Direction = .vertical,
    _constraints: []const Constraint = &[_]Constraint{},
    _margin: Margin = .{},

    pub fn direction(self: LayoutBuilder, dir: Direction) LayoutBuilder {
        var copy = self;
        copy._direction = dir;
        return copy;
    }

    pub fn constraints(self: LayoutBuilder, cons: []const Constraint) LayoutBuilder {
        var copy = self;
        copy._constraints = cons;
        return copy;
    }

    pub fn margin(self: LayoutBuilder, m: u16) LayoutBuilder {
        var copy = self;
        copy._margin = Margin{ .left = m, .right = m, .top = m, .bottom = m };
        return copy;
    }

    pub fn split(self: LayoutBuilder, allocator: Allocator, area: Rect) ![]Rect {
        const layout = Layout{
            .direction = self._direction,
            .constraints = self._constraints,
            .margin = self._margin,
        };
        return layout.split(area, allocator);
    }
};

pub const Layout = struct {
    direction: Direction,
    constraints: []const Constraint,
    margin: Margin = .{},

    pub fn default() LayoutBuilder {
        return LayoutBuilder{};
    }

    pub fn split(self: Layout, area: Rect, allocator: Allocator) ![]Rect {
        // Apply margin
        const inner = self.margin.apply(area);
        if (inner.width == 0 or inner.height == 0) {
            return &[_]Rect{};
        }

        // Calculate available space
        const available = switch (self.direction) {
            .horizontal => inner.width,
            .vertical => inner.height,
        };

        // Allocate results
        const results = try allocator.alloc(Rect, self.constraints.len);
        errdefer allocator.free(results);

        if (self.constraints.len == 0) return results;

        // First pass: calculate fixed and minimum sizes
        var total_fixed: u32 = 0;
        var flex_count: u32 = 0;

        for (self.constraints) |constraint| {
            switch (constraint) {
                .fixed => |f| total_fixed += f,
                .min => |m| total_fixed += m,
                .percentage, .ratio, .length, .max => flex_count += 1,
            }
        }

        // Calculate remaining space for flexible constraints
        const remaining: u32 = if (total_fixed > available)
            0
        else
            @as(u32, available) - total_fixed;

        // Second pass: distribute space
        var offset: u16 = 0;
        for (self.constraints, results) |constraint, *result| {
            const size: u16 = switch (constraint) {
                .fixed => |f| @min(f, available - offset),
                .min => |m| @min(m, available - offset),
                .max => |m| @min(m, @as(u16, @intCast(remaining / @max(flex_count, 1)))),
                .percentage => |p| blk: {
                    const pct = @min(p, 100);
                    const size_u32 = (@as(u32, remaining) * pct) / 100;
                    break :blk @intCast(@min(size_u32, available - offset));
                },
                .ratio => |r| blk: {
                    if (r.denominator == 0) break :blk 0;
                    const size_u32 = (@as(u32, remaining) * r.numerator) / r.denominator;
                    break :blk @intCast(@min(size_u32, available - offset));
                },
                .length => |l| @min(l, available - offset),
            };

            result.* = switch (self.direction) {
                .horizontal => Rect{
                    .x = inner.x + offset,
                    .y = inner.y,
                    .width = size,
                    .height = inner.height,
                },
                .vertical => Rect{
                    .x = inner.x,
                    .y = inner.y + offset,
                    .width = inner.width,
                    .height = size,
                },
            };

            offset += size;
            if (offset >= available) break;
        }

        return results;
    }
};

test "Constraint application" {
    try std.testing.expectEqual(@as(u16, 50), (Constraint{ .fixed = 50 }).apply(100));
    try std.testing.expectEqual(@as(u16, 50), (Constraint{ .percentage = 50 }).apply(100));
    try std.testing.expectEqual(@as(u16, 25), (Constraint{ .ratio = .{ .numerator = 1, .denominator = 4 } }).apply(100));
}

test "Margin application" {
    const rect = Rect{ .x = 0, .y = 0, .width = 10, .height = 10 };
    const margin = Margin{ .left = 1, .right = 1, .top = 1, .bottom = 1 };
    const result = margin.apply(rect);

    try std.testing.expectEqual(@as(u16, 1), result.x);
    try std.testing.expectEqual(@as(u16, 1), result.y);
    try std.testing.expectEqual(@as(u16, 8), result.width);
    try std.testing.expectEqual(@as(u16, 8), result.height);
}

test "Layout split horizontal" {
    const allocator = std.testing.allocator;
    const area = Rect{ .x = 0, .y = 0, .width = 100, .height = 20 };

    const layout = Layout{
        .direction = .horizontal,
        .constraints = &[_]Constraint{
            .{ .percentage = 50 },
            .{ .percentage = 50 },
        },
    };

    const results = try layout.split(area, allocator);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 2), results.len);
    try std.testing.expectEqual(@as(u16, 0), results[0].x);
    try std.testing.expectEqual(@as(u16, 50), results[0].width);
    try std.testing.expectEqual(@as(u16, 50), results[1].x);
    try std.testing.expectEqual(@as(u16, 50), results[1].width);
}
