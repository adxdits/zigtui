const std = @import("std");

const Range = struct { lo: u21, hi: u21 };

const zero_width = [_]Range{
    .{ .lo = 0x0300, .hi = 0x036F },
    .{ .lo = 0x0483, .hi = 0x0489 },
    .{ .lo = 0x0591, .hi = 0x05BD },
    .{ .lo = 0x05BF, .hi = 0x05BF },
    .{ .lo = 0x05C1, .hi = 0x05C2 },
    .{ .lo = 0x05C4, .hi = 0x05C5 },
    .{ .lo = 0x05C7, .hi = 0x05C7 },
    .{ .lo = 0x0610, .hi = 0x061A },
    .{ .lo = 0x064B, .hi = 0x065F },
    .{ .lo = 0x0670, .hi = 0x0670 },
    .{ .lo = 0x06D6, .hi = 0x06DC },
    .{ .lo = 0x06DF, .hi = 0x06E4 },
    .{ .lo = 0x06E7, .hi = 0x06E8 },
    .{ .lo = 0x06EA, .hi = 0x06ED },
    .{ .lo = 0x0711, .hi = 0x0711 },
    .{ .lo = 0x0730, .hi = 0x074A },
    .{ .lo = 0x07A6, .hi = 0x07B0 },
    .{ .lo = 0x07EB, .hi = 0x07F3 },
    .{ .lo = 0x0816, .hi = 0x0819 },
    .{ .lo = 0x081B, .hi = 0x0823 },
    .{ .lo = 0x0825, .hi = 0x0827 },
    .{ .lo = 0x0829, .hi = 0x082D },
    .{ .lo = 0x0900, .hi = 0x0902 },
    .{ .lo = 0x093A, .hi = 0x093A },
    .{ .lo = 0x093C, .hi = 0x093C },
    .{ .lo = 0x0941, .hi = 0x0948 },
    .{ .lo = 0x094D, .hi = 0x094D },
    .{ .lo = 0x0951, .hi = 0x0957 },
    .{ .lo = 0x0962, .hi = 0x0963 },
    .{ .lo = 0x0981, .hi = 0x0981 },
    .{ .lo = 0x09BC, .hi = 0x09BC },
    .{ .lo = 0x09C1, .hi = 0x09C4 },
    .{ .lo = 0x09CD, .hi = 0x09CD },
    .{ .lo = 0x0A01, .hi = 0x0A02 },
    .{ .lo = 0x0A3C, .hi = 0x0A3C },
    .{ .lo = 0x0A41, .hi = 0x0A42 },
    .{ .lo = 0x0A47, .hi = 0x0A48 },
    .{ .lo = 0x0A4B, .hi = 0x0A4D },
    .{ .lo = 0x0A81, .hi = 0x0A82 },
    .{ .lo = 0x0ABC, .hi = 0x0ABC },
    .{ .lo = 0x0AC1, .hi = 0x0AC5 },
    .{ .lo = 0x0AC7, .hi = 0x0AC8 },
    .{ .lo = 0x0ACD, .hi = 0x0ACD },
    .{ .lo = 0x0B01, .hi = 0x0B01 },
    .{ .lo = 0x0B3C, .hi = 0x0B3C },
    .{ .lo = 0x0B3F, .hi = 0x0B3F },
    .{ .lo = 0x0B41, .hi = 0x0B44 },
    .{ .lo = 0x0B4D, .hi = 0x0B4D },
    .{ .lo = 0x0BC0, .hi = 0x0BC0 },
    .{ .lo = 0x0BCD, .hi = 0x0BCD },
    .{ .lo = 0x0C3E, .hi = 0x0C40 },
    .{ .lo = 0x0C46, .hi = 0x0C48 },
    .{ .lo = 0x0C4A, .hi = 0x0C4D },
    .{ .lo = 0x0CBC, .hi = 0x0CBC },
    .{ .lo = 0x0CCC, .hi = 0x0CCD },
    .{ .lo = 0x0D41, .hi = 0x0D44 },
    .{ .lo = 0x0D4D, .hi = 0x0D4D },
    .{ .lo = 0x0DCA, .hi = 0x0DCA },
    .{ .lo = 0x0E31, .hi = 0x0E31 },
    .{ .lo = 0x0E34, .hi = 0x0E3A },
    .{ .lo = 0x0E47, .hi = 0x0E4E },
    .{ .lo = 0x0EB1, .hi = 0x0EB1 },
    .{ .lo = 0x0EB4, .hi = 0x0EBC },
    .{ .lo = 0x0EC8, .hi = 0x0ECD },
    .{ .lo = 0x0F35, .hi = 0x0F35 },
    .{ .lo = 0x0F37, .hi = 0x0F37 },
    .{ .lo = 0x0F39, .hi = 0x0F39 },
    .{ .lo = 0x0F71, .hi = 0x0F7E },
    .{ .lo = 0x0F80, .hi = 0x0F84 },
    .{ .lo = 0x0F86, .hi = 0x0F87 },
    .{ .lo = 0x0FC6, .hi = 0x0FC6 },
    .{ .lo = 0x102D, .hi = 0x1030 },
    .{ .lo = 0x1032, .hi = 0x1037 },
    .{ .lo = 0x1039, .hi = 0x103A },
    .{ .lo = 0x1058, .hi = 0x1059 },
    .{ .lo = 0x135F, .hi = 0x135F },
    .{ .lo = 0x1712, .hi = 0x1714 },
    .{ .lo = 0x1732, .hi = 0x1734 },
    .{ .lo = 0x1752, .hi = 0x1753 },
    .{ .lo = 0x1772, .hi = 0x1773 },
    .{ .lo = 0x17B4, .hi = 0x17B5 },
    .{ .lo = 0x17B7, .hi = 0x17BD },
    .{ .lo = 0x17C6, .hi = 0x17C6 },
    .{ .lo = 0x17C9, .hi = 0x17D3 },
    .{ .lo = 0x17DD, .hi = 0x17DD },
    .{ .lo = 0x180B, .hi = 0x180E },
    .{ .lo = 0x18A9, .hi = 0x18A9 },
    .{ .lo = 0x1920, .hi = 0x1922 },
    .{ .lo = 0x1927, .hi = 0x1928 },
    .{ .lo = 0x1932, .hi = 0x1932 },
    .{ .lo = 0x1939, .hi = 0x193B },
    .{ .lo = 0x1A17, .hi = 0x1A18 },
    .{ .lo = 0x1AB0, .hi = 0x1AFF },
    .{ .lo = 0x1B00, .hi = 0x1B03 },
    .{ .lo = 0x1B34, .hi = 0x1B34 },
    .{ .lo = 0x1B36, .hi = 0x1B3A },
    .{ .lo = 0x1B3C, .hi = 0x1B3C },
    .{ .lo = 0x1B42, .hi = 0x1B42 },
    .{ .lo = 0x1B6B, .hi = 0x1B73 },
    .{ .lo = 0x1DC0, .hi = 0x1DFF },
    .{ .lo = 0x200B, .hi = 0x200F },
    .{ .lo = 0x202A, .hi = 0x202E },
    .{ .lo = 0x2060, .hi = 0x2064 },
    .{ .lo = 0x206A, .hi = 0x206F },
    .{ .lo = 0x20D0, .hi = 0x20F0 },
    .{ .lo = 0x2CEF, .hi = 0x2CF1 },
    .{ .lo = 0x302A, .hi = 0x302F },
    .{ .lo = 0x3099, .hi = 0x309A },
    .{ .lo = 0xA806, .hi = 0xA806 },
    .{ .lo = 0xA80B, .hi = 0xA80B },
    .{ .lo = 0xA825, .hi = 0xA826 },
    .{ .lo = 0xFB1E, .hi = 0xFB1E },
    .{ .lo = 0xFE00, .hi = 0xFE0F },
    .{ .lo = 0xFE20, .hi = 0xFE2F },
    .{ .lo = 0xFEFF, .hi = 0xFEFF },
    .{ .lo = 0xFFF9, .hi = 0xFFFB },
    .{ .lo = 0x101FD, .hi = 0x101FD },
    .{ .lo = 0x10A01, .hi = 0x10A03 },
    .{ .lo = 0x10A0F, .hi = 0x10A0F },
    .{ .lo = 0x10A38, .hi = 0x10A3A },
    .{ .lo = 0x10A3F, .hi = 0x10A3F },
    .{ .lo = 0x11080, .hi = 0x11081 },
    .{ .lo = 0x110B3, .hi = 0x110B6 },
    .{ .lo = 0x110B9, .hi = 0x110BA },
    .{ .lo = 0x1D167, .hi = 0x1D169 },
    .{ .lo = 0x1D17B, .hi = 0x1D182 },
    .{ .lo = 0x1D185, .hi = 0x1D18B },
    .{ .lo = 0x1D1AA, .hi = 0x1D1AD },
    .{ .lo = 0x1D242, .hi = 0x1D244 },
    .{ .lo = 0xE0001, .hi = 0xE0001 },
    .{ .lo = 0xE0020, .hi = 0xE007F },
    .{ .lo = 0xE0100, .hi = 0xE01EF },
};

const wide = [_]Range{
    .{ .lo = 0x1100, .hi = 0x115F },
    .{ .lo = 0x231A, .hi = 0x231B },
    .{ .lo = 0x2329, .hi = 0x232A },
    .{ .lo = 0x23E9, .hi = 0x23EC },
    .{ .lo = 0x23F0, .hi = 0x23F0 },
    .{ .lo = 0x23F3, .hi = 0x23F3 },
    .{ .lo = 0x25FD, .hi = 0x25FE },
    .{ .lo = 0x2614, .hi = 0x2615 },
    .{ .lo = 0x2648, .hi = 0x2653 },
    .{ .lo = 0x267F, .hi = 0x267F },
    .{ .lo = 0x2693, .hi = 0x2693 },
    .{ .lo = 0x26A1, .hi = 0x26A1 },
    .{ .lo = 0x26AA, .hi = 0x26AB },
    .{ .lo = 0x26BD, .hi = 0x26BE },
    .{ .lo = 0x26C4, .hi = 0x26C5 },
    .{ .lo = 0x26CE, .hi = 0x26CE },
    .{ .lo = 0x26D4, .hi = 0x26D4 },
    .{ .lo = 0x26EA, .hi = 0x26EA },
    .{ .lo = 0x26F2, .hi = 0x26F3 },
    .{ .lo = 0x26F5, .hi = 0x26F5 },
    .{ .lo = 0x26FA, .hi = 0x26FA },
    .{ .lo = 0x26FD, .hi = 0x26FD },
    .{ .lo = 0x2705, .hi = 0x2705 },
    .{ .lo = 0x270A, .hi = 0x270B },
    .{ .lo = 0x2728, .hi = 0x2728 },
    .{ .lo = 0x274C, .hi = 0x274C },
    .{ .lo = 0x274E, .hi = 0x274E },
    .{ .lo = 0x2753, .hi = 0x2755 },
    .{ .lo = 0x2757, .hi = 0x2757 },
    .{ .lo = 0x2795, .hi = 0x2797 },
    .{ .lo = 0x27B0, .hi = 0x27B0 },
    .{ .lo = 0x27BF, .hi = 0x27BF },
    .{ .lo = 0x2B1B, .hi = 0x2B1C },
    .{ .lo = 0x2B50, .hi = 0x2B50 },
    .{ .lo = 0x2B55, .hi = 0x2B55 },
    .{ .lo = 0x2E80, .hi = 0x2E99 },
    .{ .lo = 0x2E9B, .hi = 0x2EF3 },
    .{ .lo = 0x2F00, .hi = 0x2FD5 },
    .{ .lo = 0x2FF0, .hi = 0x2FFB },
    .{ .lo = 0x3000, .hi = 0x303E },
    .{ .lo = 0x3041, .hi = 0x3096 },
    .{ .lo = 0x3099, .hi = 0x30FF },
    .{ .lo = 0x3105, .hi = 0x312F },
    .{ .lo = 0x3131, .hi = 0x318E },
    .{ .lo = 0x3190, .hi = 0x31E5 },
    .{ .lo = 0x31EF, .hi = 0x321E },
    .{ .lo = 0x3220, .hi = 0x3247 },
    .{ .lo = 0x3250, .hi = 0xA48C },
    .{ .lo = 0xA490, .hi = 0xA4C6 },
    .{ .lo = 0xA960, .hi = 0xA97C },
    .{ .lo = 0xAC00, .hi = 0xD7A3 },
    .{ .lo = 0xF900, .hi = 0xFAFF },
    .{ .lo = 0xFE10, .hi = 0xFE19 },
    .{ .lo = 0xFE30, .hi = 0xFE52 },
    .{ .lo = 0xFE54, .hi = 0xFE66 },
    .{ .lo = 0xFE68, .hi = 0xFE6B },
    .{ .lo = 0xFF01, .hi = 0xFF60 },
    .{ .lo = 0xFFE0, .hi = 0xFFE6 },
    .{ .lo = 0x16FE0, .hi = 0x16FE4 },
    .{ .lo = 0x16FF0, .hi = 0x16FF1 },
    .{ .lo = 0x17000, .hi = 0x187F7 },
    .{ .lo = 0x18800, .hi = 0x18CD5 },
    .{ .lo = 0x18D00, .hi = 0x18D08 },
    .{ .lo = 0x1AFF0, .hi = 0x1AFFE },
    .{ .lo = 0x1B000, .hi = 0x1B152 },
    .{ .lo = 0x1B164, .hi = 0x1B167 },
    .{ .lo = 0x1B170, .hi = 0x1B2FB },
    .{ .lo = 0x1F004, .hi = 0x1F004 },
    .{ .lo = 0x1F0CF, .hi = 0x1F0CF },
    .{ .lo = 0x1F18E, .hi = 0x1F18E },
    .{ .lo = 0x1F191, .hi = 0x1F19A },
    .{ .lo = 0x1F200, .hi = 0x1F320 },
    .{ .lo = 0x1F32D, .hi = 0x1F335 },
    .{ .lo = 0x1F337, .hi = 0x1F37C },
    .{ .lo = 0x1F37E, .hi = 0x1F393 },
    .{ .lo = 0x1F3A0, .hi = 0x1F3CA },
    .{ .lo = 0x1F3CF, .hi = 0x1F3D3 },
    .{ .lo = 0x1F3E0, .hi = 0x1F3F0 },
    .{ .lo = 0x1F3F4, .hi = 0x1F3F4 },
    .{ .lo = 0x1F3F8, .hi = 0x1F43E },
    .{ .lo = 0x1F440, .hi = 0x1F440 },
    .{ .lo = 0x1F442, .hi = 0x1F4FC },
    .{ .lo = 0x1F4FF, .hi = 0x1F53D },
    .{ .lo = 0x1F54B, .hi = 0x1F54E },
    .{ .lo = 0x1F550, .hi = 0x1F567 },
    .{ .lo = 0x1F57A, .hi = 0x1F57A },
    .{ .lo = 0x1F595, .hi = 0x1F596 },
    .{ .lo = 0x1F5A4, .hi = 0x1F5A4 },
    .{ .lo = 0x1F5FB, .hi = 0x1F64F },
    .{ .lo = 0x1F680, .hi = 0x1F6C5 },
    .{ .lo = 0x1F6CC, .hi = 0x1F6CC },
    .{ .lo = 0x1F6D0, .hi = 0x1F6D2 },
    .{ .lo = 0x1F6D5, .hi = 0x1F6D7 },
    .{ .lo = 0x1F6EB, .hi = 0x1F6EC },
    .{ .lo = 0x1F6F4, .hi = 0x1F6FC },
    .{ .lo = 0x1F7E0, .hi = 0x1F7EB },
    .{ .lo = 0x1F90C, .hi = 0x1F93A },
    .{ .lo = 0x1F93C, .hi = 0x1F945 },
    .{ .lo = 0x1F947, .hi = 0x1F9FF },
    .{ .lo = 0x1FA70, .hi = 0x1FA74 },
    .{ .lo = 0x1FA78, .hi = 0x1FA7C },
    .{ .lo = 0x1FA80, .hi = 0x1FA86 },
    .{ .lo = 0x1FA90, .hi = 0x1FAAC },
    .{ .lo = 0x1FAB0, .hi = 0x1FABA },
    .{ .lo = 0x1FAC0, .hi = 0x1FAC5 },
    .{ .lo = 0x1FAD0, .hi = 0x1FAD9 },
    .{ .lo = 0x1FAE0, .hi = 0x1FAE7 },
    .{ .lo = 0x1FAF0, .hi = 0x1FAF6 },
    .{ .lo = 0x20000, .hi = 0x2FFFD },
    .{ .lo = 0x30000, .hi = 0x3FFFD },
};

fn inRanges(ranges: []const Range, cp: u21) bool {
    var lo: usize = 0;
    var hi: usize = ranges.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const r = ranges[mid];
        if (cp < r.lo) {
            hi = mid;
        } else if (cp > r.hi) {
            lo = mid + 1;
        } else {
            return true;
        }
    }
    return false;
}

pub fn codepointWidth(cp: u21) u2 {
    if (cp < 0x20 or (cp >= 0x7F and cp < 0xA0)) return 0;
    if (cp < 0x300) return 1;
    if (inRanges(&zero_width, cp)) return 0;
    if (inRanges(&wide, cp)) return 2;
    return 1;
}

pub fn stringWidth(bytes: []const u8) usize {
    var total: usize = 0;
    var iter = std.unicode.Utf8View.initUnchecked(bytes).iterator();
    while (iter.nextCodepoint()) |cp| total += codepointWidth(cp);
    return total;
}

pub fn truncateToWidth(bytes: []const u8, max_columns: usize) []const u8 {
    var used: usize = 0;
    var end: usize = 0;
    var iter = std.unicode.Utf8View.initUnchecked(bytes).iterator();
    while (iter.nextCodepoint()) |cp| {
        const w = codepointWidth(cp);
        if (used + w > max_columns) break;
        used += w;
        end = iter.i;
    }
    return bytes[0..end];
}

test "ascii and control widths" {
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('a'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth(' '));
    try std.testing.expectEqual(@as(u2, 0), codepointWidth(0));
    try std.testing.expectEqual(@as(u2, 0), codepointWidth(0x7F));
}

test "wide and zero width codepoints" {
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('日'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth('한'));
    try std.testing.expectEqual(@as(u2, 2), codepointWidth(0x1F600));
    try std.testing.expectEqual(@as(u2, 0), codepointWidth(0x0301));
    try std.testing.expectEqual(@as(u2, 0), codepointWidth(0xFE0F));
}

test "box drawing stays narrow" {
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('─'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('╭'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('█'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('▀'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('⣿'));
    try std.testing.expectEqual(@as(u2, 1), codepointWidth('…'));
}

test "string width" {
    try std.testing.expectEqual(@as(usize, 5), stringWidth("hello"));
    try std.testing.expectEqual(@as(usize, 8), stringWidth("日本語ab"));
    try std.testing.expectEqual(@as(usize, 1), stringWidth("e\u{0301}"));
}

test "truncate to width never splits a wide codepoint" {
    try std.testing.expectEqualStrings("日", truncateToWidth("日本", 3));
    try std.testing.expectEqualStrings("日本", truncateToWidth("日本", 4));
    try std.testing.expectEqualStrings("", truncateToWidth("日本", 1));
}
