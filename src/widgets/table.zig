const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

pub const Row = struct {
    cells: []const []const u8,
    style: Style = .{},
    height: u16 = 1,
};

pub const Column = struct {
    header: []const u8,
    width: ?u16 = null, // null = auto-calculate
};

pub const Table = struct {
    columns: []const Column,
    rows: []const Row,
    header_style: Style = .{},
    selected_style: Style = .{},
    selected: ?usize = null,
    column_spacing: u16 = 1,
    offset: usize = 0,

    pub fn render(self: Table, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0 or self.columns.len == 0) return;

        var y: u16 = area.y;

        // Calculate column widths
        var widths: std.ArrayListUnmanaged(u16) = .empty;
        defer widths.deinit(buf.allocator);

        for (self.columns) |col| {
            if (col.width) |w| {
                widths.append(buf.allocator, w) catch return;
            } else {
                // Calculate based on header
                var max_width: u16 = @intCast(@min(col.header.len, std.math.maxInt(u16)));
                // Check all rows
                for (self.rows) |row| {
                    if (widths.items.len < row.cells.len) {
                        const cell = row.cells[widths.items.len];
                        const cell_width: u16 = @intCast(@min(cell.len, std.math.maxInt(u16)));
                        max_width = @max(max_width, cell_width);
                    }
                }
                widths.append(buf.allocator, max_width) catch return;
            }
        }

        // Draw headers
        if (y < area.y + area.height) {
            var x: u16 = area.x;
            for (self.columns, 0..) |col, i| {
                if (i >= widths.items.len) break;
                if (x >= area.x + area.width) break;

                const width = widths.items[i];
                const available = if (x + width > area.x + area.width)
                    area.x + area.width - x
                else
                    width;

                buf.setStringTruncated(x, y, col.header, available, self.header_style);
                x += width + self.column_spacing;
            }
            y += 1;
        }

        // Draw rows
        var row_idx = self.offset;
        while (row_idx < self.rows.len and y < area.y + area.height) : (row_idx += 1) {
            const row = self.rows[row_idx];
            const is_selected = if (self.selected) |sel| sel == row_idx else false;
            const row_style = if (is_selected) self.selected_style else row.style;

            var x: u16 = area.x;
            for (row.cells, 0..) |cell, i| {
                if (i >= widths.items.len) break;
                if (x >= area.x + area.width) break;

                const width = widths.items[i];
                const available = if (x + width > area.x + area.width)
                    area.x + area.width - x
                else
                    width;

                buf.setStringTruncated(x, y, cell, available, row_style);
                x += width + self.column_spacing;
            }

            y += row.height;
        }
    }

    pub fn selectNext(self: *Table) void {
        if (self.rows.len == 0) return;

        if (self.selected) |sel| {
            if (sel < self.rows.len - 1) {
                self.selected = sel + 1;
            }
        } else {
            self.selected = 0;
        }

        self.scrollToSelected();
    }

    pub fn selectPrevious(self: *Table) void {
        if (self.rows.len == 0) return;

        if (self.selected) |sel| {
            if (sel > 0) {
                self.selected = sel - 1;
            }
        } else if (self.rows.len > 0) {
            self.selected = self.rows.len - 1;
        }

        self.scrollToSelected();
    }

    fn scrollToSelected(self: *Table) void {
        if (self.selected) |sel| {
            if (sel < self.offset) {
                self.offset = sel;
            }
        }
    }
};

pub const TableBuilder = struct {
    allocator: std.mem.Allocator,
    columns: std.ArrayList(Column),
    rows: std.ArrayList(Row),
    header_style: Style = .{},
    selected_style: Style = .{},

    pub fn init(allocator: std.mem.Allocator) TableBuilder {
        return .{
            .allocator = allocator,
            .columns = std.ArrayList(Column).init(allocator),
            .rows = std.ArrayList(Row).init(allocator),
        };
    }

    pub fn deinit(self: *TableBuilder) void {
        self.columns.deinit();
        self.rows.deinit();
    }

    pub fn addColumn(self: *TableBuilder, header: []const u8, width: ?u16) !*TableBuilder {
        try self.columns.append(.{ .header = header, .width = width });
        return self;
    }

    pub fn addRow(self: *TableBuilder, cells: []const []const u8) !*TableBuilder {
        try self.rows.append(.{ .cells = cells });
        return self;
    }

    pub fn build(self: *TableBuilder) Table {
        return .{
            .columns = self.columns.items,
            .rows = self.rows.items,
            .header_style = self.header_style,
            .selected_style = self.selected_style,
        };
    }
};
