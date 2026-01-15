//! ZigTUI Themes Demo
//! Showcases all built-in themes with live preview
//! Controls: Up/Down to switch themes, 'q' to quit

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
const Theme = tui.Theme;
const themes = tui.themes;

const AppState = struct {
    running: bool = true,
    theme_index: usize = 0,
    selected_item: usize = 0,

    fn currentTheme(self: AppState) *const Theme {
        return themes.all_themes[self.theme_index];
    }

    fn nextTheme(self: *AppState) void {
        self.theme_index = (self.theme_index + 1) % themes.all_themes.len;
    }

    fn prevTheme(self: *AppState) void {
        if (self.theme_index == 0) {
            self.theme_index = themes.all_themes.len - 1;
        } else {
            self.theme_index -= 1;
        }
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
                        if (c == 'j') state.nextTheme();
                        if (c == 'k') state.prevTheme();
                    },
                    .up => state.prevTheme(),
                    .down => state.nextTheme(),
                    .esc => state.running = false,
                    else => {},
                }
            },
            else => {},
        }

        try terminal.draw(&state, renderUI);
    }

    try terminal.showCursor();
}

fn renderUI(state: *AppState, buf: *Buffer) !void {
    const area = buf.getArea();
    const theme = state.currentTheme();

    // Fill background
    buf.fillArea(area, ' ', theme.baseStyle());

    // Main container
    const main_block = Block{
        .title = " ZigTUI Theme Demo ",
        .borders = Borders.all(),
        .style = theme.baseStyle(),
        .border_style = theme.borderFocusedStyle(),
        .title_style = theme.titleStyle(),
    };
    main_block.render(area, buf);

    const inner = main_block.inner(area);
    if (inner.width < 60 or inner.height < 15) return;

    // Layout: Left panel (theme list) | Right panel (preview)
    const left_width = 28;
    const left_area = Rect{ .x = inner.x, .y = inner.y, .width = left_width, .height = inner.height };
    const right_area = Rect{ .x = inner.x + left_width + 1, .y = inner.y, .width = inner.width - left_width - 1, .height = inner.height };

    // Render theme list
    renderThemeList(state, left_area, buf, theme);

    // Render preview panel
    renderPreview(right_area, buf, theme);
}

fn renderThemeList(state: *AppState, area: Rect, buf: *Buffer, theme: *const Theme) void {
    const list_block = Block{
        .title = " Themes (↑/↓) ",
        .borders = Borders.all(),
        .style = theme.baseStyle(),
        .border_style = theme.borderStyle(),
        .title_style = theme.secondaryStyle().addModifier(Modifier.BOLD),
    };
    list_block.render(area, buf);

    const list_inner = list_block.inner(area);

    // Calculate visible range for scrolling
    const visible_count = @min(list_inner.height, themes.all_themes.len);
    var start_index: usize = 0;
    if (state.theme_index >= visible_count) {
        start_index = state.theme_index - visible_count + 1;
    }

    var y: u16 = 0;
    while (y < visible_count) : (y += 1) {
        const idx = start_index + y;
        if (idx >= themes.all_themes.len) break;

        const t = themes.all_themes[idx];
        const is_selected = idx == state.theme_index;

        const style = if (is_selected)
            theme.selectionStyle().addModifier(Modifier.BOLD)
        else
            theme.textStyle();

        // Clear line
        var x: u16 = 0;
        while (x < list_inner.width) : (x += 1) {
            buf.setChar(list_inner.x + x, list_inner.y + y, ' ', style);
        }

        // Draw indicator and name
        const prefix: []const u8 = if (is_selected) "▶ " else "  ";
        buf.setString(list_inner.x, list_inner.y + y, prefix, style);
        buf.setString(list_inner.x + 2, list_inner.y + y, t.name, style);
    }
}

fn renderPreview(area: Rect, buf: *Buffer, theme: *const Theme) void {
    const preview_block = Block{
        .title = " Preview ",
        .borders = Borders.all(),
        .style = theme.baseStyle(),
        .border_style = theme.borderStyle(),
        .title_style = theme.secondaryStyle().addModifier(Modifier.BOLD),
    };
    preview_block.render(area, buf);

    const inner = preview_block.inner(area);
    if (inner.height < 12) return;

    var y: u16 = 0;

    // Theme name and description
    buf.setString(inner.x, inner.y + y, theme.name, theme.titleStyle());
    y += 1;
    buf.setString(inner.x, inner.y + y, theme.description, theme.textMutedStyle());
    y += 2;

    // Color swatches
    buf.setString(inner.x, inner.y + y, "Colors:", theme.textStyle().addModifier(Modifier.BOLD));
    y += 1;

    // Primary, Secondary, Accent
    renderColorSwatch(buf, inner.x, inner.y + y, "Primary  ", theme.primary);
    renderColorSwatch(buf, inner.x + 14, inner.y + y, "Secondary", theme.secondary);
    renderColorSwatch(buf, inner.x + 28, inner.y + y, "Accent   ", theme.accent);
    y += 1;

    // Success, Warning, Error
    renderColorSwatch(buf, inner.x, inner.y + y, "Success  ", theme.success);
    renderColorSwatch(buf, inner.x + 14, inner.y + y, "Warning  ", theme.warning);
    renderColorSwatch(buf, inner.x + 28, inner.y + y, "Error    ", theme.error_color);
    y += 2;

    // Semantic styles demo
    buf.setString(inner.x, inner.y + y, "Semantic Styles:", theme.textStyle().addModifier(Modifier.BOLD));
    y += 1;

    buf.setString(inner.x, inner.y + y, "✓ Success message", theme.successStyle());
    y += 1;
    buf.setString(inner.x, inner.y + y, "⚠ Warning message", theme.warningStyle());
    y += 1;
    buf.setString(inner.x, inner.y + y, "✗ Error message", theme.errorStyle());
    y += 1;
    buf.setString(inner.x, inner.y + y, "ℹ Info message", theme.infoStyle());
    y += 2;

    // Gauge demo
    if (y + 3 < inner.height) {
        buf.setString(inner.x, inner.y + y, "Gauge Styles:", theme.textStyle().addModifier(Modifier.BOLD));
        y += 1;

        renderGaugeDemo(buf, inner.x, inner.y + y, inner.width - 2, 45, theme);
        y += 1;
        renderGaugeDemo(buf, inner.x, inner.y + y, inner.width - 2, 75, theme);
        y += 1;
        renderGaugeDemo(buf, inner.x, inner.y + y, inner.width - 2, 95, theme);
    }
}

fn renderColorSwatch(buf: *Buffer, x: u16, y: u16, label: []const u8, color: Color) void {
    buf.setString(x, y, "██", Style{ .fg = color });
    buf.setString(x + 3, y, label, Style{ .fg = color });
}

fn renderGaugeDemo(buf: *Buffer, x: u16, y: u16, width: u16, percent: u8, theme: *const Theme) void {
    const style = theme.gaugeStyle(percent);
    const filled_width = @as(u16, @intCast((@as(u32, width - 6) * percent) / 100));

    // Label
    var label_buf: [5]u8 = undefined;
    const label = std.fmt.bufPrint(&label_buf, "{d:3}%", .{percent}) catch "???%";
    buf.setString(x, y, label, style);

    // Bar
    var i: u16 = 0;
    while (i < width - 6) : (i += 1) {
        const char: u21 = if (i < filled_width) '█' else '░';
        buf.setChar(x + 5 + i, y, char, style);
    }
}
