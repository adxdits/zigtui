const std = @import("std");
const events = @import("../events/mod.zig");
const render = @import("../render/mod.zig");

pub const Error = error{
    IOError,
    UnsupportedTerminal,
    TerminalTooSmall,
    NotInRawMode,
    NotATerminal,
    Unexpected,
    // OS-level write errors (surfaced through std)
    ProcessOrphaned,
    AccessDenied,
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    DeviceBusy,
    InvalidArgument,
    BrokenPipe,
    SystemResources,
    OperationAborted,
    NotOpenForWriting,
    LockViolation,
    WouldBlock,
    ConnectionResetByPeer,
} || std.mem.Allocator.Error;

pub const KeyboardProtocolMode = enum {
    legacy,
    kitty,
};

pub const KeyboardProtocolOptions = struct {
    mode: KeyboardProtocolMode = .legacy,
    flags: u32 = 0,
    use_push_pop: bool = true,
    detect_support: bool = false,
    timeout_ms: u32 = 50,
};

pub const Backend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        enter_raw_mode: *const fn (ptr: *anyopaque) Error!void,
        exit_raw_mode: *const fn (ptr: *anyopaque) Error!void,
        enable_alternate_screen: *const fn (ptr: *anyopaque) Error!void,
        disable_alternate_screen: *const fn (ptr: *anyopaque) Error!void,
        clear_screen: *const fn (ptr: *anyopaque) Error!void,
        write: *const fn (ptr: *anyopaque, data: []const u8) Error!void,
        flush: *const fn (ptr: *anyopaque) Error!void,
        get_size: *const fn (ptr: *anyopaque) Error!render.Size,
        poll_event: *const fn (ptr: *anyopaque, timeout_ms: u32) Error!events.Event,
        hide_cursor: *const fn (ptr: *anyopaque) Error!void,
        show_cursor: *const fn (ptr: *anyopaque) Error!void,
        set_cursor: *const fn (ptr: *anyopaque, x: u16, y: u16) Error!void,
        enable_keyboard_protocol: *const fn (ptr: *anyopaque, options: KeyboardProtocolOptions) Error!void,
        disable_keyboard_protocol: *const fn (ptr: *anyopaque) Error!void,
        enable_mouse: *const fn (ptr: *anyopaque) Error!void,
        disable_mouse: *const fn (ptr: *anyopaque) Error!void,
    };

    pub fn enterRawMode(self: Backend) Error!void {
        return self.vtable.enter_raw_mode(self.ptr);
    }

    pub fn exitRawMode(self: Backend) Error!void {
        return self.vtable.exit_raw_mode(self.ptr);
    }

    pub fn enableAlternateScreen(self: Backend) Error!void {
        return self.vtable.enable_alternate_screen(self.ptr);
    }

    pub fn disableAlternateScreen(self: Backend) Error!void {
        return self.vtable.disable_alternate_screen(self.ptr);
    }

    pub fn clearScreen(self: Backend) Error!void {
        return self.vtable.clear_screen(self.ptr);
    }

    pub fn write(self: Backend, data: []const u8) Error!void {
        return self.vtable.write(self.ptr, data);
    }

    pub fn flush(self: Backend) Error!void {
        return self.vtable.flush(self.ptr);
    }

    pub fn getSize(self: Backend) Error!render.Size {
        return self.vtable.get_size(self.ptr);
    }

    pub fn pollEvent(self: Backend, timeout_ms: u32) Error!events.Event {
        return self.vtable.poll_event(self.ptr, timeout_ms);
    }

    pub fn hideCursor(self: Backend) Error!void {
        return self.vtable.hide_cursor(self.ptr);
    }

    pub fn showCursor(self: Backend) Error!void {
        return self.vtable.show_cursor(self.ptr);
    }

    pub fn setCursor(self: Backend, x: u16, y: u16) Error!void {
        return self.vtable.set_cursor(self.ptr, x, y);
    }

    pub fn enableKeyboardProtocol(self: Backend, options: KeyboardProtocolOptions) Error!void {
        return self.vtable.enable_keyboard_protocol(self.ptr, options);
    }

    pub fn disableKeyboardProtocol(self: Backend) Error!void {
        return self.vtable.disable_keyboard_protocol(self.ptr);
    }

    pub fn enableMouse(self: Backend) Error!void {
        return self.vtable.enable_mouse(self.ptr);
    }

    pub fn disableMouse(self: Backend) Error!void {
        return self.vtable.disable_mouse(self.ptr);
    }
};

// Platform-specific backends
pub const AnsiBackend = @import("ansi.zig").AnsiBackend;
pub const WindowsBackend = @import("windows.zig").WindowsBackend;

pub const NativeBackend = if (@import("builtin").os.tag == .windows) WindowsBackend else AnsiBackend;

pub fn init(allocator: std.mem.Allocator) !NativeBackend {
    return NativeBackend.init(allocator);
}
