const std = @import("std");
const builtin = @import("builtin");
const Backend = @import("mod.zig").Backend;
const KeyboardProtocolOptions = @import("mod.zig").KeyboardProtocolOptions;
const Error = @import("mod.zig").Error;
const events = @import("../events/mod.zig");
const render = @import("../render/mod.zig");
const ansi_input = @import("ansi_input.zig");
const restore = @import("../terminal/restore.zig");
const Allocator = std.mem.Allocator;

const is_windows = builtin.target.os.tag == .windows;
const is_linux = builtin.target.os.tag == .linux;
const is_macos = builtin.target.os.tag == .macos;
const is_posix = !is_windows;

// POSIX types - only available on non-Windows
const posix = if (is_posix) std.posix else void;
const termios = if (is_posix) std.posix.termios else void;
// SIGWINCH - for resize events
// Global atomic flag must be global because POSIX signal handlers
// cannot capture instance state
var global_resize_flag = std.atomic.Value(bool).init(false);

fn handleSigwinch(_: posix.SIG) callconv(.c) void {
    global_resize_flag.store(true, .release);
}

pub const AnsiBackend = struct {
    pub const max_paste_bytes = 1024 * 1024;
    const paste_end = "\x1b[201~";

    allocator: Allocator,
    io: std.Io,
    stdin: std.Io.File,
    stdout: std.Io.File,
    original_termios: if (is_posix) std.posix.termios else void,
    in_raw_mode: bool = false,
    in_alternate_screen: bool = false,
    write_buffer: std.ArrayListUnmanaged(u8) = .empty,
    input_buffer: std.ArrayListUnmanaged(u8) = .empty,
    /// How long a lone ESC waits for the rest of an escape sequence before it
    /// counts as the Esc key. Raise it over slow links that split sequences.
    escape_timeout_ms: u32 = 50,
    /// When the incomplete bytes in `input_buffer` stop waiting for more.
    escape_deadline: ?std.Io.Timestamp = null,
    keyboard_flags: u32 = 0,
    keyboard_push_pop: bool = false,
    keyboard_enabled: bool = false,
    mouse_enabled: bool = false,
    bracketed_paste_enabled: bool = false,
    paste_active: bool = false,
    paste_discarding: bool = false,
    paste_buffer: std.ArrayListUnmanaged(u8) = .empty,
    // SIGWINCH handler state
    original_sigaction: if (is_posix) posix.Sigaction else void = if (is_posix) std.mem.zeroes(posix.Sigaction) else {},
    sigwinch_installed: bool = false,

    pub fn init(allocator: Allocator, io: std.Io) !AnsiBackend {
        if (is_windows) {
            return error.UnsupportedTerminal; // Use windows.zig backend instead
        }

        const stdin = std.Io.File.stdin();
        const stdout = std.Io.File.stdout();

        // Save original terminal settings
        const original = if (is_posix) try posix.tcgetattr(stdin.handle) else {};

        return AnsiBackend{
            .allocator = allocator,
            .io = io,
            .stdin = stdin,
            .stdout = stdout,
            .original_termios = original,
        };
    }

    pub fn deinit(self: *AnsiBackend) void {
        disableBracketedPaste(self) catch {};
        if (self.mouse_enabled) {
            self.stdout.writeStreamingAll(self.io, "\x1b[?1006l\x1b[?1003l\x1b[?1000l") catch {};
            self.mouse_enabled = false;
        }
        if (self.keyboard_enabled) {
            self.stdout.writeStreamingAll(self.io, "\x1b[<u") catch {};
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
        self.paste_buffer.deinit(self.allocator);
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
                .enable_mouse = enableMouse,
                .disable_mouse = disableMouse,
                .enable_bracketed_paste = enableBracketedPaste,
                .disable_bracketed_paste = disableBracketedPaste,
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
            raw.cc[@backingInt(posix.V.TIME)] = 0;
            raw.cc[@backingInt(posix.V.MIN)] = 0;

            posix.tcsetattr(self.stdin.handle, .FLUSH, raw) catch return Error.IOError;

            restore.arm(self.stdin.handle, self.stdout.handle, self.original_termios);
            restore.installSignalHandlers();

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
        try disableBracketedPaste(self);

        if (is_posix) {
            restore.disarm();
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

        self.stdout.writeStreamingAll(self.io, "\x1b[?1049h") catch return Error.IOError; // Enable alternate screen
        self.stdout.writeStreamingAll(self.io, "\x1b[2J") catch return Error.IOError; // Clear screen
        self.stdout.writeStreamingAll(self.io, "\x1b[H") catch return Error.IOError; // Move cursor to home
        self.in_alternate_screen = true;
    }

    fn disableAlternateScreen(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (!self.in_alternate_screen) return;

        self.stdout.writeStreamingAll(self.io, "\x1b[?1049l") catch return Error.IOError; // Disable alternate screen
        self.in_alternate_screen = false;
    }

    fn clearScreen(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        self.stdout.writeStreamingAll(self.io, "\x1b[2J\x1b[H") catch return Error.IOError;
    }

    fn write(ptr: *anyopaque, data: []const u8) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        self.write_buffer.appendSlice(self.allocator, data) catch return Error.IOError;
    }

    fn flush(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (self.write_buffer.items.len > 0) {
            self.stdout.writeStreamingAll(self.io, self.write_buffer.items) catch return Error.IOError;
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
            if (try self.parseBufferedEvent(false)) |event| {
                return event;
            }

            const clock: std.Io.Clock = .awake;
            const deadline = clock.now(self.io).addDuration(.fromMilliseconds(timeout_ms));

            while (true) {
                var wait_ms = self.millisecondsUntil(deadline);

                // Bytes still in the buffer are an escape sequence whose rest is
                // on its way, or an Esc key press. Running out the escape
                // timeout with nothing more read settles it as the key press.
                var waiting_on_escape = false;
                if (self.escape_deadline) |escape_deadline| {
                    const escape_wait_ms = self.millisecondsUntil(escape_deadline);
                    if (escape_wait_ms == 0) return (try self.parseBufferedEvent(true)) orelse events.Event.none;
                    if (escape_wait_ms <= wait_ms) {
                        wait_ms = escape_wait_ms;
                        waiting_on_escape = true;
                    }
                }

                // Use poll() for timeout support
                var fds = [_]posix.pollfd{
                    .{
                        .fd = self.stdin.handle,
                        .events = posix.POLL.IN,
                        .revents = 0,
                    },
                };

                const poll_result = posix.poll(&fds, @intCast(wait_ms)) catch |err| {
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

                if (poll_result == 0) {
                    if (waiting_on_escape) return (try self.parseBufferedEvent(true)) orelse events.Event.none;
                    return events.Event.none;
                }

                if (fds[0].revents & posix.POLL.IN == 0) {
                    return events.Event.none;
                }

                // Read available bytes
                var buf: [64]u8 = undefined;
                var vecs: [1][]u8 = .{&buf};
                const n = self.stdin.readStreaming(self.io, &vecs) catch |err| switch (err) {
                    error.WouldBlock, error.EndOfStream => return events.Event.none,
                    else => return Error.IOError,
                };

                if (n == 0) return events.Event.none;

                try self.input_buffer.appendSlice(self.allocator, buf[0..n]);
                if (self.input_buffer.items.len > 4096) {
                    self.consumeInput(self.input_buffer.items.len);
                    return events.Event.none;
                }

                // New bytes restart the wait for whatever is still incomplete.
                self.escape_deadline = null;
                if (try self.parseBufferedEvent(false)) |event| {
                    return event;
                }
                if (self.millisecondsUntil(deadline) == 0) return events.Event.none;
            }
        }

        // Fallback for non-POSIX systems (should not reach here)
        return events.Event.none;
    }

    fn hideCursor(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        self.stdout.writeStreamingAll(self.io, "\x1b[?25l") catch return Error.IOError;
    }

    fn showCursor(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        self.stdout.writeStreamingAll(self.io, "\x1b[?25h") catch return Error.IOError;
    }

    fn setCursor(ptr: *anyopaque, x: u16, y: u16) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        var buffer: [32]u8 = undefined;
        const cmd = std.fmt.bufPrint(&buffer, "\x1b[{d};{d}H", .{ y + 1, x + 1 }) catch return Error.IOError;
        self.stdout.writeStreamingAll(self.io, cmd) catch return Error.IOError;
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
            self.stdout.writeStreamingAll(self.io, self.write_buffer.items) catch return Error.IOError;
            self.write_buffer.clearRetainingCapacity();
        }

        const flags_to_set: u32 = if (options.flags == 0) 1 else options.flags;

        if (options.use_push_pop) {
            var buf: [32]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[>{d}u", .{flags_to_set}) catch return Error.IOError;
            self.stdout.writeStreamingAll(self.io, seq) catch return Error.IOError;
        } else {
            var buf: [48]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[={d};1u", .{flags_to_set}) catch return Error.IOError;
            self.stdout.writeStreamingAll(self.io, seq) catch return Error.IOError;
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
            self.stdout.writeStreamingAll(self.io, self.write_buffer.items) catch return Error.IOError;
            self.write_buffer.clearRetainingCapacity();
        }

        if (self.keyboard_push_pop) {
            self.stdout.writeStreamingAll(self.io, "\x1b[<u") catch return Error.IOError;
        } else if (self.keyboard_flags != 0) {
            var buf: [48]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[={d};3u", .{self.keyboard_flags}) catch return Error.IOError;
            self.stdout.writeStreamingAll(self.io, seq) catch return Error.IOError;
        }

        self.keyboard_enabled = false;
    }

    fn enableMouse(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (self.mouse_enabled) return;
        // Enable X10 mouse reporting + SGR extended coordinates + any-event tracking
        self.stdout.writeStreamingAll(self.io, "\x1b[?1000h\x1b[?1003h\x1b[?1006h") catch return Error.IOError;
        self.mouse_enabled = true;
    }

    fn disableMouse(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (!self.mouse_enabled) return;
        self.stdout.writeStreamingAll(self.io, "\x1b[?1006l\x1b[?1003l\x1b[?1000l") catch return Error.IOError;
        self.mouse_enabled = false;
    }

    fn enableBracketedPaste(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (self.bracketed_paste_enabled) return;
        if (!self.in_raw_mode) return Error.NotInRawMode;
        try flush(ptr);
        self.stdout.writeStreamingAll(self.io, "\x1b[?2004h") catch return Error.IOError;
        self.bracketed_paste_enabled = true;
    }

    fn disableBracketedPaste(ptr: *anyopaque) Error!void {
        const self: *AnsiBackend = @ptrCast(@alignCast(ptr));
        if (!self.bracketed_paste_enabled) return;
        try flush(ptr);
        self.stdout.writeStreamingAll(self.io, "\x1b[?2004l") catch return Error.IOError;
        self.bracketed_paste_enabled = false;
        if (self.paste_active) {
            self.paste_discarding = true;
            self.paste_buffer.clearRetainingCapacity();
        }
    }

    fn detectKittyKeyboard(self: *AnsiBackend, timeout_ms: u32) Error!bool {
        if (!is_posix) return false;

        self.stdout.writeStreamingAll(self.io, "\x1b[?u") catch return Error.IOError;
        self.stdout.writeStreamingAll(self.io, "\x1b[c") catch return Error.IOError;

        var buffer: std.ArrayListUnmanaged(u8) = .empty;
        defer buffer.deinit(self.allocator);

        // Monotonic deadline; `awake` is unaffected by wall-clock jumps.
        const clock: std.Io.Clock = .awake;
        const deadline = clock.now(self.io).addDuration(.fromMilliseconds(timeout_ms));
        var supported = false;

        while (true) {
            const remaining_ms = self.millisecondsUntil(deadline);
            if (remaining_ms == 0) break;

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
            var vecs: [1][]u8 = .{&temp};
            const n = self.stdin.readStreaming(self.io, &vecs) catch |err| switch (err) {
                error.WouldBlock, error.EndOfStream => break,
                else => return Error.IOError,
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

    /// Milliseconds left until `deadline`, rounded up so a sub-millisecond
    /// remainder does not busy-spin poll(). Zero once it has passed.
    fn millisecondsUntil(self: *AnsiBackend, deadline: std.Io.Timestamp) u32 {
        const clock: std.Io.Clock = .awake;
        const remaining_ns = clock.now(self.io).durationTo(deadline).nanoseconds;
        if (remaining_ns <= 0) return 0;
        return @intCast(@min(
            @divTrunc(remaining_ns + std.time.ns_per_ms - 1, std.time.ns_per_ms),
            std.math.maxInt(i32),
        ));
    }

    /// Parse the next event out of `input_buffer`. With `stale` set, bytes that
    /// would otherwise wait for more input are settled as they stand.
    fn parseBufferedEvent(self: *AnsiBackend, stale: bool) Error!?events.Event {
        while (self.input_buffer.items.len > 0) {
            const input = self.input_buffer.items;
            if (self.paste_active) {
                const end = std.mem.indexOf(u8, input, paste_end);
                var payload_len = end orelse input.len;
                if (end == null) {
                    // Keep a possible delimiter prefix for the next read.
                    var suffix_len = @min(input.len, paste_end.len - 1);
                    while (suffix_len > 0) : (suffix_len -= 1) {
                        if (std.mem.endsWith(u8, input, paste_end[0..suffix_len])) break;
                    }
                    payload_len -= suffix_len;
                }

                var failure: ?Error = null;
                if (!self.paste_discarding) {
                    if (payload_len > max_paste_bytes - self.paste_buffer.items.len) {
                        failure = Error.PasteTooLarge;
                    } else {
                        self.paste_buffer.appendSlice(self.allocator, input[0..payload_len]) catch |err| {
                            failure = err;
                        };
                    }
                    if (failure != null) {
                        self.paste_discarding = true;
                        self.paste_buffer.clearRetainingCapacity();
                    }
                }

                self.consumeInput(if (end != null) payload_len + paste_end.len else payload_len);
                if (end != null) {
                    self.paste_active = false;
                    const discarded = self.paste_discarding;
                    self.paste_discarding = false;
                    if (failure) |err| return err;
                    if (!discarded) return .{ .paste = self.paste_buffer.items };
                    continue;
                }
                if (failure) |err| return err;
                return null;
            }

            const result = if (stale) ansi_input.parseStale(input) else ansi_input.parse(input);
            switch (result) {
                .paste_start => |consumed| {
                    self.consumeInput(consumed);
                    if (self.bracketed_paste_enabled) {
                        self.paste_buffer.clearRetainingCapacity();
                        self.paste_active = true;
                    }
                },
                .complete => |complete| {
                    self.consumeInput(complete.consumed);
                    if (complete.event == .none) continue;
                    return complete.event;
                },
                .incomplete => {
                    if (self.escape_deadline == null) {
                        const clock: std.Io.Clock = .awake;
                        self.escape_deadline = clock.now(self.io).addDuration(.fromMilliseconds(self.escape_timeout_ms));
                    }
                    return null;
                },
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
        // Whatever is left is a different prefix, so any wait starts over.
        self.escape_deadline = null;
        if (count >= self.input_buffer.items.len) {
            self.input_buffer.clearRetainingCapacity();
            return;
        }
        // replaceRange with empty slice is a shrink-only operation; cannot OOM.
        self.input_buffer.replaceRange(undefined, 0, count, &.{}) catch unreachable;
    }
};

test {
    _ = ansi_input;
}

test "AnsiBackend basic" {
    if (is_windows) return error.SkipZigTest;
    // Basic smoke test - actual functionality requires a real terminal
    const allocator = std.testing.allocator;
    _ = allocator;
    // Cannot fully test without a TTY
}

fn testInputBackend() AnsiBackend {
    return .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .stdin = .stdin(),
        .stdout = .stdout(),
        .original_termios = undefined,
        .bracketed_paste_enabled = true,
    };
}

fn deinitTestInput(backend: *AnsiBackend) void {
    backend.bracketed_paste_enabled = false;
    backend.in_raw_mode = false;
    backend.deinit();
}

test "bracketed paste keeps UTF-8 and control bytes literal before queued keys" {
    var backend = testInputBackend();
    defer deinitTestInput(&backend);
    const text = "hello\r\n\x03\x1b[A\xE4\xBD\xA0\xE5\xA5\xBD";
    try backend.input_buffer.appendSlice(backend.allocator, "\x1b[200~" ++ text ++ "\x1b[201~q");

    const event = (try backend.parseBufferedEvent(false)).?;
    try std.testing.expect(event == .paste);
    try std.testing.expectEqualStrings(text, event.paste);
    try std.testing.expectEqualStrings("q", backend.input_buffer.items);
    try std.testing.expect((try backend.parseBufferedEvent(false)).?.isChar('q'));
}

test "bracketed paste handles every split point and false delimiter prefixes" {
    const text = "a\x1b[20x\x1b[201\x1b[200~\xC3\xA9";
    const wire = "\x1b[200~" ++ text ++ "\x1b[201~";
    for (1..wire.len) |split| {
        var backend = testInputBackend();
        defer deinitTestInput(&backend);
        try backend.input_buffer.appendSlice(backend.allocator, wire[0..split]);
        try std.testing.expect(try backend.parseBufferedEvent(false) == null);
        try backend.input_buffer.appendSlice(backend.allocator, wire[split..]);
        const event = (try backend.parseBufferedEvent(false)).?;
        try std.testing.expect(event == .paste);
        try std.testing.expectEqualStrings(text, event.paste);
        try std.testing.expectEqual(@as(usize, 0), backend.input_buffer.items.len);
    }
}

test "bracketed paste survives bytewise reads and escape timeouts" {
    var backend = testInputBackend();
    defer deinitTestInput(&backend);
    const wire = "\x1b[200~\xF0\x9F\x98\x80\r\n\x1b[201~";
    for (wire, 0..) |byte, i| {
        try backend.input_buffer.append(backend.allocator, byte);
        const event = try backend.parseBufferedEvent(backend.paste_active);
        if (i + 1 < wire.len) {
            try std.testing.expect(event == null);
        } else {
            try std.testing.expectEqualStrings("\xF0\x9F\x98\x80\r\n", event.?.paste);
        }
        if (backend.paste_active) try std.testing.expect(backend.escape_deadline == null);
    }
}

test "bracketed paste supports empty and consecutive pastes" {
    var backend = testInputBackend();
    defer deinitTestInput(&backend);
    try backend.input_buffer.appendSlice(backend.allocator, "\x1b[200~\x1b[201~\x1b[200~next\x1b[201~");
    const first = (try backend.parseBufferedEvent(false)).?;
    try std.testing.expect(first == .paste);
    try std.testing.expectEqualStrings("", first.paste);
    const second = (try backend.parseBufferedEvent(false)).?;
    try std.testing.expectEqualStrings("next", second.paste);
}

test "bracketed paste remains opt-in" {
    var backend = testInputBackend();
    defer deinitTestInput(&backend);
    backend.bracketed_paste_enabled = false;
    try backend.input_buffer.appendSlice(backend.allocator, "\x1b[200~x\x1b[201~");
    try std.testing.expect((try backend.parseBufferedEvent(false)).?.isChar('x'));
    try std.testing.expect(try backend.parseBufferedEvent(false) == null);
}

test "bracketed paste accepts exactly 1 MiB and rejects one byte more" {
    for ([_]usize{ AnsiBackend.max_paste_bytes, AnsiBackend.max_paste_bytes + 1 }) |size| {
        var backend = testInputBackend();
        defer deinitTestInput(&backend);
        try backend.input_buffer.appendSlice(backend.allocator, "\x1b[200~");
        try backend.input_buffer.appendNTimes(backend.allocator, 'x', size);
        if (size > AnsiBackend.max_paste_bytes) {
            try std.testing.expectError(Error.PasteTooLarge, backend.parseBufferedEvent(false));
            try std.testing.expect(backend.paste_discarding);
            try std.testing.expectEqual(@as(usize, 0), backend.paste_buffer.items.len);
            try backend.input_buffer.appendSlice(backend.allocator, "\r\x03q\x1b[20");
            try std.testing.expect(try backend.parseBufferedEvent(true) == null);
            try backend.input_buffer.appendSlice(backend.allocator, "1~z");
        } else {
            try std.testing.expect(try backend.parseBufferedEvent(false) == null);
            try backend.input_buffer.appendSlice(backend.allocator, "\x1b[201~z");
            const event = (try backend.parseBufferedEvent(false)).?;
            try std.testing.expect(event == .paste);
            try std.testing.expectEqual(size, event.paste.len);
            try std.testing.expect(std.mem.allEqual(u8, event.paste, 'x'));
        }
        try std.testing.expect((try backend.parseBufferedEvent(false)).?.isChar('z'));
        try std.testing.expect(!backend.paste_active);
        try std.testing.expect(!backend.paste_discarding);
    }
}

test "bracketed paste reports allocation failure and discards through the end" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    var backend = testInputBackend();
    backend.allocator = failing.allocator();
    defer deinitTestInput(&backend);
    try backend.input_buffer.appendSlice(backend.allocator, "\x1b[200~text");
    try std.testing.expectError(error.OutOfMemory, backend.parseBufferedEvent(false));
    try std.testing.expect(backend.paste_discarding);
    try backend.input_buffer.appendSlice(backend.allocator, "\r\x03\x1b[201~q");
    try std.testing.expect((try backend.parseBufferedEvent(false)).?.isChar('q'));
    try std.testing.expect(!backend.paste_active);
}

test "bracketed paste mode is idempotent and disabling discards an active paste" {
    if (is_windows) return error.SkipZigTest;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const output = try tmp.dir.createFile(io, "output", .{ .read = true });
    defer output.close(io);
    var backend = testInputBackend();
    defer deinitTestInput(&backend);
    backend.stdout = output;
    backend.bracketed_paste_enabled = false;
    const interface = backend.interface();
    try std.testing.expectError(Error.NotInRawMode, interface.enableBracketedPaste());
    backend.in_raw_mode = true;
    try interface.write("pending");
    try interface.enableBracketedPaste();
    try interface.enableBracketedPaste();

    try backend.input_buffer.appendSlice(backend.allocator, "\x1b[200~text\x1b[20");
    try std.testing.expect(try backend.parseBufferedEvent(false) == null);
    try interface.disableBracketedPaste();
    try interface.disableBracketedPaste();
    try std.testing.expect(!backend.bracketed_paste_enabled);
    try std.testing.expect(backend.paste_discarding);
    try backend.input_buffer.appendSlice(backend.allocator, "1~q");
    try std.testing.expect((try backend.parseBufferedEvent(false)).?.isChar('q'));

    var bytes: [128]u8 = undefined;
    const n = try output.readPositionalAll(io, &bytes, 0);
    try std.testing.expectEqualStrings("pending\x1b[?2004h\x1b[?2004l", bytes[0..n]);
}

test "bracketed paste is disabled when the backend is deinitialized" {
    if (is_windows) return error.SkipZigTest;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const output = try tmp.dir.createFile(io, "output", .{ .read = true });
    defer output.close(io);
    var backend = testInputBackend();
    backend.stdout = output;
    backend.deinit();
    var bytes: [32]u8 = undefined;
    const n = try output.readPositionalAll(io, &bytes, 0);
    try std.testing.expectEqualStrings("\x1b[?2004l", bytes[0..n]);
}

test "bracketed paste pollEvent streams large pastes across nonblocking polls" {
    if (is_windows) return error.SkipZigTest;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const input = try tmp.dir.createFile(io, "input", .{ .read = true });
    defer input.close(io);
    const payload: [8192]u8 = @splat('x');
    try input.writePositionalAll(io, "\x1b[200~", 0);
    try input.writePositionalAll(io, &payload, 6);
    try input.writePositionalAll(io, "\x1b[201~q", 6 + payload.len);

    var backend = testInputBackend();
    defer deinitTestInput(&backend);
    backend.stdin = input;
    const interface = backend.interface();
    var received = false;
    for (0..256) |_| {
        const event = try interface.pollEvent(0);
        if (event == .none) continue;
        try std.testing.expect(event == .paste);
        try std.testing.expectEqualSlices(u8, &payload, event.paste);
        received = true;
        break;
    }
    try std.testing.expect(received);
    try std.testing.expect((try interface.pollEvent(0)).isChar('q'));
}
