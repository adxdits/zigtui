const std = @import("std");
const Allocator = std.mem.Allocator;
const backend = @import("../backend/mod.zig");
const render = @import("../render/mod.zig");

const base64_encoder = std.base64.standard.Encoder;

pub const MAX_CHUNK_SIZE: usize = 4096;

pub const Format = enum(u8) {
    rgba = 32, // 32-bit RGBA
    rgb = 24, // 24-bit RGB
    png = 100, // PNG compressed

    pub fn toCode(self: Format) u8 {
        return @intFromEnum(self);
    }
};

pub const Placement = struct {
    x: ?u16 = null,
    y: ?u16 = null,
    width: ?u16 = null,
    height: ?u16 = null,
    z_index: i32 = 0,
    image_id: ?u32 = null,
    placement_id: ?u32 = null,
    move_cursor: bool = false,
};

pub const Action = enum(u8) {
    transmit = 't', // Transmit image data
    transmit_and_display = 'T', // Transmit and display immediately
    query = 'q', // Query terminal support
    placement = 'p', // Place a previously transmitted image
    delete = 'd', // Delete image(s)
    animation_frame = 'f', // Animation frame
    animation_control = 'a', // Animation control
};

pub const DeleteTarget = enum {
    all, // Delete all images
    by_id, // Delete by image ID
    by_placement, // Delete by placement ID
    at_cursor, // Delete at cursor position
    in_range, // Delete in cell range
};

pub const Capability = struct {
    supported: bool = false,
    responded: bool = false,
    error_msg: ?[]const u8 = null,
};

pub const Image = struct {
    data: []const u8,
    width: u32,
    height: u32,
    format: Format,
    stride: u32,

    pub fn fromRGBA(data: []const u8, width: u32, height: u32) Image {
        return .{
            .data = data,
            .width = width,
            .height = height,
            .format = .rgba,
            .stride = 4,
        };
    }

    pub fn fromRGB(data: []const u8, width: u32, height: u32) Image {
        return .{
            .data = data,
            .width = width,
            .height = height,
            .format = .rgb,
            .stride = 3,
        };
    }

    pub fn fromPNG(data: []const u8) Image {
        return .{
            .data = data,
            .width = 0, // Will be determined by terminal
            .height = 0,
            .format = .png,
            .stride = 0,
        };
    }
};

pub const KittyGraphics = struct {
    allocator: Allocator,
    supported: bool = false,
    detected: bool = false,
    output_buffer: std.ArrayListUnmanaged(u8) = .empty,
    next_image_id: u32 = 1,

    pub fn init(allocator: Allocator) KittyGraphics {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *KittyGraphics) void {
        self.output_buffer.deinit(self.allocator);
    }

    // ── Helpers for building escape sequences ────────────────────────

    fn appendParam(self: *KittyGraphics, key: []const u8, value: anytype) !void {
        const alloc = self.allocator;
        try self.output_buffer.appendSlice(alloc, key);
        var buf: [20]u8 = undefined;
        const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
        try self.output_buffer.appendSlice(alloc, str);
    }

    fn appendOptParam(self: *KittyGraphics, key: []const u8, maybe: anytype) !void {
        if (maybe) |v| try self.appendParam(key, v);
    }

    fn writeChunkedData(
        self: *KittyGraphics,
        data: []const u8,
        params: struct {
            a: Action = .transmit_and_display,
            f: Format = .rgba,
            s: ?u32 = null, // width
            v: ?u32 = null, // height
            i: ?u32 = null, // image id
            p: ?u32 = null, // placement id
            x: ?u16 = null, // x position
            y: ?u16 = null, // y position
            c: ?u16 = null, // columns
            r: ?u16 = null, // rows
            z: ?i32 = null, // z-index
            C: ?u8 = null, // do not move cursor (1)
        },
    ) !void {
        const alloc = self.allocator;

        // Calculate base64 encoded size
        const encoded_len = base64_encoder.calcSize(data.len);

        // Allocate buffer for base64 encoding
        const encoded = try alloc.alloc(u8, encoded_len);
        defer alloc.free(encoded);

        // Encode to base64
        _ = base64_encoder.encode(encoded, data);

        var offset: usize = 0;
        var is_first = true;

        while (offset < encoded.len) {
            const remaining = encoded.len - offset;
            const chunk_size = @min(remaining, MAX_CHUNK_SIZE);
            const is_last = (offset + chunk_size >= encoded.len);

            // Start escape sequence
            try self.output_buffer.appendSlice(alloc, "\x1b_G");

            // Write parameters on first chunk
            if (is_first) {
                try self.output_buffer.append(alloc, 'a');
                try self.output_buffer.append(alloc, '=');
                try self.output_buffer.append(alloc, @intFromEnum(params.a));

                try self.appendParam(",f=", params.f.toCode());
                try self.appendOptParam(",s=", params.s);
                try self.appendOptParam(",v=", params.v);
                try self.appendOptParam(",i=", params.i);
                try self.appendOptParam(",p=", params.p);
                try self.appendOptParam(",x=", params.x);
                try self.appendOptParam(",y=", params.y);
                try self.appendOptParam(",c=", params.c);
                try self.appendOptParam(",r=", params.r);
                try self.appendOptParam(",z=", params.z);
                try self.appendOptParam(",C=", params.C);

                is_first = false;
            }

            // More data indicator
            try self.output_buffer.appendSlice(alloc, ",m=");
            try self.output_buffer.append(alloc, if (is_last) '0' else '1');

            // Data separator and payload
            try self.output_buffer.append(alloc, ';');
            try self.output_buffer.appendSlice(alloc, encoded[offset .. offset + chunk_size]);

            // End escape sequence
            try self.output_buffer.appendSlice(alloc, "\x1b\\");

            offset += chunk_size;
        }
    }

    pub fn drawImage(
        self: *KittyGraphics,
        image: Image,
        placement: Placement,
    ) ![]const u8 {
        self.output_buffer.clearRetainingCapacity();

        const image_id = placement.image_id orelse blk: {
            const id = self.next_image_id;
            self.next_image_id += 1;
            break :blk id;
        };

        try self.writeChunkedData(image.data, .{
            .a = .transmit_and_display,
            .f = image.format,
            .s = if (image.format != .png) image.width else null,
            .v = if (image.format != .png) image.height else null,
            .i = image_id,
            .p = placement.placement_id,
            .x = placement.x,
            .y = placement.y,
            .c = placement.width,
            .r = placement.height,
            .z = if (placement.z_index != 0) placement.z_index else null,
            .C = if (!placement.move_cursor) 1 else null,
        });

        return self.output_buffer.items;
    }

    pub fn transmitImage(
        self: *KittyGraphics,
        image: Image,
        image_id: u32,
    ) ![]const u8 {
        self.output_buffer.clearRetainingCapacity();

        try self.writeChunkedData(image.data, .{
            .a = .transmit,
            .f = image.format,
            .s = if (image.format != .png) image.width else null,
            .v = if (image.format != .png) image.height else null,
            .i = image_id,
            .p = null,
            .x = null,
            .y = null,
            .c = null,
            .r = null,
            .z = null,
            .C = null,
        });

        return self.output_buffer.items;
    }

    pub fn placeImage(
        self: *KittyGraphics,
        image_id: u32,
        placement: Placement,
    ) ![]const u8 {
        const alloc = self.allocator;
        self.output_buffer.clearRetainingCapacity();

        try self.output_buffer.appendSlice(alloc, "\x1b_Ga=p");
        try self.appendParam(",i=", image_id);
        try self.appendOptParam(",p=", placement.placement_id);
        try self.appendOptParam(",x=", placement.x);
        try self.appendOptParam(",y=", placement.y);
        try self.appendOptParam(",c=", placement.width);
        try self.appendOptParam(",r=", placement.height);
        if (placement.z_index != 0) {
            try self.appendParam(",z=", placement.z_index);
        }
        if (!placement.move_cursor) {
            try self.output_buffer.appendSlice(alloc, ",C=1");
        }

        try self.output_buffer.appendSlice(alloc, "\x1b\\");

        return self.output_buffer.items;
    }

    pub fn deleteImages(
        self: *KittyGraphics,
        target: DeleteTarget,
        id: ?u32,
    ) ![]const u8 {
        const alloc = self.allocator;
        self.output_buffer.clearRetainingCapacity();

        try self.output_buffer.appendSlice(alloc, "\x1b_Ga=d");

        switch (target) {
            .all => try self.output_buffer.appendSlice(alloc, ",d=A"),
            .by_id => {
                try self.output_buffer.appendSlice(alloc, ",d=I");
                try self.appendOptParam(",i=", id);
            },
            .by_placement => {
                try self.output_buffer.appendSlice(alloc, ",d=P");
                try self.appendOptParam(",p=", id);
            },
            .at_cursor => try self.output_buffer.appendSlice(alloc, ",d=C"),
            .in_range => try self.output_buffer.appendSlice(alloc, ",d=R"),
        }

        try self.output_buffer.appendSlice(alloc, "\x1b\\");

        return self.output_buffer.items;
    }

    pub fn querySupport(self: *KittyGraphics) ![]const u8 {
        self.output_buffer.clearRetainingCapacity();
        // Query with a minimal 1x1 transparent pixel
        // The terminal will respond with OK or an error
        try self.output_buffer.appendSlice(self.allocator, "\x1b_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\x1b\\");
        return self.output_buffer.items;
    }

    pub fn parseQueryResponse(response: []const u8) Capability {
        // Look for Kitty graphics response pattern: \x1b_Gi=31;OK\x1b\
        // or error response: \x1b_Gi=31;error message\x1b\
        var cap = Capability{};

        if (std.mem.indexOf(u8, response, "\x1b_G")) |start| {
            cap.responded = true;
            const after_header = response[start + 3 ..];

            if (std.mem.indexOf(u8, after_header, ";OK")) |_| {
                cap.supported = true;
            } else if (std.mem.indexOf(u8, after_header, ";")) |semi| {
                // Extract error message
                if (std.mem.indexOf(u8, after_header[semi + 1 ..], "\x1b\\")) |end| {
                    cap.error_msg = after_header[semi + 1 .. semi + 1 + end];
                }
            }
        }

        return cap;
    }

    pub fn generateTestPattern(self: *KittyGraphics) !Image {
        const size: u32 = 8;
        const data = try self.allocator.alloc(u8, size * size * 4);

        for (0..size) |y| {
            for (0..size) |x| {
                const offset = (y * size + x) * 4;
                const is_white = ((x + y) % 2) == 0;
                const color: u8 = if (is_white) 255 else 0;
                data[offset] = color; // R
                data[offset + 1] = color; // G
                data[offset + 2] = color; // B
                data[offset + 3] = 255; // A
            }
        }

        return Image{
            .data = data,
            .width = size,
            .height = size,
            .format = .rgba,
            .stride = 4,
        };
    }

    pub fn freeImageData(self: *KittyGraphics, image: Image) void {
        self.allocator.free(image.data);
    }
};

pub fn createSolidImage(allocator: Allocator, width: u32, height: u32, r: u8, g: u8, b: u8, a: u8) !Image {
    const data = try allocator.alloc(u8, @as(usize, width) * @as(usize, height) * 4);

    var i: usize = 0;
    while (i < data.len) : (i += 4) {
        data[i] = r;
        data[i + 1] = g;
        data[i + 2] = b;
        data[i + 3] = a;
    }

    return Image{
        .data = data,
        .width = width,
        .height = height,
        .format = .rgba,
        .stride = 4,
    };
}

pub fn freeImage(allocator: Allocator, image: Image) void {
    allocator.free(image.data);
}

test "base64 encoding" {
    const allocator = std.testing.allocator;
    var kg = KittyGraphics.init(allocator);
    defer kg.deinit();

    const test_data = [_]u8{ 0xFF, 0x00, 0xFF, 0xFF };
    const encoded_len = base64_encoder.calcSize(test_data.len);
    const encoded = try allocator.alloc(u8, encoded_len);
    defer allocator.free(encoded);

    _ = base64_encoder.encode(encoded, &test_data);
    try std.testing.expectEqualStrings("/wD//w==", encoded);
}

test "query support escape sequence" {
    const allocator = std.testing.allocator;
    var kg = KittyGraphics.init(allocator);
    defer kg.deinit();

    const query = try kg.querySupport();
    try std.testing.expect(std.mem.startsWith(u8, query, "\x1b_G"));
    try std.testing.expect(std.mem.endsWith(u8, query, "\x1b\\"));
}

test "parse query response" {
    const ok_response = "\x1b_Gi=31;OK\x1b\\";
    const cap = KittyGraphics.parseQueryResponse(ok_response);
    try std.testing.expect(cap.responded);
    try std.testing.expect(cap.supported);

    const error_response = "\x1b_Gi=31;ENOTSUPPORTED\x1b\\";
    const cap2 = KittyGraphics.parseQueryResponse(error_response);
    try std.testing.expect(cap2.responded);
    try std.testing.expect(!cap2.supported);
}
