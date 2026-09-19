const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const windows = std.os.windows;

const is_posix = builtin.os.tag != .windows;

/// Written verbatim from signal handlers and from the panic path, so it has to
/// stay one preformatted constant: no allocation, no formatting, one syscall.
const leave_sequence =
    "\x1b[?2026l" ++
    "\x1b[?1006l\x1b[?1003l\x1b[?1002l\x1b[?1000l" ++
    "\x1b[<u" ++
    "\x1b[?7h" ++
    "\x1b[0m" ++
    "\x1b[?25h" ++
    "\x1b[?1049l";

const signals = if (is_posix) struct {
    const list = [_]posix.SIG{ .INT, .TERM, .HUP, .QUIT, .ABRT, .SEGV, .BUS, .ILL, .FPE };
    var previous: [list.len]posix.Sigaction = undefined;
} else struct {};

/// Console input/output modes saved on Windows so `restore` can put them back.
const WinMode = struct {
    stdin: windows.DWORD,
    stdout: windows.DWORD,
};

/// Windows state captured by `arm`, written back by `restore`.
const win = if (!is_posix) struct {
    extern "kernel32" fn SetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode: windows.DWORD) callconv(.winapi) windows.BOOL;
    extern "kernel32" fn WriteFile(
        hFile: windows.HANDLE,
        lpBuffer: [*]const u8,
        nNumberOfBytesToWrite: windows.DWORD,
        lpNumberOfBytesWritten: ?*windows.DWORD,
        lpOverlapped: ?*anyopaque,
    ) callconv(.winapi) windows.BOOL;

    var stdin_handle: windows.HANDLE = windows.INVALID_HANDLE_VALUE;
    var stdout_handle: windows.HANDLE = windows.INVALID_HANDLE_VALUE;
    var modes: WinMode = .{ .stdin = 0, .stdout = 0 };
} else struct {};

var armed = std.atomic.Value(bool).init(false);
var handlers_installed = std.atomic.Value(bool).init(false);
var saved_termios: if (is_posix) posix.termios else void = undefined;
var tty_fd: if (is_posix) posix.fd_t else void = undefined;
var write_fd: if (is_posix) posix.fd_t else void = undefined;

/// Record what `restore` should put back. Called once raw mode is in effect.
/// `tty` is the handle the terminal attributes were read from; `out` is the
/// one the escape sequences go to; `original` is the state to return to.
pub fn arm(
    tty: if (is_posix) posix.fd_t else windows.HANDLE,
    out: if (is_posix) posix.fd_t else windows.HANDLE,
    original: if (is_posix) posix.termios else WinMode,
) void {
    if (is_posix) {
        tty_fd = tty;
        write_fd = out;
        saved_termios = original;
    } else {
        win.stdin_handle = tty;
        win.stdout_handle = out;
        win.modes = original;
    }
    armed.store(true, .release);
}

pub fn disarm() void {
    armed.store(false, .release);
}

pub fn isArmed() bool {
    return armed.load(.acquire);
}

/// Put the terminal back into a usable state. Safe to call from a signal
/// handler, and a no-op unless `arm` ran and no earlier call already restored.
pub fn restore() void {
    if (!armed.swap(false, .acq_rel)) return;

    if (is_posix) {
        var written: usize = 0;
        while (written < leave_sequence.len) {
            const rc = posix.system.write(
                write_fd,
                leave_sequence[written..].ptr,
                leave_sequence.len - written,
            );
            const n = signedResult(rc);
            if (n <= 0) break;
            written += @intCast(n);
        }

        posix.tcsetattr(tty_fd, .FLUSH, saved_termios) catch {};
    } else {
        // Write the leave sequences (mouse reporting off, cursor shown, styles
        // reset, alternate screen left) while VT processing is still enabled,
        // then hand the console modes back.
        var written: windows.DWORD = 0;
        _ = win.WriteFile(win.stdout_handle, leave_sequence.ptr, leave_sequence.len, &written, null);
        _ = win.SetConsoleMode(win.stdin_handle, win.modes.stdin);
        _ = win.SetConsoleMode(win.stdout_handle, win.modes.stdout);
    }
}

/// Raw syscall wrappers return `isize` through libc and `usize` on bare Linux;
/// both encode errors as a negative value.
fn signedResult(rc: anytype) isize {
    const info = @typeInfo(@TypeOf(rc)).int;
    return if (info.signedness == .signed) @intCast(rc) else @bitCast(rc);
}

/// Hands control back to whatever handler was installed before, so a segfault
/// still reaches the runtime's own reporter with a usable terminal underneath.
fn onFatalSignal(sig: posix.SIG) callconv(.c) void {
    restore();

    for (signals.list, &signals.previous) |candidate, *prev| {
        if (candidate == sig) {
            posix.sigaction(sig, prev, null);
            break;
        }
    }
    posix.raise(sig) catch {};
}

/// Restore the terminal when the process is killed or faults, then let the
/// signal take its normal course. Without this a crash leaves the caller's
/// shell in raw mode on the alternate screen.
pub fn installSignalHandlers() void {
    if (!is_posix) return;
    if (handlers_installed.swap(true, .acq_rel)) return;

    const action = posix.Sigaction{
        .handler = .{ .handler = onFatalSignal },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    for (signals.list, &signals.previous) |sig, *prev| posix.sigaction(sig, &action, prev);
}

fn panicFn(msg: []const u8, first_trace_addr: ?usize) noreturn {
    restore();
    std.debug.defaultPanic(msg, first_trace_addr);
}

/// Panic handler that leaves the terminal usable before printing the trace.
/// Opt in from the root source file: `pub const panic = zigtui.panic;`
pub const Panic = std.debug.FullPanic(panicFn);

test "restore is inert until armed" {
    disarm();
    try std.testing.expect(!isArmed());
    restore();
    try std.testing.expect(!isArmed());
}

test "windows: arm and restore never touch the console with invalid handles" {
    if (!is_posix) {
        disarm();
        arm(windows.INVALID_HANDLE_VALUE, windows.INVALID_HANDLE_VALUE, .{ .stdin = 0, .stdout = 0 });
        try std.testing.expect(isArmed());
        restore();
        try std.testing.expect(!isArmed());
        // A second restore is a no-op.
        restore();
        try std.testing.expect(!isArmed());
    }
}
