//! ANSI escape sequence backend for Unix-like systems

const std = @import("std");
const builtin = @import("builtin");
const Backend = @import("mod.zig").Backend;
const KeyboardProtocolOptions = @import("mod.zig").KeyboardProtocolOptions;
const Error = @import("mod.zig").Error;
const events = @import("../events/mod.zig");
const render = @import("../render/mod.zig");
const ansi_input = @import("ansi_input.zig");
const Allocator = std.mem.Allocator;

const is_windows = builtin.os.tag == .windows;
const is_linux = builtin.os.tag == .linux;
const is_macos = builtin.os.tag == .macos;
const is_posix = !is_windows;

// POSIX types - only available on non-Windows
const posix = if (is_posix) std.posix else void;
const termios = if (is_posix) std.posix.termios else void;
// SIGWINCH - for resize events
// Global atomic flag must be global because POSIX signal handlers
// cannot capture instance state
var global_resize_flag = std.atomic.Value(bool).init(false);

fn handleSigwinch(_: c_int) callconv(.c) void {
    global_resize_flag.store(true, .release);
}

pub const AnsiBackend = struct {
    allocator: Allocator,
    stdin: std.fs.File,
    stdout: std.fs.File,
    original_termios: if (is_posix) std.posix.termios else void,
    in_raw_mode: bool = false,
    in_alternate_screen: bool = false,
    write_buffer: std.ArrayListUnmanaged(u8) = .empty,
    input_buffer: std.ArrayListUnmanaged(u8) = .empty,
    keyboard_flags: u32 = 0,
    keyboard_push_pop: bool = false,
    keyboard_enabled: bool = false,
    //swigwinch handler state
    // original_sigaction: if (is_posix) posix.Sigaction else void = undefined,
    original_sigaction: if (is_posix) posix.Sigaction else void = if (is_posix) std.mem.zeroes(posix.Sigaction) else {},
    sigwinch_installed: bool = false,

    pub fn init(allocator: Allocator) !AnsiBackend {
        if (is_windows) {
            return error.UnsupportedTerminal; // Use windows.zig backend instead
        }

        const stdin = std.fs.File{ .handle = std.posix.STDIN_FILENO };
        const stdout = std.fs.File{ .handle = std.posix.STDOUT_FILENO };

        // Save original terminal settings
        const original = if (is_posix) try posix.tcgetattr(stdin.handle) else {};

        return AnsiBackend{
            .allocator = allocator,
            .stdin = stdin,
            .stdout = stdout,
            .original_termios = original,
        };
    }

    pub fn deinit(self: *AnsiBackend) void {
        if (self.keyboard_enabled) {
            self.stdout.writeAll("\x1b[<u") catch {};
            self.keyboard_enabled = false;
        }
        if (self.in_alternate_screen) {
            disableAlternateScreen(self) catch {};
        }
        if (self.in_raw_mode) {
            exitRawMode(self) catch {};
        }
        self.write_buffer.deinit(self.allocator);
        self.input_buffer.deinit(self.allocator);
    }

    pub fn interface(self: *AnsiBackend) Backend {
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
                .enable_keyboard_protocol = enableKeyboardProtocol,
                .disable_keyboard_protocol = disableKeyboardProtocol,
            },
        };
    }

    fn enterRawMode(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (self.in_raw_mode) return;

        if (is_posix) {
            var raw = self.original_termios;

            // Disable canonical mode and echo
            raw.lflag.ECHO = false;
            raw.lflag.ICANON = false;
            raw.lflag.ISIG = false;
            raw.lflag.IEXTEN = false;

            // Disable input processing
            raw.iflag.IXON = false;
            raw.iflag.ICRNL = false;
            raw.iflag.BRKINT = false;
            raw.iflag.INPCK = false;
            raw.iflag.ISTRIP = false;

            // Disable output processing
            raw.oflag.OPOST = false;

            // Set character size to 8 bits
            raw.cflag.CSIZE = .CS8;

            // Set read timeout
            raw.cc[@intFromEnum(posix.V.TIME)] = 0;
            raw.cc[@intFromEnum(posix.V.MIN)] = 0;

            posix.tcsetattr(self.stdin.handle, .FLUSH, raw) catch return Error.IOError;
            //for term resize
            if (!self.sigwinch_installed) {
                const new_action = posix.Sigaction{
                    .handler = .{ .handler = handleSigwinch },
                    .mask = posix.sigemptyset(),
                    .flags = 0,
                };
                posix.sigaction(posix.SIG.WINCH, &new_action, &self.original_sigaction);
                self.sigwinch_installed = true;
            }
            self.in_raw_mode = true;
        }
    }

    fn exitRawMode(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (!self.in_raw_mode) return;

        if (is_posix) {
            posix.tcsetattr(self.stdin.handle, .FLUSH, self.original_termios) catch return Error.IOError;

            if (self.sigwinch_installed) {
                posix.sigaction(posix.SIG.WINCH, &self.original_sigaction, null);
                self.sigwinch_installed = false;
            }
        }
        self.in_raw_mode = false;
    }

    fn enableAlternateScreen(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (self.in_alternate_screen) return;

        self.stdout.writeAll("\x1b[?1049h") catch return Error.IOError; // Enable alternate screen
        self.stdout.writeAll("\x1b[2J") catch return Error.IOError; // Clear screen
        self.stdout.writeAll("\x1b[H") catch return Error.IOError; // Move cursor to home
        self.in_alternate_screen = true;
    }

    fn disableAlternateScreen(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (!self.in_alternate_screen) return;

        self.stdout.writeAll("\x1b[?1049l") catch return Error.IOError; // Disable alternate screen
        self.in_alternate_screen = false;
    }

    fn clearScreen(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        self.stdout.writeAll("\x1b[2J\x1b[H") catch return Error.IOError;
    }

    fn write(ptr: *anyopaque, data: []const u8) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        self.write_buffer.appendSlice(self.allocator, data) catch return Error.IOError;
    }

    fn flush(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (self.write_buffer.items.len > 0) {
            self.stdout.writeAll(self.write_buffer.items) catch return Error.IOError;
            self.write_buffer.clearRetainingCapacity();
        }
    }

    fn getSize(ptr: *anyopaque) Error!render.Size {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));

        if (is_windows) {
            // Windows: fallback to default size
            return .{ .width = 80, .height = 24 };
        }

        if (is_posix) {
            var size: posix.winsize = undefined;
            const result = posix.system.ioctl(self.stdout.handle, posix.T.IOCGWINSZ, @intFromPtr(&size));
            // On error, ioctl returns -errno as usize (very large value)
            // Check if result is 0 for success
            if (result != 0) {
                // Return default size if ioctl fails
                return .{ .width = 80, .height = 24 };
            }
            // Fallback if zero dimensions
            if (size.col == 0 or size.row == 0) {
                return .{ .width = 80, .height = 24 };
            }
            return .{
                .width = size.col,
                .height = size.row,
            };
        }

        return .{ .width = 80, .height = 24 };
    }

    fn pollEvent(ptr: *anyopaque, timeout_ms: u32) Error!events.Event {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));

        if (is_posix) {
            // check for resize event FIRST
            if (global_resize_flag.swap(false, .acquire)) {
                const size = getSize(@ptrCast(@alignCast(self))) catch {
                    return events.Event.none;
                };
                return events.Event{ .resize = .{ .width = size.width, .height = size.height } };
            }
            if (self.parseBufferedEvent()) |event| {
                return event;
            }

            // Use poll() for timeout support
            var fds = [_]posix.pollfd{
                .{
                    .fd = self.stdin.handle,
                    .events = posix.POLL.IN,
                    .revents = 0,
                },
            };

            const poll_result = posix.poll(&fds, @intCast(timeout_ms)) catch |err| {
                //sigwinch interupts poll()
                if (err == error.Interrupted) {
                    if (global_resize_flag.swap(false, .acquire)) {
                        const size = getSize(@ptrCast(@alignCast(self))) catch {
                            return events.Event.none;
                        };
                        return events.Event{ .resize = .{ .width = size.width, .height = size.height } };
                    }
                }
                return events.Event.none;
            };

            if (poll_result == 0) return events.Event.none;

            if (fds[0].revents & posix.POLL.IN == 0) {
                return events.Event.none;
            }

            // Read available bytes
            var buf: [64]u8 = undefined;
            const n = self.stdin.read(&buf) catch |err| {
                if (err == error.WouldBlock) return events.Event.none;
                return Error.IOError;
            };

            if (n == 0) return events.Event.none;

            try self.input_buffer.appendSlice(self.allocator, buf[0..n]);
            if (self.input_buffer.items.len > 4096) {
                self.input_buffer.clearRetainingCapacity();
                return events.Event.none;
            }

            if (self.parseBufferedEvent()) |event| {
                return event;
            }

            return events.Event.none;
        }

        // Fallback for non-POSIX systems (should not reach here)
        return events.Event.none;
    }

    fn hideCursor(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        self.stdout.writeAll("\x1b[?25l") catch return Error.IOError;
    }

    fn showCursor(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        self.stdout.writeAll("\x1b[?25h") catch return Error.IOError;
    }

    fn setCursor(ptr: *anyopaque, x: u16, y: u16) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        var buffer: [32]u8 = undefined;
        const cmd = std.fmt.bufPrint(&buffer, "\x1b[{d};{d}H", .{ y + 1, x + 1 }) catch return Error.IOError;
        self.stdout.writeAll(cmd) catch return Error.IOError;
    }

    fn enableKeyboardProtocol(ptr: *anyopaque, options: KeyboardProtocolOptions) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (options.mode == .legacy) return;

        if (options.detect_support) {
            const supported = try self.detectKittyKeyboard(options.timeout_ms);
            if (!supported) return Error.UnsupportedTerminal;
        }

        // Flush any pending render data so the protocol sequence is not
        // interleaved with buffered output.
        if (self.write_buffer.items.len > 0) {
            self.stdout.writeAll(self.write_buffer.items) catch return Error.IOError;
            self.write_buffer.clearRetainingCapacity();
        }

        const flags_to_set: u32 = if (options.flags == 0) 1 else options.flags;

        if (options.use_push_pop) {
            var buf: [32]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[>{d}u", .{flags_to_set}) catch return Error.IOError;
            self.stdout.writeAll(seq) catch return Error.IOError;
        } else {
            var buf: [48]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[={d};1u", .{flags_to_set}) catch return Error.IOError;
            self.stdout.writeAll(seq) catch return Error.IOError;
        }

        self.keyboard_flags = flags_to_set;
        self.keyboard_push_pop = options.use_push_pop;
        self.keyboard_enabled = true;
    }

    fn disableKeyboardProtocol(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (!self.keyboard_enabled) return;

        // Flush any pending render data before sending the protocol sequence.
        if (self.write_buffer.items.len > 0) {
            self.stdout.writeAll(self.write_buffer.items) catch return Error.IOError;
            self.write_buffer.clearRetainingCapacity();
        }

        if (self.keyboard_push_pop) {
            self.stdout.writeAll("\x1b[<u") catch return Error.IOError;
        } else if (self.keyboard_flags != 0) {
            var buf: [48]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[={d};3u", .{self.keyboard_flags}) catch return Error.IOError;
            self.stdout.writeAll(seq) catch return Error.IOError;
        }

        self.keyboard_enabled = false;
    }

    fn detectKittyKeyboard(self: *AnsiBackend, timeout_ms: u32) Error!bool {
        if (!is_posix) return false;

        self.stdout.writeAll("\x1b[?u") catch return Error.IOError;
        self.stdout.writeAll("\x1b[c") catch return Error.IOError;

        var buffer: std.ArrayListUnmanaged(u8) = .empty;
        defer buffer.deinit(self.allocator);

        const deadline = std.time.milliTimestamp() + @as(i64, timeout_ms);
        var supported = false;

        while (std.time.milliTimestamp() < deadline) {
            const now = std.time.milliTimestamp();
            const remaining_ms: u32 = if (deadline > now) @intCast(deadline - now) else 0;

            var fds = [_]posix.pollfd{
                .{
                    .fd = self.stdin.handle,
                    .events = posix.POLL.IN,
                    .revents = 0,
                },
            };

            const poll_result = posix.poll(&fds, @intCast(remaining_ms)) catch |err| {
                if (err == error.Interrupted) continue;
                return Error.IOError;
            };
            if (poll_result == 0) break;
            if (fds[0].revents & posix.POLL.IN == 0) break;

            var temp: [128]u8 = undefined;
            const n = self.stdin.read(&temp) catch |err| {
                if (err == error.WouldBlock) break;
                return Error.IOError;
            };
            if (n == 0) break;

            try buffer.appendSlice(self.allocator, temp[0..n]);
            supported = stripKittyResponses(&buffer) or supported;
        }

        if (buffer.items.len > 0) {
            try self.input_buffer.appendSlice(self.allocator, buffer.items);
        }

        return supported;
    }

    /// Strip `CSI ? ... u` (kitty keyboard query response) and `CSI ? ... c`
    /// (DA1 sentinel response) from the buffer. Returns true if a kitty
    /// keyboard response (`u` terminator) was found, indicating support.
    fn stripKittyResponses(buffer: *std.ArrayListUnmanaged(u8)) bool {
        var supported = false;
        var i: usize = 0;
        while (i + 2 < buffer.items.len) {
            if (buffer.items[i] == 0x1b and buffer.items[i + 1] == '[' and buffer.items[i + 2] == '?') {
                var j: usize = i + 3;
                while (j < buffer.items.len) : (j += 1) {
                    const b = buffer.items[j];
                    if (b == 'u' or b == 'c') {
                        if (b == 'u') supported = true;
                        dropRange(buffer, i, j + 1 - i);
                        // Restart scan -- indices shifted after removal.
                        i = 0;
                        break;
                    }
                    if (!((b >= '0' and b <= '9') or b == ';')) {
                        // Not a response we recognise; skip past the ESC byte.
                        i += 1;
                        break;
                    }
                }
                if (j >= buffer.items.len) break;
            } else {
                i += 1;
            }
        }
        return supported;
    }

    fn dropRange(buffer: *std.ArrayListUnmanaged(u8), start: usize, len: usize) void {
        if (len == 0 or start >= buffer.items.len) return;
        const clamped = @min(len, buffer.items.len - start);
        // replaceRange with empty slice is a shrink-only operation; cannot OOM.
        buffer.replaceRange(undefined, start, clamped, &.{}) catch unreachable;
    }

    fn parseBufferedEvent(self: *AnsiBackend) ?events.Event {
        while (self.input_buffer.items.len > 0) {
            switch (ansi_input.parse(self.input_buffer.items)) {
                .complete => |complete| {
                    self.consumeInput(complete.consumed);
                    if (complete.event == .none) continue;
                    return complete.event;
                },
                .incomplete => return null,
                .invalid => |consumed| {
                    const drop_count = if (consumed == 0) 1 else consumed;
                    self.consumeInput(@min(drop_count, self.input_buffer.items.len));
                },
            }
        }
        return null;
    }

    fn consumeInput(self: *AnsiBackend, count: usize) void {
        if (count == 0 or self.input_buffer.items.len == 0) return;
        if (count >= self.input_buffer.items.len) {
            self.input_buffer.clearRetainingCapacity();
            return;
        }
        // replaceRange with empty slice is a shrink-only operation; cannot OOM.
        self.input_buffer.replaceRange(undefined, 0, count, &.{}) catch unreachable;
    }
};

test "AnsiBackend basic" {
    if (is_windows) return error.SkipZigTest;
    // Basic smoke test - actual functionality requires a real terminal
    const allocator = std.testing.allocator;
    _ = allocator;
    // Cannot fully test without a TTY
}
