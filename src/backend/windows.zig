//! Windows console backend

const std = @import("std");
const builtin = @import("builtin");
const Backend = @import("mod.zig").Backend;
const Error = @import("mod.zig").Error;
const events = @import("../events/mod.zig");
const render = @import("../render/mod.zig");
const Allocator = std.mem.Allocator;

const is_windows = builtin.os.tag == .windows;

// Import Windows API types from std.os.windows
const windows = if (is_windows) std.os.windows else void;
const kernel32 = if (is_windows) std.os.windows.kernel32 else void;
const HANDLE = if (is_windows) windows.HANDLE else void;
const DWORD = if (is_windows) windows.DWORD else u32;
const WORD = if (is_windows) windows.WORD else u16;
const BOOL = if (is_windows) windows.BOOL else i32;
const UINT = if (is_windows) windows.UINT else u32;
const COORD = if (is_windows) windows.COORD else void;
const SMALL_RECT = if (is_windows) windows.SMALL_RECT else void;
const CONSOLE_SCREEN_BUFFER_INFO = if (is_windows) windows.CONSOLE_SCREEN_BUFFER_INFO else void;

// Console input/output mode flags
const ENABLE_ECHO_INPUT: DWORD = 0x0004;
const ENABLE_LINE_INPUT: DWORD = 0x0002;
const ENABLE_PROCESSED_INPUT: DWORD = 0x0001;
const ENABLE_WINDOW_INPUT: DWORD = 0x0008;
const ENABLE_VIRTUAL_TERMINAL_PROCESSING: DWORD = 0x0004;
const ENABLE_VIRTUAL_TERMINAL_INPUT: DWORD = 0x0200;

// Standard handles
const STD_INPUT_HANDLE: DWORD = @bitCast(@as(i32, -10));
const STD_OUTPUT_HANDLE: DWORD = @bitCast(@as(i32, -11));

// Console cursor info structure
const CONSOLE_CURSOR_INFO = extern struct {
    dwSize: DWORD,
    bVisible: BOOL,
};

// External Windows API functions not in std.os.windows.kernel32
extern "kernel32" fn GetConsoleCursorInfo(
    hConsoleOutput: HANDLE,
    lpConsoleCursorInfo: *CONSOLE_CURSOR_INFO,
) callconv(.winapi) BOOL;

extern "kernel32" fn SetConsoleCursorInfo(
    hConsoleOutput: HANDLE,
    lpConsoleCursorInfo: *const CONSOLE_CURSOR_INFO,
) callconv(.winapi) BOOL;

extern "kernel32" fn WriteConsoleA(
    hConsoleOutput: HANDLE,
    lpBuffer: [*]const u8,
    nNumberOfCharsToWrite: DWORD,
    lpNumberOfCharsWritten: ?*DWORD,
    lpReserved: ?*anyopaque,
) callconv(.winapi) BOOL;

extern "kernel32" fn ReadConsoleInputW(
    hConsoleInput: HANDLE,
    lpBuffer: [*]INPUT_RECORD,
    nLength: DWORD,
    lpNumberOfEventsRead: *DWORD,
) callconv(.winapi) BOOL;

extern "kernel32" fn GetNumberOfConsoleInputEvents(
    hConsoleInput: HANDLE,
    lpcNumberOfEvents: *DWORD,
) callconv(.winapi) BOOL;

extern "kernel32" fn WaitForSingleObject(
    hHandle: HANDLE,
    dwMilliseconds: DWORD,
) callconv(.winapi) DWORD;

// Input record structures for reading console input
const INPUT_RECORD = extern struct {
    EventType: WORD,
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        MouseEvent: MOUSE_EVENT_RECORD,
        WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        MenuEvent: MENU_EVENT_RECORD,
        FocusEvent: FOCUS_EVENT_RECORD,
    },
};

const KEY_EVENT_RECORD = extern struct {
    bKeyDown: BOOL,
    wRepeatCount: WORD,
    wVirtualKeyCode: WORD,
    wVirtualScanCode: WORD,
    uChar: extern union {
        UnicodeChar: u16,
        AsciiChar: u8,
    },
    dwControlKeyState: DWORD,
};

const MOUSE_EVENT_RECORD = extern struct {
    dwMousePosition: COORD,
    dwButtonState: DWORD,
    dwControlKeyState: DWORD,
    dwEventFlags: DWORD,
};

const WINDOW_BUFFER_SIZE_RECORD = extern struct {
    dwSize: COORD,
};

const MENU_EVENT_RECORD = extern struct {
    dwCommandId: UINT,
};

const FOCUS_EVENT_RECORD = extern struct {
    bSetFocus: BOOL,
};

// Event types
const KEY_EVENT: WORD = 0x0001;
const MOUSE_EVENT: WORD = 0x0002;
const WINDOW_BUFFER_SIZE_EVENT: WORD = 0x0004;
const FOCUS_EVENT: WORD = 0x0010;

// Virtual key codes
const VK_RETURN: WORD = 0x0D;
const VK_ESCAPE: WORD = 0x1B;
const VK_BACK: WORD = 0x08;
const VK_TAB: WORD = 0x09;
const VK_LEFT: WORD = 0x25;
const VK_UP: WORD = 0x26;
const VK_RIGHT: WORD = 0x27;
const VK_DOWN: WORD = 0x28;
const VK_DELETE: WORD = 0x2E;
const VK_HOME: WORD = 0x24;
const VK_END: WORD = 0x23;
const VK_PRIOR: WORD = 0x21; // Page Up
const VK_NEXT: WORD = 0x22; // Page Down
const VK_INSERT: WORD = 0x2D;
const VK_F1: WORD = 0x70;

// Control key state
const LEFT_CTRL_PRESSED: DWORD = 0x0008;
const RIGHT_CTRL_PRESSED: DWORD = 0x0004;
const LEFT_ALT_PRESSED: DWORD = 0x0002;
const RIGHT_ALT_PRESSED: DWORD = 0x0001;
const SHIFT_PRESSED: DWORD = 0x0010;

// Wait result
const WAIT_OBJECT_0: DWORD = 0x00000000;
const WAIT_TIMEOUT: DWORD = 0x00000102;

pub const WindowsBackend = struct {
    allocator: Allocator,
    stdin_handle: HANDLE,
    stdout_handle: HANDLE,
    original_stdin_mode: DWORD = 0,
    original_stdout_mode: DWORD = 0,
    in_raw_mode: bool = false,
    in_alternate_screen: bool = false,
    write_buffer: std.ArrayListUnmanaged(u8) = .empty,
    original_console_info: CONSOLE_SCREEN_BUFFER_INFO = undefined,

    pub fn init(allocator: Allocator) !WindowsBackend {
        if (!is_windows) {
            return error.UnsupportedTerminal; // Use ansi.zig backend instead
        }

        // Get standard handles using GetStdHandle
        const stdin_handle = windows.GetStdHandle(STD_INPUT_HANDLE) catch return error.IOError;
        const stdout_handle = windows.GetStdHandle(STD_OUTPUT_HANDLE) catch return error.IOError;

        // Get original console modes
        var original_stdin_mode: DWORD = 0;
        var original_stdout_mode: DWORD = 0;
        _ = kernel32.GetConsoleMode(stdin_handle, &original_stdin_mode);
        _ = kernel32.GetConsoleMode(stdout_handle, &original_stdout_mode);

        // Get original console info
        var original_console_info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
        _ = kernel32.GetConsoleScreenBufferInfo(stdout_handle, &original_console_info);

        return WindowsBackend{
            .allocator = allocator,
            .stdin_handle = stdin_handle,
            .stdout_handle = stdout_handle,
            .original_stdin_mode = original_stdin_mode,
            .original_stdout_mode = original_stdout_mode,
            .original_console_info = original_console_info,
        };
    }

    pub fn deinit(self: *WindowsBackend) void {
        if (self.in_alternate_screen) {
            disableAlternateScreen(self) catch {};
        }
        if (self.in_raw_mode) {
            exitRawMode(self) catch {};
        }

        // Restore original console settings
        _ = kernel32.SetConsoleTextAttribute(self.stdout_handle, self.original_console_info.wAttributes);
        _ = kernel32.SetConsoleCursorPosition(self.stdout_handle, self.original_console_info.dwCursorPosition);

        self.write_buffer.deinit(self.allocator);
    }

    pub fn interface(self: *WindowsBackend) Backend {
        return Backend{
            .ptr = self,
            .vtable = &.{
                .enter_raw_mode = enterRawMode,
                .exit_raw_mode = exitRawMode,
                .enable_alternate_screen = enableAlternateScreen,
                .disable_alternate_screen = disableAlternateScreen,
                .clear_screen = clearScreen,
                .write = write,
                .flush = flush,
                .get_size = getSize,
                .poll_event = pollEvent,
                .hide_cursor = hideCursor,
                .show_cursor = showCursor,
                .set_cursor = setCursor,
            },
        };
    }

    fn enterRawMode(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (self.in_raw_mode) return;

        if (!is_windows) return;

        // Disable line input, echo input, processed input for stdin
        var stdin_mode: DWORD = self.original_stdin_mode;
        stdin_mode &= ~ENABLE_LINE_INPUT;
        stdin_mode &= ~ENABLE_ECHO_INPUT;
        stdin_mode &= ~ENABLE_PROCESSED_INPUT;
        stdin_mode |= ENABLE_WINDOW_INPUT;
        stdin_mode |= ENABLE_VIRTUAL_TERMINAL_INPUT;
        _ = kernel32.SetConsoleMode(self.stdin_handle, stdin_mode);

        // Enable virtual terminal processing for stdout (ANSI escape sequences)
        var stdout_mode: DWORD = self.original_stdout_mode;
        stdout_mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        _ = kernel32.SetConsoleMode(self.stdout_handle, stdout_mode);

        self.in_raw_mode = true;
    }

    fn exitRawMode(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (!self.in_raw_mode) return;

        if (!is_windows) return;

        // Restore original modes
        _ = kernel32.SetConsoleMode(self.stdin_handle, self.original_stdin_mode);
        _ = kernel32.SetConsoleMode(self.stdout_handle, self.original_stdout_mode);
        self.in_raw_mode = false;
    }

    fn enableAlternateScreen(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (self.in_alternate_screen) return;

        if (!is_windows) return;

        // Use ANSI escape sequence for alternate screen buffer (works with VT mode enabled)
        try writeDirectToConsole(self, "\x1b[?1049h");
        try clearScreen(ptr);
        self.in_alternate_screen = true;
    }

    fn disableAlternateScreen(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        if (!self.in_alternate_screen) return;

        if (!is_windows) return;

        // Use ANSI escape sequence to restore main screen buffer
        try writeDirectToConsole(self, "\x1b[?1049l");
        self.in_alternate_screen = false;
    }

    fn clearScreen(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (kernel32.GetConsoleScreenBufferInfo(self.stdout_handle, &info) == 0) {
            return Error.IOError;
        }

        const coord: COORD = .{ .X = 0, .Y = 0 };
        const attrs = info.wAttributes;
        const buffer_size = @as(DWORD, @intCast(info.dwSize.X)) * @as(DWORD, @intCast(info.dwSize.Y));

        var written: DWORD = undefined;
        // Use wide character version
        if (kernel32.FillConsoleOutputCharacterW(self.stdout_handle, ' ', buffer_size, coord, &written) == 0) {
            return Error.IOError;
        }
        if (kernel32.FillConsoleOutputAttribute(self.stdout_handle, attrs, buffer_size, coord, &written) == 0) {
            return Error.IOError;
        }
        if (kernel32.SetConsoleCursorPosition(self.stdout_handle, coord) == 0) {
            return Error.IOError;
        }
    }

    fn write(ptr: *anyopaque, data: []const u8) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));
        self.write_buffer.appendSlice(self.allocator, data) catch return Error.IOError;
    }

    fn flush(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        if (self.write_buffer.items.len > 0) {
            try writeDirectToConsole(self, self.write_buffer.items);
            self.write_buffer.clearRetainingCapacity();
        }
    }

    fn writeDirectToConsole(self: *WindowsBackend, data: []const u8) Error!void {
        if (!is_windows) return;

        var written: DWORD = undefined;
        const result = WriteConsoleA(
            self.stdout_handle,
            data.ptr,
            @intCast(data.len),
            &written,
            null,
        );

        if (result == 0) {
            return Error.IOError;
        }
    }

    fn getSize(ptr: *anyopaque) Error!render.Size {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) {
            return .{ .width = 80, .height = 24 };
        }

        var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (kernel32.GetConsoleScreenBufferInfo(self.stdout_handle, &info) == 0) {
            return .{ .width = 80, .height = 24 }; // Default fallback
        }

        // Use the window size, not buffer size
        const width: u16 = @intCast(info.srWindow.Right - info.srWindow.Left + 1);
        const height: u16 = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1);

        return .{
            .width = if (width > 0) width else 80,
            .height = if (height > 0) height else 24,
        };
    }

    fn pollEvent(ptr: *anyopaque, timeout_ms: u32) Error!events.Event {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) {
            return events.Event.none;
        }

        // Wait for input with timeout
        const wait_result = WaitForSingleObject(self.stdin_handle, timeout_ms);
        if (wait_result == WAIT_TIMEOUT) {
            return events.Event.none;
        }
        if (wait_result != WAIT_OBJECT_0) {
            return events.Event.none;
        }

        // Check if there are events available
        var num_events: DWORD = 0;
        if (GetNumberOfConsoleInputEvents(self.stdin_handle, &num_events) == 0) {
            return events.Event.none;
        }
        if (num_events == 0) {
            return events.Event.none;
        }

        // Read the input event
        var input_record: [1]INPUT_RECORD = undefined;
        var events_read: DWORD = 0;
        if (ReadConsoleInputW(self.stdin_handle, &input_record, 1, &events_read) == 0) {
            return events.Event.none;
        }
        if (events_read == 0) {
            return events.Event.none;
        }

        const record = input_record[0];

        switch (record.EventType) {
            KEY_EVENT => {
                const key_event = record.Event.KeyEvent;
                if (key_event.bKeyDown == 0) {
                    return events.Event.none; // Ignore key up events
                }

                const ctrl_pressed = (key_event.dwControlKeyState & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED)) != 0;
                const alt_pressed = (key_event.dwControlKeyState & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED)) != 0;
                const shift_pressed = (key_event.dwControlKeyState & SHIFT_PRESSED) != 0;

                const modifiers = events.KeyModifiers{
                    .ctrl = ctrl_pressed,
                    .alt = alt_pressed,
                    .shift = shift_pressed,
                };

                // Map virtual key codes to KeyCode
                const key_code: events.KeyCode = switch (key_event.wVirtualKeyCode) {
                    VK_RETURN => .enter,
                    VK_ESCAPE => .esc,
                    VK_BACK => .backspace,
                    VK_TAB => if (shift_pressed) .back_tab else .tab,
                    VK_LEFT => .left,
                    VK_RIGHT => .right,
                    VK_UP => .up,
                    VK_DOWN => .down,
                    VK_DELETE => .delete,
                    VK_HOME => .home,
                    VK_END => .end,
                    VK_PRIOR => .page_up,
                    VK_NEXT => .page_down,
                    VK_INSERT => .insert,
                    VK_F1...VK_F1 + 11 => |vk| .{ .f = @intCast(vk - VK_F1 + 1) },
                    else => blk: {
                        // Use the Unicode character if available
                        const unicode_char = key_event.uChar.UnicodeChar;
                        if (unicode_char > 0 and unicode_char < 0xD800) {
                            break :blk .{ .char = unicode_char };
                        }
                        return events.Event.none;
                    },
                };

                return events.Event{ .key = .{ .code = key_code, .modifiers = modifiers } };
            },
            WINDOW_BUFFER_SIZE_EVENT => {
                const size_event = record.Event.WindowBufferSizeEvent;
                return events.Event{ .resize = .{
                    .width = @intCast(size_event.dwSize.X),
                    .height = @intCast(size_event.dwSize.Y),
                } };
            },
            FOCUS_EVENT => {
                const focus_event = record.Event.FocusEvent;
                if (focus_event.bSetFocus != 0) {
                    return events.Event.focus_gained;
                } else {
                    return events.Event.focus_lost;
                }
            },
            else => return events.Event.none,
        }
    }

    fn hideCursor(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        var info: CONSOLE_CURSOR_INFO = undefined;
        if (GetConsoleCursorInfo(self.stdout_handle, &info) == 0) {
            return Error.IOError;
        }

        info.bVisible = 0; // false
        if (SetConsoleCursorInfo(self.stdout_handle, &info) == 0) {
            return Error.IOError;
        }
    }

    fn showCursor(ptr: *anyopaque) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        var info: CONSOLE_CURSOR_INFO = undefined;
        if (GetConsoleCursorInfo(self.stdout_handle, &info) == 0) {
            return Error.IOError;
        }

        info.bVisible = 1; // true
        if (SetConsoleCursorInfo(self.stdout_handle, &info) == 0) {
            return Error.IOError;
        }
    }

    fn setCursor(ptr: *anyopaque, x: u16, y: u16) Error!void {
        const self: *WindowsBackend = @ptrCast(@alignCast(ptr));

        if (!is_windows) return;

        const coord: COORD = .{ .X = @intCast(x), .Y = @intCast(y) };
        if (kernel32.SetConsoleCursorPosition(self.stdout_handle, coord) == 0) {
            return Error.IOError;
        }
    }
};
