//! Style module - Colors, modifiers, and styling

const std = @import("std");

/// Color representation supporting various color modes
pub const Color = union(enum) {
    reset,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    gray,
    dark_gray,
    light_red,
    light_green,
    light_yellow,
    light_blue,
    light_magenta,
    light_cyan,
    light_white,
    rgb: RGB,
    indexed: u8,

    pub const RGB = struct {
        r: u8,
        g: u8,
        b: u8,
    };

    // Color constructor functions for convenience
    pub fn reset_() Color { return .reset; }
    pub fn black_() Color { return .black; }
    pub fn red_() Color { return .red; }
    pub fn green_() Color { return .green; }
    pub fn yellow_() Color { return .yellow; }
    pub fn blue_() Color { return .blue; }
    pub fn magenta_() Color { return .magenta; }
    pub fn cyan_() Color { return .cyan; }
    pub fn white_() Color { return .white; }
    pub fn gray_() Color { return .gray; }

    /// Check if two colors are equal
    pub fn eql(self: Color, other: Color) bool {
        if (@as(std.meta.Tag(Color), self) != @as(std.meta.Tag(Color), other)) {
            return false;
        }
        return switch (self) {
            .rgb => |rgb| rgb.r == other.rgb.r and rgb.g == other.rgb.g and rgb.b == other.rgb.b,
            .indexed => |idx| idx == other.indexed,
            else => true,
        };
    }

    /// Convert color to ANSI foreground code
    pub fn toFg(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[39m",
            .black => "\x1b[30m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",
            .gray => "\x1b[90m",
            .dark_gray => "\x1b[90m",
            .light_red => "\x1b[91m",
            .light_green => "\x1b[92m",
            .light_yellow => "\x1b[93m",
            .light_blue => "\x1b[94m",
            .light_magenta => "\x1b[95m",
            .light_cyan => "\x1b[96m",
            .light_white => "\x1b[97m",
            .rgb, .indexed => "", // Requires formatting
        };
    }

    /// Convert color to ANSI background code
    pub fn toBg(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[49m",
            .black => "\x1b[40m",
            .red => "\x1b[41m",
            .green => "\x1b[42m",
            .yellow => "\x1b[43m",
            .blue => "\x1b[44m",
            .magenta => "\x1b[45m",
            .cyan => "\x1b[46m",
            .white => "\x1b[47m",
            .gray => "\x1b[100m",
            .dark_gray => "\x1b[100m",
            .light_red => "\x1b[101m",
            .light_green => "\x1b[102m",
            .light_yellow => "\x1b[103m",
            .light_blue => "\x1b[104m",
            .light_magenta => "\x1b[105m",
            .light_cyan => "\x1b[106m",
            .light_white => "\x1b[107m",
            .rgb, .indexed => "", // Requires formatting
        };
    }
};

/// Text modifiers (bold, italic, etc.)
pub const Modifier = packed struct {
    bold: bool = false,
    dim: bool = false,
    italic: bool = false,
    underlined: bool = false,
    slow_blink: bool = false,
    rapid_blink: bool = false,
    reversed: bool = false,
    hidden: bool = false,
    crossed_out: bool = false,

    pub const NONE = Modifier{};
    pub const BOLD = Modifier{ .bold = true };
    pub const DIM = Modifier{ .dim = true };
    pub const ITALIC = Modifier{ .italic = true };
    pub const UNDERLINED = Modifier{ .underlined = true };
    pub const REVERSED = Modifier{ .reversed = true };

    /// Check if two modifiers are equal
    pub fn eql(self: Modifier, other: Modifier) bool {
        return @as(u9, @bitCast(self)) == @as(u9, @bitCast(other));
    }

    /// Merge two modifiers (OR operation)
    pub fn merge(self: Modifier, other: Modifier) Modifier {
        return @bitCast(@as(u9, @bitCast(self)) | @as(u9, @bitCast(other)));
    }

    /// Check if modifier is empty
    pub fn isEmpty(self: Modifier) bool {
        return @as(u9, @bitCast(self)) == 0;
    }

    /// Get ANSI codes for modifier
    pub fn toAnsi(self: Modifier, writer: anytype) !void {
        if (self.bold) try writer.writeAll("\x1b[1m");
        if (self.dim) try writer.writeAll("\x1b[2m");
        if (self.italic) try writer.writeAll("\x1b[3m");
        if (self.underlined) try writer.writeAll("\x1b[4m");
        if (self.slow_blink) try writer.writeAll("\x1b[5m");
        if (self.rapid_blink) try writer.writeAll("\x1b[6m");
        if (self.reversed) try writer.writeAll("\x1b[7m");
        if (self.hidden) try writer.writeAll("\x1b[8m");
        if (self.crossed_out) try writer.writeAll("\x1b[9m");
    }
};

/// Style combining foreground, background, and modifiers
pub const Style = struct {
    fg: ?Color = null,
    bg: ?Color = null,
    modifier: Modifier = .{},

    pub const DEFAULT = Style{};

    /// Merge two styles (other takes precedence)
    pub fn merge(self: Style, other: Style) Style {
        return .{
            .fg = other.fg orelse self.fg,
            .bg = other.bg orelse self.bg,
            .modifier = self.modifier.merge(other.modifier),
        };
    }

    /// Create style with foreground color
    pub fn fgColor(color: Color) Style {
        return .{ .fg = color };
    }

    /// Create style with background color
    pub fn bgColor(color: Color) Style {
        return .{ .bg = color };
    }

    /// Add modifier to style
    pub fn addModifier(self: Style, mod: Modifier) Style {
        return .{
            .fg = self.fg,
            .bg = self.bg,
            .modifier = self.modifier.merge(mod),
        };
    }

    /// Reset all styles
    pub fn reset(writer: anytype) !void {
        try writer.writeAll("\x1b[0m");
    }
};

test "Color equality" {
    const red: Color = .red;
    const blue: Color = .blue;
    try std.testing.expect(red.eql(.red));
    try std.testing.expect(!red.eql(blue));
    
    const rgb1 = Color{ .rgb = .{ .r = 255, .g = 0, .b = 0 } };
    const rgb2 = Color{ .rgb = .{ .r = 255, .g = 0, .b = 0 } };
    const rgb3 = Color{ .rgb = .{ .r = 0, .g = 255, .b = 0 } };
    
    try std.testing.expect(rgb1.eql(rgb2));
    try std.testing.expect(!rgb1.eql(rgb3));
}

test "Modifier operations" {
    const m1 = Modifier.BOLD;
    const m2 = Modifier.ITALIC;
    const merged = m1.merge(m2);
    
    try std.testing.expect(merged.bold);
    try std.testing.expect(merged.italic);
    try std.testing.expect(!merged.underlined);
}

test "Style merging" {
    const s1 = Style{ .fg = .red, .modifier = Modifier.BOLD };
    const s2 = Style{ .bg = .blue, .modifier = Modifier.ITALIC };
    const merged = s1.merge(s2);
    
    try std.testing.expect(merged.fg.?.eql(Color.red));
    try std.testing.expect(merged.bg.?.eql(Color.blue));
    try std.testing.expect(merged.modifier.bold);
    try std.testing.expect(merged.modifier.italic);
}
