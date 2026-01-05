//! ZigTUI Kitty Graphics Example
//! Demonstrates displaying images in terminals with Kitty Graphics protocol support
//! Controls: 'q' to quit, 'r' to refresh, 't' to toggle between image and fallback
//!
//! This example shows:
//! - Detecting Kitty Graphics support
//! - Displaying images using the Kitty protocol
//! - Fallback to Unicode block characters for unsupported terminals

const std = @import("std");
const tui = @import("zigtui");

const Terminal = tui.terminal.Terminal;
const Buffer = tui.render.Buffer;
const Rect = tui.render.Rect;
const Color = tui.style.Color;
const Style = tui.style.Style;
const Graphics = tui.graphics.Graphics;
const Image = tui.graphics.Image;
const KittyGraphics = tui.graphics.KittyGraphics;
const Block = tui.widgets.Block;
const Borders = tui.widgets.Borders;
const BorderSymbols = tui.widgets.BorderSymbols;

const AppState = struct {
    running: bool = true,
    graphics: Graphics,
    test_image: ?Image = null,
    force_fallback: bool = false,
    status_message: []const u8 = "Initializing...",
    frame_count: u64 = 0,
    image_escape_seq: ?[]const u8 = null,

    fn init(allocator: std.mem.Allocator) !AppState {
        var gfx = Graphics.init(allocator);
        const mode = gfx.detect();

        const status = switch (mode) {
            .kitty => "Kitty Graphics detected! Displaying image...",
            .sixel => "Sixel detected (limited support)",
            .block => "No graphics protocol - using Unicode blocks",
            .ascii => "ASCII fallback mode",
        };

        return .{
            .graphics = gfx,
            .status_message = status,
        };
    }

    fn deinit(self: *AppState, allocator: std.mem.Allocator) void {
        if (self.test_image) |img| {
            allocator.free(img.data);
        }
        self.graphics.deinit();
    }

    fn toggleFallback(self: *AppState) void {
        self.force_fallback = !self.force_fallback;
        if (self.force_fallback) {
            self.status_message = "Forced Unicode block fallback";
        } else {
            self.status_message = switch (self.graphics.mode) {
                .kitty => "Kitty Graphics mode",
                .sixel => "Sixel mode",
                .block => "Unicode block mode",
                .ascii => "ASCII mode",
            };
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize backend and terminal
    var backend = try tui.backend.init(allocator);
    defer backend.deinit();

    var terminal = try Terminal.init(allocator, backend.interface());
    defer terminal.deinit();

    try terminal.hideCursor();

    // Initialize app state with graphics detection
    var state = try AppState.init(allocator);
    defer state.deinit(allocator);

    // Try to load demo.bmp - works for both Kitty and fallback mode
    state.test_image = loadDemoImage(allocator) catch blk: {
        // Fall back to gradient if no demo.bmp found
        break :blk try generateGradientImage(allocator, 128, 128);
    };

    if (state.graphics.supportsImages()) {
        state.status_message = "Kitty Graphics - displaying image!";
    } else {
        state.status_message = "Unicode blocks - convert image to demo.bmp!";
    }

    // Main loop
    while (state.running) {
        const event = try backend.interface().pollEvent(100);

        switch (event) {
            .key => |key| {
                switch (key.code) {
                    .char => |c| {
                        switch (c) {
                            'q', 'Q' => state.running = false,
                            'r', 'R' => state.frame_count = 0,
                            't', 'T' => state.toggleFallback(),
                            else => {},
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

        state.frame_count += 1;

        const DrawContext = struct {
            state: *AppState,
            allocator: std.mem.Allocator,
            backend_iface: tui.Backend,
        };

        const ctx = DrawContext{
            .state = &state,
            .allocator = allocator,
            .backend_iface = backend.interface(),
        };

        try terminal.draw(ctx, struct {
            fn render(draw_ctx: DrawContext, buf: *Buffer) !void {
                const area = buf.getArea();
                const app = draw_ctx.state;

                // No borders - use ENTIRE terminal for the image!
                const image_area = Rect{
                    .x = 0,
                    .y = 0,
                    .width = area.width,
                    .height = area.height -| 1, // Leave 1 row for controls
                };

                drawImagePanel(buf, image_area, app, draw_ctx.backend_iface);

                // Draw controls at bottom
                drawControls(buf, area);
            }
        }.render);
    }

    // Clean up images from terminal before exit
    if (!state.force_fallback and state.graphics.mode == .kitty) {
        if (try state.graphics.clearImages()) |seq| {
            try backend.interface().write(seq);
            try backend.interface().flush();
        }
    }

    try terminal.showCursor();
}

fn drawInfoPanel(buf: *Buffer, area: Rect, state: *AppState) void {
    const title_style = Style{ .fg = .white, .modifier = .{ .bold = true } };
    const value_style = Style{ .fg = .green };

    // Compact single-line info
    buf.setString(area.x, area.y, "Mode: ", title_style);
    const mode_name = switch (state.graphics.mode) {
        .kitty => "Kitty",
        .sixel => "Sixel",
        .block => "Blocks",
        .ascii => "ASCII",
    };
    buf.setString(area.x + 6, area.y, mode_name, value_style);

    var frame_buf: [32]u8 = undefined;
    const info_str = std.fmt.bufPrint(&frame_buf, " | Frame: {d}", .{state.frame_count}) catch "";
    buf.setString(area.x + 6 + @as(u16, @intCast(mode_name.len)), area.y, info_str, Style{ .fg = .gray });
}

fn drawImagePanel(buf: *Buffer, area: Rect, state: *AppState, backend_iface: tui.Backend) void {
    // No border - use full area for image!
    if (state.test_image) |image| {
        // Use Kitty graphics if available and not forced to fallback
        if (!state.force_fallback and state.graphics.mode == .kitty) {
            // For Kitty, we send escape sequences directly
            if (state.graphics.kitty_gfx) |*kg| {
                const placement = tui.graphics.Placement{
                    .x = area.x,
                    .y = area.y,
                    .width = area.width,
                    .height = area.height,
                };

                if (kg.drawImage(image, placement)) |seq| {
                    backend_iface.write(seq) catch {};
                } else |_| {}
            }
        } else {
            // Fallback: render using Unicode half-blocks - FULL AREA
            state.graphics.renderImageToBuffer(image, buf, area);
        }
    } else {
        // No image loaded
        buf.setString(
            area.x + (area.width -| 14) / 2,
            area.y + area.height / 2,
            "[No Image]",
            Style{ .fg = .gray },
        );
    }
}

fn drawControls(buf: *Buffer, area: Rect) void {
    const y = area.y + area.height - 1;  // Very bottom row
    const help_style = Style{ .fg = .gray };
    const key_style = Style{ .fg = .cyan, .modifier = .{ .bold = true } };

    var x = area.x + 2;

    buf.setString(x, y, "[", help_style);
    x += 1;
    buf.setString(x, y, "Q", key_style);
    x += 1;
    buf.setString(x, y, "]uit  ", help_style);
    x += 6;

    buf.setString(x, y, "[", help_style);
    x += 1;
    buf.setString(x, y, "R", key_style);
    x += 1;
    buf.setString(x, y, "]efresh  ", help_style);
    x += 9;

    buf.setString(x, y, "[", help_style);
    x += 1;
    buf.setString(x, y, "T", key_style);
    x += 1;
    buf.setString(x, y, "]oggle Fallback", help_style);
}

/// Generate a gradient test image
fn generateGradientImage(allocator: std.mem.Allocator, width: u32, height: u32) !Image {
    const data = try allocator.alloc(u8, @as(usize, width) * @as(usize, height) * 4);

    for (0..height) |y| {
        for (0..width) |x| {
            const offset = (y * width + x) * 4;

            // Create a nice gradient pattern
            const r: u8 = @intCast((x * 255) / width);
            const g: u8 = @intCast((y * 255) / height);
            const b: u8 = @intCast(((x + y) * 128) / (width + height));

            data[offset] = r;
            data[offset + 1] = g;
            data[offset + 2] = b;
            data[offset + 3] = 255; // Alpha
        }
    }

    return Image{
        .data = data,
        .width = width,
        .height = height,
        .format = .rgba,
        .stride = 4,
    };
}

/// Load demo.bmp from the examples directory (BMP format for easy decoding)
fn loadDemoImage(allocator: std.mem.Allocator) !Image {
    // Try to find demo.bmp relative to executable or in examples folder
    const paths = [_][]const u8{
        "examples/demo.bmp",
        "demo.bmp",
        "../examples/demo.bmp",
    };

    for (paths) |path| {
        // Use the BMP decoder
        const bmp_image = tui.graphics.bmp.loadFile(allocator, path) catch continue;
        
        // Transfer ownership - the Image will own this data
        return Image{
            .data = bmp_image.data,
            .width = bmp_image.width,
            .height = bmp_image.height,
            .format = .rgba,
            .stride = 4,
        };
    }

    return error.FileNotFound;
}
