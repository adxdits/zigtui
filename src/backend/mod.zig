//! Backend module - Terminal backend abstraction

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

/// Backend interface for terminal operations
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
    };

    /// Enter raw mode (disable line buffering, echo, etc.)
    pub fn enterRawMode(self: Backend) Error!void {
        return self.vtable.enter_raw_mode(self.ptr);
    }

    /// Exit raw mode
    pub fn exitRawMode(self: Backend) Error!void {
        return self.vtable.exit_raw_mode(self.ptr);
    }

    /// Enable alternate screen buffer
    pub fn enableAlternateScreen(self: Backend) Error!void {
        return self.vtable.enable_alternate_screen(self.ptr);
    }

    /// Disable alternate screen buffer
    pub fn disableAlternateScreen(self: Backend) Error!void {
        return self.vtable.disable_alternate_screen(self.ptr);
    }

    /// Clear the screen
    pub fn clearScreen(self: Backend) Error!void {
        return self.vtable.clear_screen(self.ptr);
    }

    /// Write data to terminal
    pub fn write(self: Backend, data: []const u8) Error!void {
        return self.vtable.write(self.ptr, data);
    }

    /// Flush buffered output
    pub fn flush(self: Backend) Error!void {
        return self.vtable.flush(self.ptr);
    }

    /// Get terminal size
    pub fn getSize(self: Backend) Error!render.Size {
        return self.vtable.get_size(self.ptr);
    }

    /// Poll for events (timeout in milliseconds, 0 = non-blocking)
    pub fn pollEvent(self: Backend, timeout_ms: u32) Error!events.Event {
        return self.vtable.poll_event(self.ptr, timeout_ms);
    }

    /// Hide cursor
    pub fn hideCursor(self: Backend) Error!void {
        return self.vtable.hide_cursor(self.ptr);
    }

    /// Show cursor
    pub fn showCursor(self: Backend) Error!void {
        return self.vtable.show_cursor(self.ptr);
    }

    /// Set cursor position
    pub fn setCursor(self: Backend, x: u16, y: u16) Error!void {
        return self.vtable.set_cursor(self.ptr, x, y);
    }
};

// Platform-specific backends
pub const AnsiBackend = @import("ansi.zig").AnsiBackend;
pub const WindowsBackend = @import("windows.zig").WindowsBackend;
