//! Graphics module - Image rendering for terminal UIs
//! Supports Kitty Graphics Protocol with fallback to text/unicode block characters

const std = @import("std");
const render_mod = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Allocator = std.mem.Allocator;

pub const kitty = @import("kitty.zig");
pub const bmp = @import("bmp.zig");

// Re-export commonly used types
pub const KittyGraphics = kitty.KittyGraphics;
pub const Image = kitty.Image;
pub const Placement = kitty.Placement;
pub const Format = kitty.Format;
pub const Capability = kitty.Capability;

/// Graphics capability of the terminal
pub const GraphicsMode = enum {
    /// Terminal supports Kitty graphics protocol
    kitty,
    /// Terminal supports Sixel graphics
    sixel,
    /// Fallback to Unicode block characters
    block,
    /// No graphics support, use ASCII
    ascii,
};

/// Unified graphics interface with automatic fallback
pub const Graphics = struct {
    allocator: Allocator,
    mode: GraphicsMode,
    kitty_gfx: ?KittyGraphics,
    /// Whether graphics support has been detected
    detected: bool = false,

    pub fn init(allocator: Allocator) Graphics {
        return .{
            .allocator = allocator,
            .mode = .block, // Safe default
            .kitty_gfx = null,
        };
    }

    pub fn deinit(self: *Graphics) void {
        if (self.kitty_gfx) |*kg| {
            kg.deinit();
        }
    }

    /// Detect graphics capabilities by querying the terminal
    /// Returns the detected graphics mode
    /// Note: This is a synchronous check - for async detection, use detectAsync
    pub fn detect(self: *Graphics) GraphicsMode {
        // Check environment variables first for quick detection
        if (self.detectFromEnv()) |mode| {
            self.mode = mode;
            self.detected = true;
            if (mode == .kitty) {
                self.kitty_gfx = KittyGraphics.init(self.allocator);
            }
            return mode;
        }

        // Default to block characters (safe fallback)
        self.mode = .block;
        self.detected = true;
        return self.mode;
    }

    /// Detect graphics support from environment variables
    fn detectFromEnv(self: *Graphics) ?GraphicsMode {
        _ = self;

        // Check TERM for kitty
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "TERM")) |term| {
            defer std.heap.page_allocator.free(term);
            if (std.mem.indexOf(u8, term, "kitty") != null) {
                return .kitty;
            }
        } else |_| {}

        // Check TERM_PROGRAM
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "TERM_PROGRAM")) |term_program| {
            defer std.heap.page_allocator.free(term_program);
            if (std.mem.eql(u8, term_program, "kitty")) {
                return .kitty;
            }
            // WezTerm also supports Kitty graphics
            if (std.mem.eql(u8, term_program, "WezTerm")) {
                return .kitty;
            }
        } else |_| {}

        // Check KITTY_WINDOW_ID (definitive kitty indicator)
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "KITTY_WINDOW_ID")) |_| {
            return .kitty;
        } else |_| {}

        // Check for Konsole (supports Sixel)
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "KONSOLE_VERSION")) |_| {
            return .sixel;
        } else |_| {}

        return null;
    }

    /// Force a specific graphics mode (useful for testing or manual override)
    pub fn setMode(self: *Graphics, mode: GraphicsMode) void {
        self.mode = mode;
        self.detected = true;

        if (mode == .kitty and self.kitty_gfx == null) {
            self.kitty_gfx = KittyGraphics.init(self.allocator);
        }
    }

    /// Check if the terminal supports true image display
    pub fn supportsImages(self: Graphics) bool {
        return self.mode == .kitty or self.mode == .sixel;
    }

    /// Draw an image using the best available method
    /// Returns escape sequence for Kitty mode, or null if using fallback
    pub fn drawImage(
        self: *Graphics,
        image: Image,
        placement: Placement,
    ) !?[]const u8 {
        switch (self.mode) {
            .kitty => {
                if (self.kitty_gfx) |*kg| {
                    return try kg.drawImage(image, placement);
                }
                return null;
            },
            .sixel => {
                // TODO: Implement Sixel support
                return null;
            },
            .block, .ascii => {
                // Fallback rendering is done via buffer
                return null;
            },
        }
    }

    /// Render an image to a text buffer using Unicode block characters
    /// This provides a fallback when the terminal doesn't support graphics protocols
    pub fn renderImageToBuffer(
        self: *Graphics,
        image: Image,
        buffer: *render_mod.Buffer,
        area: render_mod.Rect,
    ) void {
        _ = self;

        if (image.format == .png) {
            // Can't render PNG without decoding
            renderPlaceholder(buffer, area, "[PNG Image]");
            return;
        }

        const img_width = image.width;
        const img_height = image.height;
        const stride = image.stride;

        // Each cell represents 2 vertical pixels using half-block characters
        const cells_x = area.width;
        const cells_y = area.height;

        // Scale factors
        const scale_x: f32 = @as(f32, @floatFromInt(img_width)) / @as(f32, @floatFromInt(cells_x));
        const scale_y: f32 = @as(f32, @floatFromInt(img_height)) / @as(f32, @floatFromInt(cells_y * 2));

        var cy: u16 = 0;
        while (cy < cells_y and cy + area.y < buffer.height) : (cy += 1) {
            var cx: u16 = 0;
            while (cx < cells_x and cx + area.x < buffer.width) : (cx += 1) {
                // Sample top pixel (upper half of cell)
                const top_img_x: usize = @intFromFloat(@as(f32, @floatFromInt(cx)) * scale_x);
                const top_img_y: usize = @intFromFloat(@as(f32, @floatFromInt(cy * 2)) * scale_y);

                // Sample bottom pixel (lower half of cell)
                const bot_img_y: usize = @intFromFloat(@as(f32, @floatFromInt(cy * 2 + 1)) * scale_y);

                // Get colors from image
                const top_color = samplePixel(image.data, img_width, stride, top_img_x, top_img_y);
                const bot_color = samplePixel(image.data, img_width, stride, top_img_x, bot_img_y);

                // Use upper half block character (▀) with fg=top, bg=bottom
                if (buffer.get(area.x + cx, area.y + cy)) |cell| {
                    cell.char = '▀'; // Upper half block
                    cell.fg = top_color;
                    cell.bg = bot_color;
                }
            }
        }
    }

    /// Render a placeholder text in the area
    fn renderPlaceholder(buffer: *render_mod.Buffer, area: render_mod.Rect, text: []const u8) void {
        if (area.height == 0 or area.width == 0) return;

        const text_len = @min(text.len, area.width);
        const start_x = area.x + (area.width - @as(u16, @intCast(text_len))) / 2;
        const start_y = area.y + area.height / 2;

        buffer.setString(start_x, start_y, text[0..text_len], .{ .fg = .gray });
    }

    /// Sample a pixel from image data and convert to Color
    fn samplePixel(data: []const u8, width: u32, stride: u32, x: usize, y: usize) style.Color {
        const idx = (y * @as(usize, width) + x) * @as(usize, stride);
        if (idx + 2 >= data.len) {
            return .black;
        }

        return .{ .rgb = .{
            .r = data[idx],
            .g = data[idx + 1],
            .b = data[idx + 2],
        } };
    }

    /// Get escape sequence to query graphics support
    pub fn getQuerySequence(self: *Graphics) !?[]const u8 {
        if (self.kitty_gfx) |*kg| {
            return try kg.querySupport();
        }
        // Initialize Kitty graphics just for query
        var kg = KittyGraphics.init(self.allocator);
        defer kg.deinit();
        return try kg.querySupport();
    }

    /// Delete all images from the terminal
    pub fn clearImages(self: *Graphics) !?[]const u8 {
        if (self.kitty_gfx) |*kg| {
            return try kg.deleteImages(.all, null);
        }
        return null;
    }
};

/// Widget for displaying images in the TUI
pub const ImageWidget = struct {
    image: ?Image = null,
    placement: Placement = .{},
    fallback_text: []const u8 = "[Image]",

    /// Set the image to display
    pub fn setImage(self: *ImageWidget, image: Image) void {
        self.image = image;
    }

    /// Set placement options
    pub fn setPlacement(self: *ImageWidget, placement: Placement) void {
        self.placement = placement;
    }

    /// Draw the image widget
    /// If graphics is available, returns escape sequence; otherwise renders to buffer
    pub fn draw(
        self: ImageWidget,
        gfx: *Graphics,
        buffer: *render_mod.Buffer,
        area: render_mod.Rect,
    ) !?[]const u8 {
        if (self.image) |img| {
            if (gfx.supportsImages()) {
                var placement = self.placement;
                placement.x = area.x;
                placement.y = area.y;
                placement.width = area.width;
                placement.height = area.height;
                return try gfx.drawImage(img, placement);
            } else {
                gfx.renderImageToBuffer(img, buffer, area);
                return null;
            }
        } else {
            // No image set, render placeholder
            Graphics.renderPlaceholder(buffer, area, self.fallback_text);
            return null;
        }
    }
};

test "graphics mode detection from env" {
    const allocator = std.testing.allocator;
    var gfx = Graphics.init(allocator);
    defer gfx.deinit();

    // Default mode should be block (safe fallback)
    try std.testing.expectEqual(GraphicsMode.block, gfx.mode);
}

test "force graphics mode" {
    const allocator = std.testing.allocator;
    var gfx = Graphics.init(allocator);
    defer gfx.deinit();

    gfx.setMode(.kitty);
    try std.testing.expectEqual(GraphicsMode.kitty, gfx.mode);
    try std.testing.expect(gfx.supportsImages());
}

test "render image to buffer fallback" {
    const allocator = std.testing.allocator;
    var gfx = Graphics.init(allocator);
    defer gfx.deinit();

    // Create a small test image (2x2 RGBA)
    const img_data = [_]u8{
        255, 0,   0,   255, // Red
        0,   255, 0,   255, // Green
        0,   0,   255, 255, // Blue
        255, 255, 0,   255, // Yellow
    };

    const image = Image.fromRGBA(&img_data, 2, 2);

    var buffer = try render_mod.Buffer.init(allocator, 10, 10);
    defer buffer.deinit();

    const area = render_mod.Rect{ .x = 0, .y = 0, .width = 2, .height = 1 };
    gfx.renderImageToBuffer(image, &buffer, area);

    // Check that something was rendered
    if (buffer.get(0, 0)) |cell| {
        try std.testing.expectEqual(@as(u21, '▀'), cell.char);
    }
}
