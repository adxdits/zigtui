---
id: tree
title: Tree
---

# Tree

Hierarchical, collapsible list. Selection is a flat visible-row index.

:::caution Memory safety
If `TreeNode` children slices point into fields of your state struct, build the tree **after** the state variable is in its final stack slot not inside an `init()` function that returns by value. See `examples/widgets_demo.zig` for the correct pattern.
:::

## Usage

```zig
// Declare child arrays as fields of your state struct
var src_children = [_]tui.widgets.TreeNode{
    .{ .label = "main.zig" },
    .{ .label = "lib.zig" },
};
var root_nodes = [_]tui.widgets.TreeNode{
    .{ .label = "src/", .children = &src_children, .expanded = true },
    .{ .label = "build.zig" },
};

var tree = tui.widgets.Tree{
    .roots            = &root_nodes,
    .selected         = 0,
    .highlight_style  = .{ .fg = .black, .bg = .cyan },
    .indent           = 2,
    .expanded_symbol  = "▼ ",
    .collapsed_symbol = "▶ ",
    .leaf_symbol      = "  ",
};
tree.render(area, buf);
```

## Navigation

```zig
tree.selectNext();
tree.selectPrevious();

// Toggle the expanded state of the selected node
tree.toggleSelectedNode(&root_nodes);

// Number of currently visible rows (for scroll logic)
const visible: usize = tree.visibleCount();
```
