/// widgets_demo.zig — interactive showcase of every new widget.
///
/// Controls:
///   Tab / Shift+Tab  → cycle through demo tabs
///   Arrow keys       → navigate lists, tree, bar chart
///   Enter            → toggle tree node / confirm dialog
///   t                → cycle Spinner kind
///   q / Esc          → quit
const std = @import("std");
const tui = @import("zigtui");

const Terminal = tui.terminal.Terminal;
const Buffer = tui.render.Buffer;
const Rect = tui.render.Rect;
const Style = tui.style.Style;
const Modifier = tui.style.Modifier;
const Block = tui.widgets.Block;
const Borders = tui.widgets.Borders;
const BorderSymbols = tui.widgets.BorderSymbols;
const Paragraph = tui.widgets.Paragraph;
const Tabs = tui.widgets.Tabs;
const Sparkline = tui.widgets.Sparkline;
const BarChart = tui.widgets.BarChart;
const Bar = tui.widgets.Bar;
const BarDirection = tui.widgets.BarDirection;
const TextInput = tui.widgets.TextInput;
const Spinner = tui.widgets.Spinner;
const SpinnerKind = tui.widgets.SpinnerKind;
const Tree = tui.widgets.Tree;
const TreeNode = tui.widgets.TreeNode;
const Canvas = tui.widgets.Canvas;
const Popup = tui.widgets.Popup;
const Dialog = tui.widgets.Dialog;
const centeredRectPct = tui.widgets.centeredRectPct;

// ─────────────────────────────────────────────────────────────────────────────
// Demo state
// ─────────────────────────────────────────────────────────────────────────────

const Tab = enum(u8) {
    sparkline = 0,
    bar_chart,
    text_input,
    spinner,
    tree,
    canvas,
    popup,
};

const tab_titles = [_][]const u8{
    "Sparkline",
    "BarChart",
    "TextInput",
    "Spinner",
    "Tree",
    "Canvas",
    "Popup",
};

const AppState = struct {
    running: bool = true,
    tab: Tab = .sparkline,
    tick: u64 = 0,

    // Sparkline
    spark_data: [80]f64 = [_]f64{0} ** 80,
    spark_head: usize = 0,

    // BarChart
    bar_selected: usize = 0,
    bar_direction: BarDirection = .vertical,

    // TextInput
    input: TextInput(256) = .{
        .style = .{ .fg = .white },
        .cursor_style = .{ .fg = .black, .bg = .white },
        .placeholder = "Type something…",
        .focused = true,
    },

    // Spinner
    spinner: Spinner = .{ .kind = .dots, .style = .{ .fg = .cyan }, .label = "Loading data…", .label_style = .{ .fg = .white } },

    // Tree
    tree_nodes: [3]TreeNode = undefined,
    src_children: [4]TreeNode = undefined,
    examples_children: [2]TreeNode = undefined,
    tree_selected: ?usize = 0,

    // Popup / Dialog
    show_popup: bool = false,
    show_dialog: bool = false,
    dialog: Dialog = .{
        .title = " Quit? ",
        .message = "Are you sure you want to exit the widgets demo?",
        .buttons = &.{ "Yes", "No" },
        .selected_button = 1,
        .border_style = .{ .fg = .yellow },
        .selected_button_style = .{ .fg = .black, .bg = .yellow, .modifier = .{ .bold = true } },
        .button_style = .{ .fg = .white },
        .message_style = .{ .fg = .white },
    },

    fn init() AppState {
        var s = AppState{};

        // Pre-fill sparkline with a sine-like wave
        for (&s.spark_data, 0..) |*v, i| {
            const fi = @as(f64, @floatFromInt(i));
            v.* = 50.0 + 40.0 * @sin(fi * 0.2) + 10.0 * @sin(fi * 0.7);
        }

        return s;
    }

    /// Must be called once after `init()` returns, while `self` is in its final
    /// stack slot.  Sets up tree child-slice pointers that must refer to fields
    /// of the *live* AppState — not a temporary copy on the init() stack frame.
    fn initNodes(self: *AppState) void {
        self.src_children = .{
            TreeNode{ .label = "lib.zig" },
            TreeNode{ .label = "widgets/mod.zig" },
            TreeNode{ .label = "render/mod.zig" },
            TreeNode{ .label = "events/mod.zig" },
        };
        self.examples_children = .{
            TreeNode{ .label = "dashboard.zig" },
            TreeNode{ .label = "widgets_demo.zig", .style = .{ .fg = .cyan } },
        };
        self.tree_nodes = .{
            TreeNode{ .label = "src/", .children = &self.src_children, .expanded = true },
            TreeNode{ .label = "examples/", .children = &self.examples_children, .expanded = false },
            TreeNode{ .label = "build.zig" },
        };
    }

    fn update(self: *AppState) void {
        self.tick += 1;
        self.spinner.tick();

        // Scroll sparkline
        if (self.tick % 5 == 0) {
            const fi = @as(f64, @floatFromInt(self.tick));
            self.spark_data[self.spark_head] = 50.0 + 40.0 * @sin(fi * 0.12) + 10.0 * @sin(fi * 0.5);
            self.spark_head = (self.spark_head + 1) % self.spark_data.len;
        }
    }

    fn currentTree(self: *AppState) Tree {
        return Tree{
            .roots = &self.tree_nodes,
            .selected = self.tree_selected,
            .style = .{ .fg = .white },
            .highlight_style = .{ .fg = .black, .bg = .cyan },
            .expanded_symbol = "▼ ",
            .collapsed_symbol = "▶ ",
            .leaf_symbol = "  ",
        };
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var backend = try tui.backend.init(allocator);
    defer backend.deinit();

    var terminal = try Terminal.init(allocator, backend.interface());
    defer terminal.deinit();

    try terminal.hideCursor();

    var state = AppState.init();
    state.initNodes();

    while (state.running) {
        const event = try backend.interface().pollEvent(80);

        // ── Global key handling ────────────────────────────────────────────
        switch (event) {
            .key => |key| {
                // Close dialog / popup first
                if (state.show_dialog) {
                    switch (key.code) {
                        .left, .back_tab => state.dialog.selectPreviousButton(),
                        .right, .tab => state.dialog.selectNextButton(),
                        .enter => {
                            if (state.dialog.selected_button == 0) {
                                state.running = false;
                            }
                            state.show_dialog = false;
                        },
                        .esc => state.show_dialog = false,
                        else => {},
                    }
                } else if (state.show_popup) {
                    state.show_popup = false;
                } else {
                    switch (key.code) {
                        .char => |c| switch (c) {
                            'q', 'Q' => {
                                state.show_dialog = true;
                            },
                            't', 'T' => {
                                // Cycle spinner kind
                                const kinds = [_]SpinnerKind{ .dots, .line, .arrow, .bounce, .bar };
                                const cur = @intFromEnum(state.spinner.kind);
                                state.spinner.kind = kinds[(cur + 1) % kinds.len];
                                state.spinner.reset();
                            },
                            'p', 'P' => state.show_popup = !state.show_popup,
                            'd', 'D' => {
                                if (state.tab == .bar_chart) {
                                    state.bar_direction = if (state.bar_direction == .vertical) .horizontal else .vertical;
                                }
                            },
                            else => {
                                if (state.tab == .text_input) {
                                    state.input.insertCodepoint(c);
                                }
                            },
                        },
                        .tab => {
                            const next = (@intFromEnum(state.tab) + 1) % tab_titles.len;
                            state.tab = @enumFromInt(next);
                        },
                        .back_tab => {
                            const cur = @intFromEnum(state.tab);
                            const prev = if (cur == 0) tab_titles.len - 1 else cur - 1;
                            state.tab = @enumFromInt(prev);
                        },
                        .backspace => {
                            if (state.tab == .text_input) state.input.deleteBackward();
                        },
                        .delete => {
                            if (state.tab == .text_input) state.input.deleteForward();
                        },
                        .left => {
                            if (state.tab == .text_input) state.input.moveCursorLeft();
                        },
                        .right => {
                            if (state.tab == .text_input) state.input.moveCursorRight();
                        },
                        .home => {
                            if (state.tab == .text_input) state.input.moveCursorHome();
                        },
                        .end => {
                            if (state.tab == .text_input) state.input.moveCursorEnd();
                        },
                        .up => {
                            switch (state.tab) {
                                .tree => {
                                    var tree = state.currentTree();
                                    tree.selectPrevious();
                                    state.tree_selected = tree.selected;
                                },
                                .bar_chart => {
                                    if (state.bar_selected > 0) state.bar_selected -= 1;
                                },
                                else => {},
                            }
                        },
                        .down => {
                            switch (state.tab) {
                                .tree => {
                                    var tree = state.currentTree();
                                    tree.selectNext();
                                    state.tree_selected = tree.selected;
                                },
                                .bar_chart => {
                                    if (state.bar_selected < 5) state.bar_selected += 1;
                                },
                                else => {},
                            }
                        },
                        .enter => {
                            if (state.tab == .tree) {
                                state.tree_nodes[0].expanded = !state.tree_nodes[0].expanded;
                                state.tree_nodes[1].expanded = !state.tree_nodes[1].expanded;
                            }
                        },
                        .esc => state.show_dialog = true,
                        else => {},
                    }
                }
            },
            .resize => |size| {
                try terminal.resize(.{ .width = size.width, .height = size.height });
            },
            else => {},
        }

        state.update();

        const Ctx = struct { s: *AppState };
        try terminal.draw(Ctx{ .s = &state }, struct {
            fn render(ctx: Ctx, buf: *Buffer) !void {
                drawFrame(ctx.s, buf);
            }
        }.render);
    }

    try terminal.showCursor();
}

// ─────────────────────────────────────────────────────────────────────────────
// Rendering
// ─────────────────────────────────────────────────────────────────────────────

fn drawFrame(state: *AppState, buf: *Buffer) void {
    const area = buf.getArea();

    // Outer border
    const outer = Block{
        .title = " ZigTUI — New Widgets Demo ",
        .borders = Borders.ALL,
        .border_style = .{ .fg = .cyan },
        .title_style = .{ .fg = .white, .modifier = .{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    outer.render(area, buf);

    if (area.width < 30 or area.height < 8) return;

    const inner = Rect{
        .x = area.x + 1,
        .y = area.y + 1,
        .width = area.width -| 2,
        .height = area.height -| 2,
    };

    // Tab bar (2 rows: tabs + separator)
    const tab_area = Rect{ .x = inner.x, .y = inner.y, .width = inner.width, .height = 1 };
    const content_area = Rect{
        .x = inner.x,
        .y = inner.y + 2,
        .width = inner.width,
        .height = inner.height -| 2,
    };

    drawTabs(state, tab_area, buf);
    drawSeparator(inner.x, inner.y + 1, inner.width, buf);
    drawContent(state, content_area, buf);
    drawHelp(area, buf);

    // Overlays (drawn last so they sit on top)
    if (state.show_popup) drawPopupOverlay(area, buf);
    if (state.show_dialog) drawDialogOverlay(state, area, buf);
}

fn drawTabs(state: *AppState, area: Rect, buf: *Buffer) void {
    var tabs = Tabs{
        .titles = &tab_titles,
        .selected = @intFromEnum(state.tab),
        .style = .{ .fg = .dark_gray },
        .selected_style = .{ .fg = .cyan, .modifier = .{ .bold = true, .underlined = true } },
        .unselected_style = .{ .fg = .gray },
        .divider = 0x2502,
        .padding = 1,
    };
    tabs.render(area, buf);
}

fn drawSeparator(x: u16, y: u16, width: u16, buf: *Buffer) void {
    var i: u16 = 0;
    while (i < width) : (i += 1) {
        buf.setChar(x + i, y, 0x2500, .{ .fg = .dark_gray });
    }
}

fn drawContent(state: *AppState, area: Rect, buf: *Buffer) void {
    switch (state.tab) {
        .sparkline => drawSparklineTab(state, area, buf),
        .bar_chart => drawBarChartTab(state, area, buf),
        .text_input => drawTextInputTab(state, area, buf),
        .spinner => drawSpinnerTab(state, area, buf),
        .tree => drawTreeTab(state, area, buf),
        .canvas => drawCanvasTab(area, buf),
        .popup => drawPopupInfoTab(area, buf),
    }
}

// ── Sparkline tab ─────────────────────────────────────────────────────────────

fn drawSparklineTab(state: *AppState, area: Rect, buf: *Buffer) void {
    const blk = Block{
        .title = " Live Metric — Sparkline ",
        .borders = Borders.ALL,
        .border_style = .{ .fg = .gray },
        .title_style = .{ .fg = .green, .modifier = .{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    blk.render(area, buf);

    const inner = blk.inner(area);
    if (inner.height == 0 or inner.width == 0) return;

    // Label
    buf.setString(inner.x, inner.y, "CPU sim (sine wave):", .{ .fg = .dark_gray });

    // Rearrange data so the most recent point is last
    var ordered: [80]f64 = undefined;
    const n = @min(state.spark_data.len, @as(usize, inner.width));
    const head = state.spark_head;
    const total = state.spark_data.len;
    for (0..n) |i| {
        ordered[i] = state.spark_data[(head + total - n + i) % total];
    }

    const spark = Sparkline{
        .data = ordered[0..n],
        .max = 100.0,
        .style = .{ .fg = .green },
    };
    const spark_area = Rect{
        .x = inner.x,
        .y = inner.y + 1,
        .width = inner.width,
        .height = if (inner.height > 1) inner.height - 1 else 0,
    };
    spark.render(spark_area, buf);
}

// ── BarChart tab ──────────────────────────────────────────────────────────────

const bar_data = [_]Bar{
    .{ .label = "Jan", .value = 42 },
    .{ .label = "Feb", .value = 75 },
    .{ .label = "Mar", .value = 31 },
    .{ .label = "Apr", .value = 88 },
    .{ .label = "May", .value = 64 },
    .{ .label = "Jun", .value = 55 },
};

fn drawBarChartTab(state: *AppState, area: Rect, buf: *Buffer) void {
    const dir_label: []const u8 = if (state.bar_direction == .vertical) "Vertical" else "Horizontal";
    var title_buf: [40]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, " Monthly Revenue — {s} (d=toggle) ", .{dir_label}) catch " Monthly Revenue ";

    const blk = Block{
        .title = title,
        .borders = Borders.ALL,
        .border_style = .{ .fg = .gray },
        .title_style = .{ .fg = .yellow, .modifier = .{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    blk.render(area, buf);

    const inner = blk.inner(area);

    const chart = BarChart{
        .bars = &bar_data,
        .max = 100,
        .direction = state.bar_direction,
        .bar_width = if (state.bar_direction == .vertical) 5 else 2,
        .bar_gap = 1,
        .bar_style = .{ .fg = .yellow },
        .label_style = .{ .fg = .white },
        .bar_char = 0x2588,
        .empty_char = 0x2591,
    };
    chart.render(inner, buf);
}

// ── TextInput tab ─────────────────────────────────────────────────────────────

fn drawTextInputTab(state: *AppState, area: Rect, buf: *Buffer) void {
    const blk = Block{
        .title = " TextInput Widget ",
        .borders = Borders.ALL,
        .border_style = .{ .fg = .gray },
        .title_style = .{ .fg = .magenta, .modifier = .{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    blk.render(area, buf);

    const inner = blk.inner(area);
    if (inner.height == 0 or inner.width == 0) return;

    // Instruction rows
    buf.setString(inner.x, inner.y, "Single-line editable field — type, use ← → Home/End/Backspace/Del", .{ .fg = .dark_gray });

    if (inner.height < 3) return;

    // Input box
    const input_area = Rect{ .x = inner.x, .y = inner.y + 2, .width = inner.width, .height = 1 };
    const input_blk = Block{
        .borders = Borders.ALL,
        .border_style = .{ .fg = .magenta },
    };
    input_blk.render(
        .{ .x = input_area.x, .y = input_area.y -| 1, .width = input_area.width, .height = 3 },
        buf,
    );
    state.input.render(
        .{ .x = input_area.x + 1, .y = input_area.y, .width = input_area.width -| 2, .height = 1 },
        buf,
    );

    if (inner.height < 7) return;

    // Echo
    var echo_buf: [300]u8 = undefined;
    const echo = std.fmt.bufPrint(&echo_buf, "Buffer ({d} bytes): \"{s}\"", .{ state.input.len, state.input.value() }) catch return;
    buf.setString(inner.x, inner.y + 5, echo, .{ .fg = .white });
}

// ── Spinner tab ───────────────────────────────────────────────────────────────

fn drawSpinnerTab(state: *AppState, area: Rect, buf: *Buffer) void {
    const blk = Block{
        .title = " Spinner / Throbber (t=cycle kind) ",
        .borders = Borders.ALL,
        .border_style = .{ .fg = .gray },
        .title_style = .{ .fg = .cyan, .modifier = .{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    blk.render(area, buf);
    const inner = blk.inner(area);
    if (inner.height == 0 or inner.width == 0) return;

    const kinds = [_]SpinnerKind{ .dots, .line, .arrow, .bounce, .bar };
    const kind_names = [_][]const u8{ "dots", "line", "arrow", "bounce", "bar" };

    var y = inner.y;
    for (kinds, 0..) |kind, i| {
        if (y >= inner.y + inner.height) break;
        const is_active = state.spinner.kind == kind;
        const marker: u8 = if (is_active) '>' else ' ';
        buf.setChar(inner.x, y, marker, .{ .fg = .yellow });

        var sp = Spinner{
            .kind = kind,
            .frame = state.spinner.frame,
            .style = if (is_active) .{ .fg = .cyan } else .{ .fg = .dark_gray },
            .label = kind_names[i],
            .label_style = if (is_active) .{ .fg = .white } else .{ .fg = .dark_gray },
        };
        sp.render(.{ .x = inner.x + 2, .y = y, .width = inner.width -| 2, .height = 1 }, buf);
        y += 1;
    }
}

// ── Tree tab ──────────────────────────────────────────────────────────────────

fn drawTreeTab(state: *AppState, area: Rect, buf: *Buffer) void {
    const blk = Block{
        .title = " Tree (↑↓ navigate, Enter toggle all) ",
        .borders = Borders.ALL,
        .border_style = .{ .fg = .gray },
        .title_style = .{ .fg = .blue, .modifier = .{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    blk.render(area, buf);

    const inner = blk.inner(area);
    const tree = state.currentTree();
    tree.render(inner, buf);
}

// ── Canvas tab ────────────────────────────────────────────────────────────────

fn drawCanvasTab(area: Rect, buf: *Buffer) void {
    const blk = Block{
        .title = " Canvas — drawing primitives ",
        .borders = Borders.ALL,
        .border_style = .{ .fg = .gray },
        .title_style = .{ .fg = .red, .modifier = .{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    blk.render(area, buf);

    const inner = blk.inner(area);
    if (inner.width < 20 or inner.height < 8) return;

    var cv = Canvas.init(inner, buf, .{ .fg = .white });

    // Diagonal lines
    cv.drawLine(0, 0, inner.width -| 1, inner.height -| 1, '\\', .{ .fg = .dark_gray });
    cv.drawLine(inner.width -| 1, 0, 0, inner.height -| 1, '/', .{ .fg = .dark_gray });

    // Box in centre
    const bw: u16 = @min(20, inner.width -| 4);
    const bh: u16 = @min(8, inner.height -| 4);
    const bx = (inner.width -| bw) / 2;
    const by = (inner.height -| bh) / 2;
    cv.fillRect(.{ .x = bx, .y = by, .width = bw, .height = bh }, ' ', .{ .fg = .white, .bg = .black });
    cv.drawBox(.{ .x = bx, .y = by, .width = bw, .height = bh }, .{ .fg = .yellow });

    // Text inside the box
    cv.drawText(bx + 1, by + 1, "Canvas widget", .{ .fg = .yellow, .modifier = .{ .bold = true } });
    cv.drawText(bx + 1, by + 2, "drawLine  drawBox", .{ .fg = .white });
    cv.drawText(bx + 1, by + 3, "drawHLine drawVLine", .{ .fg = .white });
    cv.drawText(bx + 1, by + 4, "drawCircle fillRect", .{ .fg = .white });

    // Circle (if space allows)
    const cx = @min(@as(u16, 8), inner.width -| 1);
    const cy = @min(@as(u16, 4), inner.height -| 1);
    cv.drawCircle(cx, cy, @min(3, @min(cx, cy)), 'o', .{ .fg = .cyan });
}

// ── Popup info tab ────────────────────────────────────────────────────────────

fn drawPopupInfoTab(area: Rect, buf: *Buffer) void {
    const blk = Block{
        .title = " Popup & Dialog ",
        .borders = Borders.ALL,
        .border_style = .{ .fg = .gray },
        .title_style = .{ .fg = .white, .modifier = .{ .bold = true } },
        .border_symbols = BorderSymbols.rounded(),
    };
    blk.render(area, buf);

    const inner = blk.inner(area);
    const para = Paragraph{
        .text =
        \\Press [p] to show a Popup overlay.
        \\Press [q] or [Esc] to open a Dialog (with Yes/No buttons).
        \\
        \\Popup    — bordered floating box with optional backdrop dimming.
        \\           Use centeredRectPct() or centeredRectFixed() to position.
        \\
        \\Dialog   — Popup with a message and a row of [ buttons ].
        \\           Navigate buttons with ← → and confirm with Enter.
        ,
        .style = .{ .fg = .white },
        .wrap = true,
    };
    para.render(inner, buf);
}

// ── Overlays ──────────────────────────────────────────────────────────────────

fn drawPopupOverlay(area: Rect, buf: *Buffer) void {
    const pop_area = centeredRectPct(area, 50, 40);
    const pop = Popup{
        .title = " Info ",
        .border_style = .{ .fg = .cyan },
        .title_style = .{ .fg = .cyan, .modifier = .{ .bold = true } },
        .backdrop_style = .{ .fg = .dark_gray },
        .show_backdrop = true,
    };
    pop.render(pop_area, buf);

    const inner = Popup.innerArea(pop_area);
    const para = Paragraph{
        .text =
        \\This is a Popup overlay.
        \\
        \\It dims the content behind it
        \\and floats above everything else.
        \\
        \\Press any key to dismiss.
        ,
        .style = .{ .fg = .white },
        .wrap = true,
    };
    para.render(inner, buf);
}

fn drawDialogOverlay(state: *AppState, area: Rect, buf: *Buffer) void {
    const dlg_area = Dialog.dialogArea(area, 56, 9);
    state.dialog.render(dlg_area, buf);
}

// ── Help footer ───────────────────────────────────────────────────────────────

fn drawHelp(area: Rect, buf: *Buffer) void {
    const help = " [Tab/S-Tab] switch  [↑↓] navigate  [t] spinner  [p] popup  [q/Esc] quit ";
    const y = area.y + area.height - 1;
    const x = area.x + (area.width -| @as(u16, @intCast(help.len))) / 2;
    buf.setString(x, y, help, .{ .fg = .dark_gray });
}
