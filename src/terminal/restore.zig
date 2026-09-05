const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

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

var armed = std.atomic.Value(bool).init(false);
var handlers_installed = std.atomic.Value(bool).init(false);
var saved_termios: if (is_posix) posix.termios else void = undefined;
var tty_fd: if (is_posix) posix.fd_t else void = undefined;
var write_fd: if (is_posix) posix.fd_t else void = undefined;

/// Record what `restore` should put back. Called once raw mode is in effect.
/// `tty` is the descriptor the terminal attributes were read from; `out` is the
/// one the escape sequences go to.
pub fn arm(
    tty: if (is_posix) posix.fd_t else void,
    out: if (is_posix) posix.fd_t else void,
    original: if (is_posix) posix.termios else void,
) void {
    if (!is_posix) return;
    tty_fd = tty;
    write_fd = out;
    saved_termios = original;
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
    if (!is_posix) return;
    if (!armed.swap(false, .acq_rel)) return;

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
