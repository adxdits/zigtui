//! ZigTUI Dashboard Demo
//! A beautiful terminal dashboard showcasing the library's capabilities
//! Controls: Tab to switch panels, Arrow keys to navigate, 'q' to quit

const std = @import("std");
const tui = @import("zigtui");

const Terminal = tui.terminal.Terminal;
const Buffer = tui.render.Buffer;
const Rect = tui.render.Rect;
const Color = tui.style.Color;
const Style = tui.style.Style;
const Modifier = tui.style.Modifier;
const Block = tui.widgets.Block;
const Borders = tui.widgets.Borders;
const BorderSymbols = tui.widgets.BorderSymbols;

const AppState = struct {
    running: bool = true,
    selected_panel: u8 = 0,
    cpu_history: [60]u8 = [_]u8{0} ** 60,
    mem_history: [60]u8 = [_]u8{0} ** 60,
    history_index: usize = 0,
    cpu_usage: u8 = 45,
    mem_usage: u8 = 62,
    disk_usage: u8 = 78,
    network_in: u32 = 1234,
    network_out: u32 = 567,
    processes: [8]Process = .{
        .{ .name = "zig", .cpu = 12, .mem = 156 },
        .{ .name = "code", .cpu = 8, .mem = 892 },
        .{ .name = "chrome", .cpu = 15, .mem = 2048 },
        .{ .name = "spotify", .cpu = 3, .mem = 384 },
        .{ .name = "discord", .cpu = 2, .mem = 512 },
        .{ .name = "terminal", .cpu = 1, .mem = 64 },
        .{ .name = "systemd", .cpu = 0, .mem = 12 },
        .{ .name = "kernel", .cpu = 1, .mem = 0 },
    },
    selected_process: usize = 0,
    log_scroll: usize = 0,
    tick: u64 = 0,

    const Process = struct {
        name: []const u8,
        cpu: u8,
        mem: u16,
    };

    fn update(self: *AppState) void {
        self.tick += 1;

        // Simulate changing values
        const seed = @as(u32, @truncate(self.tick));
        self.cpu_usage = @intCast(30 + (seed * 7) % 40);
        self.mem_usage = @intCast(50 + (seed * 3) % 30);
        self.network_in = 800 + (seed * 13) % 1000;
        self.network_out = 200 + (seed * 11) % 600;

        // Update history
        self.cpu_history[self.history_index] = self.cpu_usage;
        self.mem_history[self.history_index] = self.mem_usage;
        self.history_index = (self.history_index + 1) % 60;
    }
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

    var state = AppState{};

    while (state.running) {
        const event = try backend.interface().pollEvent(100);

        switch (event) {
            .key => |key| {
                switch (key.code) {
                    .char => |c| {
                        if (c == 'q' or c == 'Q') state.running = false;
                    },
                    .tab => {
                        state.selected_panel = (state.selected_panel + 1) % 4;
                    },
                    .up => {
                        if (state.selected_panel == 2 and state.selected_process > 0) {
                            state.selected_process -= 1;
                        }
                    },
                    .down => {
                        if (state.selected_panel == 2 and state.selected_process < 7) {
                            state.selected_process += 1;
                        }
                    },
                    .esc => state.running = false,
                    else => {},
                }
            },
            .resize => |size| {
                try terminal.resize(.{ .width = size.width, .height = size.height });
            },
            else => {},
        }

        state.update();

        const DrawContext = struct { state: *AppState, allocator: std.mem.Allocator };
        const ctx = DrawContext{ .state = &state, .allocator = allocator };

        try terminal.draw(ctx, struct {
            fn render(draw_ctx: DrawContext, buf: *Buffer) !void {
                const area = buf.getArea();
                const app = draw_ctx.state;

                // Main border with title
                const main_block = Block{
                    .title = " ZigTUI System Monitor ",
                    .borders = Borders.all(),
                    .style = Style{ .bg = .black },
                    .border_style = Style{ .fg = .cyan },
                    .title_style = Style{ .fg = .white, .modifier = Modifier{ .bold = true } },
                    .border_symbols = BorderSymbols.double(),
                };
                main_block.render(area, buf);

                // Calculate layout
                const inner = Rect{
                    .x = area.x + 1,
                    .y = area.y + 1,
                    .width = area.width -| 2,
                    .height = area.height -| 2,
                };

                if (inner.width < 40 or inner.height < 10) return;

                // Top row: System stats
                const top_height = 7;
                const top_area = Rect{ .x = inner.x, .y = inner.y, .width = inner.width, .height = top_height };

                // Bottom area: Process list and logs
                const bottom_y = inner.y + top_height;
                const bottom_height = inner.height -| top_height;
                const bottom_area = Rect{ .x = inner.x, .y = bottom_y, .width = inner.width, .height = bottom_height };

                // Draw panels
                drawSystemStats(top_area, buf, app);
                drawBottomPanels(bottom_area, buf, app);

                // Draw footer
                drawFooter(area, buf);
            }
        }.render);
    }

    try terminal.showCursor();
}

fn drawSystemStats(area: Rect, buf: *Buffer, state: *AppState) void {
    if (area.width < 20) return;

    const panel_width = area.width / 4;

    // CPU Panel
    const cpu_area = Rect{ .x = area.x, .y = area.y, .width = panel_width, .height = area.height };
    drawGaugePanel(cpu_area, buf, "CPU", state.cpu_usage, .cyan, state.selected_panel == 0);

    // Memory Panel
    const mem_area = Rect{ .x = area.x + panel_width, .y = area.y, .width = panel_width, .height = area.height };
    drawGaugePanel(mem_area, buf, "Memory", state.mem_usage, .green, state.selected_panel == 1);

    // Disk Panel
    const disk_area = Rect{ .x = area.x + panel_width * 2, .y = area.y, .width = panel_width, .height = area.height };
    drawGaugePanel(disk_area, buf, "Disk", state.disk_usage, .yellow, state.selected_panel == 2);

    // Network Panel
    const net_area = Rect{ .x = area.x + panel_width * 3, .y = area.y, .width = area.width - panel_width * 3, .height = area.height };
    drawNetworkPanel(net_area, buf, state);
}

fn drawGaugePanel(area: Rect, buf: *Buffer, title: []const u8, value: u8, color: Color, selected: bool) void {
    const border_color: Color = if (selected) .white else .gray;
    const block = Block{
        .title = title,
        .borders = Borders.all(),
        .border_style = Style{ .fg = border_color, .modifier = if (selected) Modifier{ .bold = true } else .{} },
        .title_style = Style{ .fg = color, .modifier = Modifier{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    block.render(area, buf);

    if (area.height < 4 or area.width < 6) return;

    // Value display
    var val_buf: [8]u8 = undefined;
    const val_str = std.fmt.bufPrint(&val_buf, "{d}%", .{value}) catch return;
    const val_x = area.x + (area.width -| @as(u16, @intCast(val_str.len))) / 2;
    buf.setString(val_x, area.y + 2, val_str, Style{ .fg = color, .modifier = Modifier{ .bold = true } });

    // Progress bar using ASCII characters for Windows compatibility
    if (area.height >= 5 and area.width >= 6) {
        const bar_width = area.width -| 4;
        const filled = @as(u16, @intCast(value)) * bar_width / 100;
        const bar_y = area.y + 4;

        // Draw bar with ASCII: '#' for filled, '-' for empty
        var i: u16 = 0;
        while (i < bar_width) : (i += 1) {
            const char: u21 = if (i < filled) '#' else '-';
            const fg: Color = if (i < filled) color else .dark_gray;
            buf.setChar(area.x + 2 + i, bar_y, char, Style{ .fg = fg });
        }
    }
}

fn drawNetworkPanel(area: Rect, buf: *Buffer, state: *AppState) void {
    const block = Block{
        .title = "Network",
        .borders = Borders.all(),
        .border_style = Style{ .fg = .gray },
        .title_style = Style{ .fg = .magenta, .modifier = Modifier{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    block.render(area, buf);

    if (area.height < 4 or area.width < 10) return;

    // Download - using ASCII 'v' instead of Unicode arrow
    var dl_buf: [20]u8 = undefined;
    const dl_str = std.fmt.bufPrint(&dl_buf, "v {d} KB/s", .{state.network_in}) catch return;
    buf.setString(area.x + 2, area.y + 2, dl_str, Style{ .fg = .green });

    // Upload - using ASCII '^' instead of Unicode arrow
    var ul_buf: [20]u8 = undefined;
    const ul_str = std.fmt.bufPrint(&ul_buf, "^ {d} KB/s", .{state.network_out}) catch return;
    buf.setString(area.x + 2, area.y + 4, ul_str, Style{ .fg = .red });
}

fn drawBottomPanels(area: Rect, buf: *Buffer, state: *AppState) void {
    if (area.width < 20) return;

    const left_width = area.width / 2;

    // Process list
    const proc_area = Rect{ .x = area.x, .y = area.y, .width = left_width, .height = area.height };
    drawProcessList(proc_area, buf, state);

    // Sparkline / Activity
    const spark_area = Rect{ .x = area.x + left_width, .y = area.y, .width = area.width - left_width, .height = area.height };
    drawActivityPanel(spark_area, buf, state);
}

fn drawProcessList(area: Rect, buf: *Buffer, state: *AppState) void {
    const selected = state.selected_panel == 2;
    const block = Block{
        .title = " Processes ",
        .borders = Borders.all(),
        .border_style = Style{ .fg = if (selected) .white else .gray, .modifier = if (selected) Modifier{ .bold = true } else .{} },
        .title_style = Style{ .fg = .yellow, .modifier = Modifier{ .bold = true } },
        .border_symbols = BorderSymbols.line(),
    };
    block.render(area, buf);

    if (area.height < 4 or area.width < 20) return;

    // Header
    buf.setString(area.x + 2, area.y + 1, "NAME", Style{ .fg = .cyan, .modifier = Modifier{ .bold = true } });
    buf.setString(area.x + 14, area.y + 1, "CPU", Style{ .fg = .cyan, .modifier = Modifier{ .bold = true } });
    buf.setString(area.x + 20, area.y + 1, "MEM", Style{ .fg = .cyan, .modifier = Modifier{ .bold = true } });

    // Separator ─ using ASCII dash for Windows compatibility
    var i: u16 = 0;
    while (i < area.width -| 4) : (i += 1) {
        buf.setChar(area.x + 2 + i, area.y + 2, '─', Style{ .fg = .dark_gray });
    }

    // Process rows
    const max_rows = @min(state.processes.len, area.height -| 4);
    for (state.processes[0..max_rows], 0..) |proc, idx| {
        const y = area.y + 3 + @as(u16, @intCast(idx));
        const is_selected = selected and idx == state.selected_process;

        const row_style = if (is_selected)
            Style{ .fg = .black, .bg = .cyan }
        else
            Style{ .fg = .white };

        // Fill row background if selected
        if (is_selected) {
            var x: u16 = 0;
            while (x < area.width -| 4) : (x += 1) {
                buf.setChar(area.x + 2 + x, y, ' ', row_style);
            }
        }

        buf.setString(area.x + 2, y, proc.name, row_style);

        var cpu_buf: [8]u8 = undefined;
        const cpu_str = std.fmt.bufPrint(&cpu_buf, "{d}%", .{proc.cpu}) catch continue;
        buf.setString(area.x + 14, y, cpu_str, row_style);

        var mem_buf: [12]u8 = undefined;
        const mem_str = std.fmt.bufPrint(&mem_buf, "{d}MB", .{proc.mem}) catch continue;
        buf.setString(area.x + 20, y, mem_str, row_style);
    }
}

fn drawActivityPanel(area: Rect, buf: *Buffer, state: *AppState) void {
    const selected = state.selected_panel == 3;
    const block = Block{
        .title = " CPU History ",
        .borders = Borders.all(),
        .border_style = Style{ .fg = if (selected) .white else .gray },
        .title_style = Style{ .fg = .cyan, .modifier = Modifier{ .bold = true } },
        .border_symbols = BorderSymbols.line(),
    };
    block.render(area, buf);

    if (area.height < 4 or area.width < 10) return;

    // Draw sparkline using ASCII characters for Windows compatibility
    const spark_width = @min(@as(usize, area.width -| 4), 60);
    const spark_height = area.height -| 3;

    if (spark_height == 0) return;

    // ASCII bar visualization: '_', '.', '-', '=', '#', '@'
    const blocks = [_]u21{ ' ', '_', '.', '-', '=', '#', '@', '*', '|' };

    var x: usize = 0;
    while (x < spark_width) : (x += 1) {
        const hist_idx = (state.history_index + 60 - spark_width + x) % 60;
        const value = state.cpu_history[hist_idx];
        const normalized = @as(usize, value) * 8 / 100;
        const char = blocks[@min(normalized, 8)];

        const color: Color = if (value > 80) .red else if (value > 50) .yellow else .cyan;
        buf.setChar(area.x + 2 + @as(u16, @intCast(x)), area.y + area.height - 2, char, Style{ .fg = color });
    }

    // Draw scale
    buf.setString(area.x + 2, area.y + 1, "100%", Style{ .fg = .dark_gray });
    buf.setString(area.x + 2, area.y + area.height - 3, "0%", Style{ .fg = .dark_gray });
}

fn drawFooter(area: Rect, buf: *Buffer) void {
    const footer_y = area.y + area.height - 1;
    const help = " [Tab] Switch Panel  [Up/Down] Navigate  [Q] Quit ";
    const help_x = area.x + (area.width -| @as(u16, @intCast(help.len))) / 2;
    buf.setString(help_x, footer_y, help, Style{ .fg = .dark_gray });
}
