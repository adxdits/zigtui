//! ANSI input parsing helpers (legacy + Kitty CSI u)

const std = @import("std");
const events = @import("../events/mod.zig");

pub const ParseResult = union(enum) {
    complete: Complete,
    incomplete,
    invalid: usize,
};

pub const Complete = struct {
    event: events.Event,
    consumed: usize,
};

pub fn parse(input: []const u8) ParseResult {
    if (input.len == 0) return .incomplete;

    if (input[0] != 0x1b) {
        return parseUtf8(input);
    }

    // NOTE: A lone ESC is immediately returned as an esc key-press. This means
    // a CSI u sequence (e.g. Shift+Enter -> ESC [ 1 3 ; 2 u) that is split
    // across two reads with only the ESC byte in the first chunk will be
    // misinterpreted as an esc key followed by literal characters. A
    // timeout-based approach (wait briefly for more bytes) would resolve this
    // but is left for a future improvement.
    if (input.len == 1) {
        return .{ .complete = .{ .event = .{ .key = .{ .code = .esc } }, .consumed = 1 } };
    }

    switch (input[1]) {
        '[' => return parseCsi(input),
        'O' => return parseSs3(input),
        else => return parseAlt(input),
    }
}

fn parseUtf8(input: []const u8) ParseResult {
    const first = input[0];
    if (first < 0x80) {
        return .{ .complete = .{ .event = parseAsciiControl(first), .consumed = 1 } };
    }

    const len = std.unicode.utf8ByteSequenceLength(first) catch {
        return .{ .invalid = 1 };
    };

    if (input.len < len) return .incomplete;

    const cp = std.unicode.utf8Decode(input[0..len]) catch {
        return .{ .invalid = len };
    };

    return .{ .complete = .{ .event = .{ .key = .{ .code = .{ .char = cp } } }, .consumed = len } };
}

fn parseAsciiControl(byte: u8) events.Event {
    return switch (byte) {
        '\r', '\n' => .{ .key = .{ .code = .enter } },
        '\t' => .{ .key = .{ .code = .tab } },
        127 => .{ .key = .{ .code = .backspace } },
        1...8, 11...12, 14...26 => |ctrl| .{
            .key = .{
                .code = .{ .char = @as(u21, ctrl - 1 + 'a') },
                .modifiers = .{ .ctrl = true },
            },
        },
        else => .{ .key = .{ .code = .{ .char = byte } } },
    };
}

fn parseAlt(input: []const u8) ParseResult {
    if (input.len < 2) return .incomplete;

    const c = input[1];
    if (c >= 32 and c < 127) {
        return .{ .complete = .{ .event = .{ .key = .{ .code = .{ .char = c }, .modifiers = .{ .alt = true } } }, .consumed = 2 } };
    }

    return .{ .invalid = 1 };
}

fn parseSs3(input: []const u8) ParseResult {
    if (input.len < 3) return .incomplete;

    const code: events.KeyCode = switch (input[2]) {
        'P' => .{ .f = 1 },
        'Q' => .{ .f = 2 },
        'R' => .{ .f = 3 },
        'S' => .{ .f = 4 },
        'H' => .home,
        'F' => .end,
        'A' => .up,
        'B' => .down,
        'C' => .right,
        'D' => .left,
        else => return .{ .invalid = 3 },
    };

    return .{ .complete = .{ .event = .{ .key = .{ .code = code } }, .consumed = 3 } };
}

fn parseCsi(input: []const u8) ParseResult {
    var i: usize = 2;
    while (i < input.len) : (i += 1) {
        const b = input[i];
        if (b >= 0x40 and b <= 0x7e) break;
    }

    if (i >= input.len) return .incomplete;

    const final = input[i];
    const params = input[2..i];
    const consumed = i + 1;

    switch (final) {
        'A', 'B', 'C', 'D', 'H', 'F', 'Z', 'P', 'Q', 'R', 'S' => {
            return parseCsiLetter(params, final, consumed);
        },
        '~' => return parseCsiTilde(params, consumed),
        'u' => return parseCsiU(params, consumed),
        'M', 'm' => {
            // SGR mouse: CSI < Cb ; Cx ; Cy M/m  (press/release)
            if (params.len > 0 and params[0] == '<') {
                return parseSgrMouse(params[1..], final, consumed);
            }
            return .{ .complete = .{ .event = .none, .consumed = consumed } };
        },
        else => return .{ .complete = .{ .event = .none, .consumed = consumed } },
    }
}

fn parseCsiLetter(params: []const u8, final: u8, consumed: usize) ParseResult {
    const parsed = parseParams(params);
    const mods = decodeModifiers(parsed.modifiers);

    const code: events.KeyCode = switch (final) {
        'A' => .up,
        'B' => .down,
        'C' => .right,
        'D' => .left,
        'H' => .home,
        'F' => .end,
        'Z' => .back_tab,
        'P' => .{ .f = 1 },
        'Q' => .{ .f = 2 },
        'R' => .{ .f = 3 },
        'S' => .{ .f = 4 },
        else => return .{ .complete = .{ .event = .none, .consumed = consumed } },
    };

    return .{ .complete = .{ .event = .{ .key = .{ .code = code, .modifiers = mods } }, .consumed = consumed } };
}

fn parseCsiTilde(params: []const u8, consumed: usize) ParseResult {
    const parsed = parseParams(params);
    const mods = decodeModifiers(parsed.modifiers);

    const code: events.KeyCode = switch (parsed.primary) {
        1, 7 => .home,
        4, 8 => .end,
        2 => .insert,
        3 => .delete,
        5 => .page_up,
        6 => .page_down,
        11 => .{ .f = 1 },
        12 => .{ .f = 2 },
        13 => .{ .f = 3 },
        14 => .{ .f = 4 },
        15 => .{ .f = 5 },
        17 => .{ .f = 6 },
        18 => .{ .f = 7 },
        19 => .{ .f = 8 },
        20 => .{ .f = 9 },
        21 => .{ .f = 10 },
        23 => .{ .f = 11 },
        24 => .{ .f = 12 },
        29 => .menu,
        else => return .{ .complete = .{ .event = .none, .consumed = consumed } },
    };

    return .{ .complete = .{ .event = .{ .key = .{ .code = code, .modifiers = mods } }, .consumed = consumed } };
}

fn parseCsiU(params: []const u8, consumed: usize) ParseResult {
    var key_code: ?u32 = null;
    var modifiers_value: u32 = 1;
    var event_type_value: u32 = 1;

    var field_index: u8 = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= params.len) : (i += 1) {
        if (i == params.len or params[i] == ';') {
            const field = params[start..i];
            switch (field_index) {
                0 => {
                    key_code = parseFirstSubfield(field) orelse return .{ .invalid = consumed };
                },
                1 => {
                    const parsed = parseTwoSubfields(field);
                    if (parsed.first) |v| modifiers_value = v;
                    if (parsed.second) |v| event_type_value = v;
                },
                // Field 2 carries text-as-codepoints (associated text).
                // Not yet supported; silently discarded.
                else => {},
            }
            field_index += 1;
            start = i + 1;
        }
    }

    const code_value = key_code orelse return .{ .invalid = consumed };
    if (code_value == 0) {
        return .{ .complete = .{ .event = .none, .consumed = consumed } };
    }

    const key_code_mapped = mapKeyCode(code_value) orelse return .{ .complete = .{ .event = .none, .consumed = consumed } };
    const modifiers = decodeModifiers(modifiers_value);
    const kind = decodeEventType(event_type_value);

    return .{ .complete = .{ .event = .{ .key = .{ .code = key_code_mapped, .modifiers = modifiers, .kind = kind } }, .consumed = consumed } };
}

fn parseSgrMouse(params: []const u8, final: u8, consumed: usize) ParseResult {
    // params = "Cb;Cx;Cy", final = 'M' (press/motion) or 'm' (release)
    var fields: [3]u32 = .{ 0, 0, 0 };
    var field_index: usize = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= params.len) : (i += 1) {
        if (i == params.len or params[i] == ';') {
            if (field_index < 3) {
                fields[field_index] = parseNumber(params[start..i]) orelse 0;
            }
            field_index += 1;
            start = i + 1;
        }
    }
    if (field_index < 3) return .{ .complete = .{ .event = .none, .consumed = consumed } };

    const cb = fields[0];
    const cx = fields[1];
    const cy = fields[2];

    // Decode button and event kind from cb
    const button_bits = cb & 0b11;
    const is_motion = (cb & 32) != 0;
    const is_scroll = (cb & 64) != 0;

    var kind: events.MouseEventKind = undefined;
    var button: events.MouseButton = .left;

    if (is_scroll) {
        kind = if (button_bits == 0) .scroll_up else .scroll_down;
    } else if (final == 'm') {
        kind = .up;
        button = switch (button_bits) {
            0 => .left,
            1 => .middle,
            2 => .right,
            else => .left,
        };
    } else if (is_motion) {
        kind = .moved;
        button = switch (button_bits) {
            0 => .left,
            1 => .middle,
            2 => .right,
            else => .left,
        };
    } else {
        kind = .down;
        button = switch (button_bits) {
            0 => .left,
            1 => .middle,
            2 => .right,
            else => .left,
        };
    }

    const modifiers = events.KeyModifiers{
        .shift = (cb & 4) != 0,
        .alt = (cb & 8) != 0,
        .ctrl = (cb & 16) != 0,
    };

    // SGR coordinates are 1-based
    const x: u16 = if (cx > 0) @intCast(cx - 1) else 0;
    const y: u16 = if (cy > 0) @intCast(cy - 1) else 0;

    return .{ .complete = .{ .event = .{ .mouse = .{
        .kind = kind,
        .button = button,
        .x = x,
        .y = y,
        .modifiers = modifiers,
    } }, .consumed = consumed } };
}

fn parseParams(params: []const u8) struct { primary: u32, modifiers: u32 } {
    var primary: u32 = 0;
    var modifiers: u32 = 1;

    var field_index: u8 = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= params.len) : (i += 1) {
        if (i == params.len or params[i] == ';') {
            const field = params[start..i];
            if (field_index == 0) {
                primary = parseNumber(field) orelse 0;
            } else if (field_index == 1) {
                modifiers = parseNumber(field) orelse 1;
            }
            field_index += 1;
            start = i + 1;
        }
    }

    return .{ .primary = primary, .modifiers = modifiers };
}

fn parseFirstSubfield(field: []const u8) ?u32 {
    var i: usize = 0;
    while (i <= field.len) : (i += 1) {
        if (i == field.len or field[i] == ':') {
            return parseNumber(field[0..i]);
        }
    }
    return null;
}

fn parseTwoSubfields(field: []const u8) struct { first: ?u32, second: ?u32 } {
    var first: ?u32 = null;
    var second: ?u32 = null;

    var index: u8 = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= field.len) : (i += 1) {
        if (i == field.len or field[i] == ':') {
            const part = field[start..i];
            const value = parseNumber(part);
            if (index == 0) first = value else if (index == 1) second = value;
            index += 1;
            start = i + 1;
        }
    }

    return .{ .first = first, .second = second };
}

fn parseNumber(bytes: []const u8) ?u32 {
    if (bytes.len == 0 or bytes.len > 10) return null;
    var value: u32 = 0;
    for (bytes) |b| {
        if (b < '0' or b > '9') return null;
        value = std.math.mul(u32, value, 10) catch return null;
        value = std.math.add(u32, value, @as(u32, b - '0')) catch return null;
    }
    return value;
}

fn decodeModifiers(value: u32) events.KeyModifiers {
    if (value == 0) return .{};
    const mask: u32 = value - 1;

    return .{
        .shift = (mask & 0b0000_0001) != 0,
        .alt = (mask & 0b0000_0010) != 0,
        .ctrl = (mask & 0b0000_0100) != 0,
        .super = (mask & 0b0000_1000) != 0,
        .hyper = (mask & 0b0001_0000) != 0,
        .meta = (mask & 0b0010_0000) != 0,
        .caps_lock = (mask & 0b0100_0000) != 0,
        .num_lock = (mask & 0b1000_0000) != 0,
    };
}

fn decodeEventType(value: u32) events.KeyEventKind {
    return switch (value) {
        2 => .repeat,
        3 => .release,
        else => .press,
    };
}

fn mapKeyCode(code: u32) ?events.KeyCode {
    switch (code) {
        9 => return .tab,
        13 => return .enter,
        27 => return .esc,
        127 => return .backspace,
        // Navigation keys (PUA, used under report-all-keys mode)
        57348 => return .insert,
        57349 => return .delete,
        57350 => return .left,
        57351 => return .right,
        57352 => return .up,
        57353 => return .down,
        57354 => return .page_up,
        57355 => return .page_down,
        57356 => return .home,
        57357 => return .end,
        // Lock/misc keys
        57358 => return .caps_lock,
        57359 => return .scroll_lock,
        57360 => return .num_lock,
        57361 => return .print_screen,
        57362 => return .pause,
        57363 => return .menu,
        // F13-F35 (PUA)
        57376...57398 => return .{ .f = @intCast(code - 57376 + 13) },
        else => {},
    }

    if (code >= 57344 and code <= 63743) {
        return .{ .functional = code };
    }

    if (code <= 0x10FFFF and !std.unicode.isSurrogateCodepoint(@intCast(code))) {
        return .{ .char = @intCast(code) };
    }

    return null;
}

test "parse CSI u basic" {
    const input = "\x1b[97;6u";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    try std.testing.expectEqual(@as(usize, input.len), complete.consumed);
    switch (complete.event) {
        .key => |key| {
            try std.testing.expectEqual(events.KeyCode{ .char = 'a' }, key.code);
            try std.testing.expect(key.modifiers.ctrl);
            try std.testing.expect(key.modifiers.shift);
            try std.testing.expect(!key.modifiers.alt);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse CSI u repeat" {
    const input = "\x1b[97;1:2u";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    switch (complete.event) {
        .key => |key| {
            try std.testing.expectEqual(events.KeyCode{ .char = 'a' }, key.code);
            try std.testing.expectEqual(events.KeyEventKind.repeat, key.kind);
            try std.testing.expect(!key.modifiers.ctrl);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse CSI modified arrow" {
    const input = "\x1b[1;5C";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    switch (complete.event) {
        .key => |key| {
            try std.testing.expectEqual(events.KeyCode.right, key.code);
            try std.testing.expect(key.modifiers.ctrl);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse utf8 multibyte" {
    const input = "\xE2\x82\xAC";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    switch (complete.event) {
        .key => |key| {
            try std.testing.expectEqual(events.KeyCode{ .char = 0x20AC }, key.code);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse incomplete CSI" {
    const input = "\x1b[1;5";
    const result = parse(input);
    try std.testing.expect(result == .incomplete);
}

test "parse SGR mouse left click" {
    const input = "\x1b[<0;10;20M";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    const complete = result.complete;
    try std.testing.expectEqual(@as(usize, input.len), complete.consumed);
    switch (complete.event) {
        .mouse => |mouse| {
            try std.testing.expectEqual(events.MouseEventKind.down, mouse.kind);
            try std.testing.expectEqual(events.MouseButton.left, mouse.button);
            try std.testing.expectEqual(@as(u16, 9), mouse.x);
            try std.testing.expectEqual(@as(u16, 19), mouse.y);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse SGR mouse release" {
    const input = "\x1b[<0;5;3m";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    switch (result.complete.event) {
        .mouse => |mouse| {
            try std.testing.expectEqual(events.MouseEventKind.up, mouse.kind);
            try std.testing.expectEqual(events.MouseButton.left, mouse.button);
            try std.testing.expectEqual(@as(u16, 4), mouse.x);
            try std.testing.expectEqual(@as(u16, 2), mouse.y);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse SGR mouse scroll up" {
    const input = "\x1b[<64;1;1M";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    switch (result.complete.event) {
        .mouse => |mouse| {
            try std.testing.expectEqual(events.MouseEventKind.scroll_up, mouse.kind);
        },
        else => return error.TestExpectedEqual,
    }
}

test "parse SGR mouse right click with ctrl" {
    const input = "\x1b[<18;15;10M";
    const result = parse(input);
    try std.testing.expect(result == .complete);
    switch (result.complete.event) {
        .mouse => |mouse| {
            try std.testing.expectEqual(events.MouseEventKind.down, mouse.kind);
            try std.testing.expectEqual(events.MouseButton.right, mouse.button);
            try std.testing.expect(mouse.modifiers.ctrl);
        },
        else => return error.TestExpectedEqual,
    }
}
