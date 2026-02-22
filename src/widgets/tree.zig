const std = @import("std");
const render = @import("../render/mod.zig");
const style = @import("../style/mod.zig");
const Rect = render.Rect;
const Buffer = render.Buffer;
const Style = style.Style;

/// A single node in the tree.  Nodes without children are always leaf nodes;
/// the `expanded` field is ignored for them.
pub const TreeNode = struct {
    label: []const u8,
    children: []const TreeNode = &.{},
    expanded: bool = false,
    style: Style = .{},

    pub fn isLeaf(self: TreeNode) bool {
        return self.children.len == 0;
    }
};

pub const Tree = struct {
    roots: []const TreeNode,
    selected: ?usize = null,
    style: Style = .{},
    highlight_style: Style = .{},
    highlight_symbol: []const u8 = "> ",
    /// Indentation per depth level, in cells.
    indent: u16 = 2,
    /// Prefix for expanded nodes.
    expanded_symbol: []const u8 = "▼ ",
    /// Prefix for collapsed nodes.
    collapsed_symbol: []const u8 = "▶ ",
    /// Prefix for leaf nodes.
    leaf_symbol: []const u8 = "  ",

    pub fn render(self: Tree, area: Rect, buf: *Buffer) void {
        if (area.width == 0 or area.height == 0) return;

        var row: u16 = 0;
        var flat_idx: usize = 0;
        self.renderNodes(self.roots, 0, area, buf, &row, &flat_idx);
    }

    fn renderNodes(
        self: Tree,
        nodes: []const TreeNode,
        depth: u16,
        area: Rect,
        buf: *Buffer,
        row: *u16,
        flat_idx: *usize,
    ) void {
        for (nodes) |node| {
            if (row.* >= area.height) return;

            const y = area.y + row.*;
            const is_selected = if (self.selected) |sel| sel == flat_idx.* else false;
            const row_style = if (is_selected)
                self.style.merge(node.style).merge(self.highlight_style)
            else
                self.style.merge(node.style);

            // Clear row background
            {
                var fx: u16 = area.x;
                while (fx < area.x + area.width) : (fx += 1) {
                    buf.setChar(fx, y, ' ', row_style);
                }
            }

            var x: u16 = area.x;

            // Indent
            const indent_cells = depth * self.indent;
            x += indent_cells;
            if (x >= area.x + area.width) {
                row.* += 1;
                flat_idx.* += 1;
                continue;
            }

            // Highlight symbol
            const sym_width: u16 = blk: {
                var count: u16 = 0;
                var iter = std.unicode.Utf8View.initUnchecked(self.highlight_symbol).iterator();
                while (iter.nextCodepoint()) |_| count += 1;
                break :blk count;
            };
            if (is_selected and x + sym_width <= area.x + area.width) {
                buf.setString(x, y, self.highlight_symbol, row_style);
            }
            x += sym_width;

            // Node kind symbol
            const kind_sym = if (node.isLeaf())
                self.leaf_symbol
            else if (node.expanded)
                self.expanded_symbol
            else
                self.collapsed_symbol;

            const kind_width: u16 = blk: {
                var count: u16 = 0;
                var iter = std.unicode.Utf8View.initUnchecked(kind_sym).iterator();
                while (iter.nextCodepoint()) |_| count += 1;
                break :blk count;
            };
            if (x + kind_width <= area.x + area.width) {
                buf.setString(x, y, kind_sym, row_style);
            }
            x += kind_width;

            // Label
            if (x < area.x + area.width) {
                const available = area.x + area.width - x;
                buf.setStringTruncated(x, y, node.label, available, row_style);
            }

            row.* += 1;
            flat_idx.* += 1;

            // Recurse into children if expanded
            if (!node.isLeaf() and node.expanded) {
                self.renderNodes(node.children, depth + 1, area, buf, row, flat_idx);
            }
        }
    }

    /// Count of currently visible rows (expanded nodes and all their visible children).
    pub fn visibleCount(self: Tree) usize {
        return countVisible(self.roots);
    }

    pub fn selectNext(self: *Tree) void {
        const total = self.visibleCount();
        if (total == 0) return;
        if (self.selected) |sel| {
            if (sel + 1 < total) self.selected = sel + 1;
        } else {
            self.selected = 0;
        }
    }

    pub fn selectPrevious(self: *Tree) void {
        if (self.selected) |sel| {
            if (sel > 0) {
                self.selected = sel - 1;
            }
        } else {
            const total = self.visibleCount();
            if (total > 0) self.selected = total - 1;
        }
    }

    pub fn toggleSelectedNode(self: *Tree, mutable_roots: []TreeNode) void {
        if (self.selected) |sel| {
            _ = toggleAtIndex(mutable_roots, sel, 0);
        }
    }
};

fn countVisible(nodes: []const TreeNode) usize {
    var count: usize = 0;
    for (nodes) |node| {
        count += 1;
        if (!node.isLeaf() and node.expanded) {
            count += countVisible(node.children);
        }
    }
    return count;
}

fn toggleAtIndex(nodes: []TreeNode, target: usize, current: usize) usize {
    var idx = current;
    for (nodes) |*node| {
        if (idx == target) {
            node.expanded = !node.expanded;
            return idx + 1; // sentinel "found"
        }
        idx += 1;
        if (!node.isLeaf() and node.expanded) {
            const result = toggleAtIndex(node.children, target, idx);
            if (result != idx + countVisible(node.children)) return result; // found inside
            idx += countVisible(node.children);
        }
    }
    return idx;
}

test "Tree visibleCount respects expanded" {
    const leaf1 = TreeNode{ .label = "a.zig" };
    const leaf2 = TreeNode{ .label = "b.zig" };
    const dir = TreeNode{ .label = "src", .children = &.{ leaf1, leaf2 }, .expanded = false };
    const t = Tree{ .roots = &.{dir} };
    try std.testing.expectEqual(@as(usize, 1), t.visibleCount()); // collapsed

    const dir_open = TreeNode{ .label = "src", .children = &.{ leaf1, leaf2 }, .expanded = true };
    const t2 = Tree{ .roots = &.{dir_open} };
    try std.testing.expectEqual(@as(usize, 3), t2.visibleCount());
}
