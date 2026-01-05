//! Simple BMP image decoder
//! Supports 24-bit and 32-bit uncompressed BMP files

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const BmpError = error{
    InvalidSignature,
    UnsupportedFormat,
    InvalidHeader,
    FileTooSmall,
    OutOfMemory,
};

/// Decoded BMP image
pub const BmpImage = struct {
    data: []u8,
    width: u32,
    height: u32,
    allocator: Allocator,

    pub fn deinit(self: *BmpImage) void {
        self.allocator.free(self.data);
    }
};

/// Decode a BMP file from raw bytes
/// Returns RGBA pixel data (top-to-bottom, left-to-right)
pub fn decode(allocator: Allocator, file_data: []const u8) !BmpImage {
    if (file_data.len < 54) {
        return BmpError.FileTooSmall;
    }

    // Check BMP signature "BM"
    if (file_data[0] != 'B' or file_data[1] != 'M') {
        return BmpError.InvalidSignature;
    }

    // Parse header
    const data_offset = std.mem.readInt(u32, file_data[10..14], .little);
    const header_size = std.mem.readInt(u32, file_data[14..18], .little);

    if (header_size < 40) {
        return BmpError.UnsupportedFormat; // Need BITMAPINFOHEADER or later
    }

    const width_i32 = std.mem.readInt(i32, file_data[18..22], .little);
    const height_i32 = std.mem.readInt(i32, file_data[22..26], .little);
    const bits_per_pixel = std.mem.readInt(u16, file_data[28..30], .little);
    const compression = std.mem.readInt(u32, file_data[30..34], .little);

    // Only support uncompressed (0) or BI_BITFIELDS (3) for 32-bit
    if (compression != 0 and compression != 3) {
        return BmpError.UnsupportedFormat;
    }

    // Only support 24-bit or 32-bit
    if (bits_per_pixel != 24 and bits_per_pixel != 32) {
        return BmpError.UnsupportedFormat;
    }

    const width: u32 = @intCast(@abs(width_i32));
    const height: u32 = @intCast(@abs(height_i32));
    const flip_vertical = height_i32 > 0; // Positive height means bottom-up

    // Calculate row stride (rows are padded to 4-byte boundaries)
    const bytes_per_pixel: u32 = @as(u32, bits_per_pixel) / 8;
    const row_size = ((width * bytes_per_pixel + 3) / 4) * 4;

    // Allocate output RGBA buffer
    const output_size = @as(usize, width) * @as(usize, height) * 4;
    const output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);

    // Decode pixels
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        const src_y = if (flip_vertical) height - 1 - y else y;
        const src_row_start = data_offset + src_y * row_size;

        if (src_row_start + width * bytes_per_pixel > file_data.len) {
            return BmpError.InvalidHeader;
        }

        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const src_offset = src_row_start + x * bytes_per_pixel;
            const dst_offset = (@as(usize, y) * @as(usize, width) + @as(usize, x)) * 4;

            // BMP stores as BGR(A)
            const b = file_data[src_offset];
            const g = file_data[src_offset + 1];
            const r = file_data[src_offset + 2];
            const a: u8 = if (bits_per_pixel == 32) file_data[src_offset + 3] else 255;

            // Output as RGBA
            output[dst_offset] = r;
            output[dst_offset + 1] = g;
            output[dst_offset + 2] = b;
            output[dst_offset + 3] = a;
        }
    }

    return BmpImage{
        .data = output,
        .width = width,
        .height = height,
        .allocator = allocator,
    };
}

/// Load and decode a BMP file from disk
pub fn loadFile(allocator: Allocator, path: []const u8) !BmpImage {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const file_data = try allocator.alloc(u8, stat.size);
    defer allocator.free(file_data);

    const bytes_read = try file.readAll(file_data);
    if (bytes_read != stat.size) {
        return BmpError.FileTooSmall;
    }

    return decode(allocator, file_data);
}

test "bmp header parsing" {
    // Minimal invalid BMP
    const invalid = [_]u8{ 'X', 'Y' } ++ [_]u8{0} ** 52;
    try std.testing.expectError(BmpError.InvalidSignature, decode(std.testing.allocator, &invalid));
}
