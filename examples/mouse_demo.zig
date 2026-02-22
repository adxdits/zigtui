const std = @import("std");
const tui = @import("zigtui");

const Terminal = tui.terminal.Terminal;
const Buffer = tui.render.Buffer;
const Rect = tui.render.Rect;

const State = struct {
    last_kind: []const u8 = "—",
    last_button: []const u8 = "—",
    x: u16 = 0,
    y: u16 = 0,
    clicks: u32 = 0,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var backend = try tui.backend.init(allocator);
    defer backend.deinit();

    var terminal = try Terminal.init(allocator, backend.interface());
    defer terminal.deinit();

    try terminal.hideCursor();
    defer terminal.showCursor() catch {};

    try terminal.enableMouse();
    defer terminal.disableMouse() catch {};

    var state = State{};
    var running = true;

    while (running) {
        const event = try backend.interface().pollEvent(100);
        switch (event) {
            .key => |key| {
                if (key.code == .esc or (key.code == .char and key.code.char == 'q'))
                    running = false;
            },
            .mouse => |mouse| {
                state.x = mouse.x;
                state.y = mouse.y;
                state.last_kind = switch (mouse.kind) {
                    .down => "down",
                    .up => "up",
                    .moved => "moved",
                    .drag => "drag",
                    .scroll_up => "scroll up",
                    .scroll_down => "scroll down",
                };
                state.last_button = switch (mouse.button) {
                    .left => "left",
                    .right => "right",
                    .middle => "middle",
                };
                if (mouse.kind == .down) state.clicks += 1;
            },
            else => {},
        }

        try terminal.draw(&state, struct {
            fn render(s: *State, buf: *Buffer) !void {
                const area = buf.getArea();

                const block = tui.widgets.Block{
                    .title = "Mouse demo press 'q' to quit",
                    .borders = tui.widgets.Borders.all(),
                    .border_style = .{ .fg = .cyan },
                };
                block.render(area, buf);

                const inner = Rect{
                    .x = area.x + 2,
                    .y = area.y + 2,
                    .width = if (area.width > 4) area.width - 4 else 0,
                    .height = if (area.height > 4) area.height - 4 else 0,
                };

                if (inner.width == 0 or inner.height == 0) return;

                var line_buf: [128]u8 = undefined;

                // Line 1: position
                const pos_line = std.fmt.bufPrint(&line_buf, "Position: ({d}, {d})", .{ s.x, s.y }) catch return;
                buf.setString(inner.x, inner.y, pos_line, .{});

                // Line 2: event
                var evt_buf: [128]u8 = undefined;
                const evt_line = std.fmt.bufPrint(&evt_buf, "Event:    {s} ({s})", .{ s.last_kind, s.last_button }) catch return;
                buf.setString(inner.x, inner.y + 1, evt_line, .{});

                // Line 3: click count
                var cnt_buf: [64]u8 = undefined;
                const cnt_line = std.fmt.bufPrint(&cnt_buf, "Clicks:   {d}", .{s.clicks}) catch return;
                buf.setString(inner.x, inner.y + 2, cnt_line, .{});
            }
        }.render);
    }
}
