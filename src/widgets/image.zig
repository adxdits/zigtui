const render = @import("../render/mod.zig");
const graphics = @import("../graphics/mod.zig");
const Image = graphics.Image;
const Placement = graphics.Placement;
const Graphics = graphics.Graphics;

pub const ImageWidget = struct {
    image: ?Image = null,
    placement: Placement = .{},
    fallback_text: []const u8 = "[Image]",

    pub fn setImage(self: *ImageWidget, image: Image) void {
        self.image = image;
    }

    pub fn setPlacement(self: *ImageWidget, placement: Placement) void {
        self.placement = placement;
    }

    pub fn draw(
        self: ImageWidget,
        gfx: *Graphics,
        buffer: *render.Buffer,
        area: render.Rect,
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
            Graphics.renderPlaceholder(buffer, area, self.fallback_text);
            return null;
        }
    }
};
