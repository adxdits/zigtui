//! Input event types

const std = @import("std");

/// Key modifiers (Ctrl, Alt, Shift, Meta)
pub const KeyModifiers = packed struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    meta: bool = false,
    super: bool = false,
    hyper: bool = false,
    caps_lock: bool = false,
    num_lock: bool = false,

    pub const NONE = KeyModifiers{};
    pub const SHIFT = KeyModifiers{ .shift = true };
    pub const CTRL = KeyModifiers{ .ctrl = true };
    pub const ALT = KeyModifiers{ .alt = true };
};

/// Key codes for keyboard input
pub const KeyCode = union(enum) {
    char: u21,
    f: u8, // F1-F35
    functional: u32,
    backspace,
    enter,
    left,
    right,
    up,
    down,
    home,
    end,
    page_up,
    page_down,
    tab,
    back_tab,
    delete,
    insert,
    esc,
    caps_lock,
    scroll_lock,
    num_lock,
    print_screen,
    pause,
    menu,

    /// Common key codes
    pub fn from_char(c: u21) KeyCode {
        return .{ .char = c };
    }
};

/// Key event type
pub const KeyEventKind = enum {
    press,
    repeat,
    release,
};

/// Keyboard event
pub const KeyEvent = struct {
    code: KeyCode,
    modifiers: KeyModifiers = .{},
    kind: KeyEventKind = .press,

    /// Check if Ctrl is pressed
    pub fn isCtrl(self: KeyEvent) bool {
        return self.modifiers.ctrl;
    }

    /// Check if Alt is pressed
    pub fn isAlt(self: KeyEvent) bool {
        return self.modifiers.alt;
    }

    /// Check if Shift is pressed
    pub fn isShift(self: KeyEvent) bool {
        return self.modifiers.shift;
    }

    /// Check if this is a character key
    pub fn isChar(self: KeyEvent, c: u21) bool {
        return switch (self.code) {
            .char => |ch| ch == c,
            else => false,
        };
    }
};

/// Mouse button
pub const MouseButton = enum {
    left,
    right,
    middle,
};

/// Mouse event type
pub const MouseEventKind = enum {
    down,
    up,
    drag,
    moved,
    scroll_up,
    scroll_down,
};

/// Mouse event
pub const MouseEvent = struct {
    kind: MouseEventKind,
    button: MouseButton,
    x: u16,
    y: u16,
    modifiers: KeyModifiers = .{},
};

/// Terminal event
pub const Event = union(enum) {
    key: KeyEvent,
    mouse: MouseEvent,
    resize: struct { width: u16, height: u16 },
    focus_gained,
    focus_lost,
    paste: []const u8,
    none,

    /// Check if this is a key event with specific character
    pub fn isChar(self: Event, c: u21) bool {
        return switch (self) {
            .key => |key| key.isChar(c),
            else => false,
        };
    }

    /// Check if this is a key event with specific code
    pub fn isKey(self: Event, code: KeyCode) bool {
        return switch (self) {
            .key => |key| std.meta.eql(key.code, code),
            else => false,
        };
    }

    /// Check if this is a resize event
    pub fn isResize(self: Event) bool {
        return self == .resize;
    }
};

test "KeyEvent creation" {
    const key = KeyEvent{
        .code = .{ .char = 'a' },
        .modifiers = .{ .ctrl = true },
    };
    
    try std.testing.expect(key.isCtrl());
    try std.testing.expect(!key.isAlt());
    try std.testing.expect(key.isChar('a'));
    try std.testing.expect(!key.isChar('b'));
}

test "Event matching" {
    const event = Event{ .key = .{ .code = .{ .char = 'q' } } };
    try std.testing.expect(event.isChar('q'));
    try std.testing.expect(!event.isChar('x'));
    try std.testing.expect(!event.isResize());
}
