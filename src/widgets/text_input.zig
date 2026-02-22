const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

pub fn TextInput(comptime max_bytes: usize) type {
    return struct {
        const Self = @This();

        buf: [max_bytes]u8 = undefined,
        /// Number of valid bytes currently stored.
        len: usize = 0,
        /// Byte offset of the cursor (always on a codepoint boundary).
        cursor: usize = 0,
        focused: bool = true,
        style: Style = .{},
        cursor_style: Style = .{},
        placeholder: []const u8 = "",
        placeholder_style: Style = .{},


        /// Return the current text as a slice.
        pub fn value(self: *const Self) []const u8 {
            return self.buf[0..self.len];
        }

        /// Clear all content and reset cursor.
        pub fn clear(self: *Self) void {
            self.len = 0;
            self.cursor = 0;
        }

        /// Insert a Unicode codepoint at the cursor position.
        pub fn insertCodepoint(self: *Self, cp: u21) void {
            var enc: [4]u8 = undefined;
            const cp_len = std.unicode.utf8Encode(cp, &enc) catch return;
            self.insertBytes(enc[0..cp_len]);
        }

        /// Insert raw bytes (must be valid UTF-8) at the cursor.
        pub fn insertBytes(self: *Self, bytes: []const u8) void {
            if (self.len + bytes.len > max_bytes) return;
            // Shift existing content right to make room
            if (self.cursor < self.len) {
                std.mem.copyBackwards(
                    u8,
                    self.buf[self.cursor + bytes.len .. self.len + bytes.len],
                    self.buf[self.cursor..self.len],
                );
            }
            @memcpy(self.buf[self.cursor .. self.cursor + bytes.len], bytes);
            self.len += bytes.len;
            self.cursor += bytes.len;
        }

        /// Delete the codepoint immediately before the cursor (backspace).
        pub fn deleteBackward(self: *Self) void {
            if (self.cursor == 0) return;
            const cp_len = self.prevCodepointLen();
            const new_cursor = self.cursor - cp_len;
            std.mem.copyForwards(u8, self.buf[new_cursor .. self.len - cp_len], self.buf[self.cursor..self.len]);
            self.len -= cp_len;
            self.cursor = new_cursor;
        }

        /// Delete the codepoint immediately after the cursor (delete key).
        pub fn deleteForward(self: *Self) void {
            if (self.cursor >= self.len) return;
            const cp_len = self.nextCodepointLen();
            std.mem.copyForwards(u8, self.buf[self.cursor .. self.len - cp_len], self.buf[self.cursor + cp_len .. self.len]);
            self.len -= cp_len;
        }

        pub fn moveCursorLeft(self: *Self) void {
            if (self.cursor == 0) return;
            self.cursor -= self.prevCodepointLen();
        }

        pub fn moveCursorRight(self: *Self) void {
            if (self.cursor >= self.len) return;
            self.cursor += self.nextCodepointLen();
        }

        pub fn moveCursorHome(self: *Self) void {
            self.cursor = 0;
        }

        pub fn moveCursorEnd(self: *Self) void {
            self.cursor = self.len;
        }

        pub fn render(self: *const Self, area: Rect, buf: *Buffer) void {
            if (area.width == 0 or area.height == 0) return;

            const text = self.value();

            if (text.len == 0 and self.placeholder.len > 0 and !self.focused) {
                buf.setStringTruncated(area.x, area.y, self.placeholder, area.width, self.placeholder_style);
                return;
            }

            // Determine visible window (scroll so cursor is on screen)
            // We work in codepoints for display width simplicity.
            var cp_count: u16 = 0;
            {
                var iter = std.unicode.Utf8View.initUnchecked(text).iterator();
                while (iter.nextCodepoint()) |_| cp_count += 1;
            }

            // cursor codepoint index
            var cursor_cp: u16 = 0;
            {
                var byte_pos: usize = 0;
                var iter = std.unicode.Utf8View.initUnchecked(text).iterator();
                while (iter.nextCodepoint()) |_| : (byte_pos += 1) {
                    if (byte_pos >= self.cursor) break;
                    cursor_cp += 1;
                    byte_pos += 0; // already advanced by iterator; need exact byte tracking
                }
            }
            // Simpler: count codepoints up to cursor byte offset
            cursor_cp = 0;
            {
                var byte_pos: usize = 0;
                var iter = std.unicode.Utf8View.initUnchecked(text).iterator();
                while (byte_pos < self.cursor) {
                    if (iter.nextCodepoint()) |cp_val| {
                        _ = cp_val;
                        cursor_cp += 1;
                        byte_pos = @intCast(iter.i);
                    } else break;
                }
            }

            // Scroll: show a window of `area.width` codepoints ending past cursor
            const scroll: u16 = if (cursor_cp >= area.width) cursor_cp - area.width + 1 else 0;

            var x: u16 = area.x;
            var cp_idx: u16 = 0;
            var byte_pos: usize = 0;
            var iter = std.unicode.Utf8View.initUnchecked(text).iterator();

            while (iter.nextCodepoint()) |cp_val| {
                const cp_byte_start = byte_pos;
                byte_pos = @intCast(iter.i);
                _ = cp_byte_start;

                if (cp_idx < scroll) {
                    cp_idx += 1;
                    continue;
                }
                if (x >= area.x + area.width) break;

                const is_cursor = self.focused and (cp_idx == cursor_cp);
                const cell_style = if (is_cursor) self.style.merge(self.cursor_style) else self.style;
                buf.setChar(x, area.y, cp_val, cell_style);
                x += 1;
                cp_idx += 1;
            }

            // Draw cursor at end-of-text position
            if (self.focused and x < area.x + area.width and cursor_cp == cp_count) {
                buf.setChar(x, area.y, ' ', self.style.merge(self.cursor_style));
                x += 1;
            }

            // Fill remainder with background style
            while (x < area.x + area.width) : (x += 1) {
                buf.setChar(x, area.y, ' ', self.style);
            }
        }

        // ── Private helpers ───────────────────────────────────────────────────

        fn prevCodepointLen(self: *const Self) usize {
            // Walk backwards to find the start of the previous codepoint.
            var i = self.cursor;
            while (i > 0) {
                i -= 1;
                if (self.buf[i] & 0xC0 != 0x80) break; // not a continuation byte
            }
            return self.cursor - i;
        }

        fn nextCodepointLen(self: *const Self) usize {
            if (self.cursor >= self.len) return 0;
            const seq_len = std.unicode.utf8ByteSequenceLength(self.buf[self.cursor]) catch return 1;
            return @min(seq_len, self.len - self.cursor);
        }
    };
}

test "TextInput insert and delete" {
    var input = TextInput(64){};
    input.insertCodepoint('H');
    input.insertCodepoint('i');
    try std.testing.expectEqualStrings("Hi", input.value());

    input.deleteBackward();
    try std.testing.expectEqualStrings("H", input.value());
}

test "TextInput cursor movement" {
    var input = TextInput(64){};
    input.insertCodepoint('A');
    input.insertCodepoint('B');
    input.insertCodepoint('C');
    input.moveCursorHome();
    try std.testing.expectEqual(@as(usize, 0), input.cursor);
    input.moveCursorEnd();
    try std.testing.expectEqual(@as(usize, 3), input.cursor);
    input.moveCursorLeft();
    try std.testing.expectEqual(@as(usize, 2), input.cursor);
}

test "TextInput insert in middle" {
    var input = TextInput(64){};
    input.insertCodepoint('A');
    input.insertCodepoint('C');
    input.moveCursorLeft();
    input.insertCodepoint('B');
    try std.testing.expectEqualStrings("ABC", input.value());
}
