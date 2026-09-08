const std = @import("std");

pub const backend = @import("backend/mod.zig");
pub const terminal = @import("terminal/mod.zig");
pub const render = @import("render/mod.zig");
pub const layout = @import("layout/mod.zig");
pub const widgets = @import("widgets/mod.zig");
pub const style = @import("style/mod.zig");
pub const events = @import("events/mod.zig");
pub const graphics = @import("graphics/mod.zig");

pub const Terminal = terminal.Terminal;
pub const Buffer = render.Buffer;
pub const Cell = render.Cell;
pub const Rect = render.Rect;
pub const Size = render.Size;

pub const codepointWidth = render.codepointWidth;
pub const stringWidth = render.stringWidth;
pub const truncateToWidth = render.truncateToWidth;

pub const restore = terminal.restore;

/// Panic handler that puts the terminal back before printing the trace. Opt in
/// from your root source file with `pub const panic = zigtui.panic;`. Signal
/// handlers are installed for you when raw mode is entered.
pub const panic = terminal.restore.Panic;

pub const Color = style.Color;
pub const Style = style.Style;
pub const Modifier = style.Modifier;
pub const Theme = style.Theme;
pub const themes = style.themes;

pub const Event = events.Event;
pub const KeyEvent = events.KeyEvent;
pub const KeyCode = events.KeyCode;
pub const KeyModifiers = events.KeyModifiers;
pub const MouseEvent = events.MouseEvent;

pub const Backend = backend.Backend;
pub const NativeBackend = backend.NativeBackend;

pub const Layout = layout.Layout;
pub const Constraint = layout.Constraint;

pub const Block = widgets.Block;
pub const Borders = widgets.Borders;
pub const BorderSymbols = widgets.BorderSymbols;
pub const Paragraph = widgets.Paragraph;
pub const List = widgets.List;
pub const ListItem = widgets.ListItem;
pub const Gauge = widgets.Gauge;
pub const LineGauge = widgets.LineGauge;
pub const Table = widgets.Table;
pub const Tabs = widgets.Tabs;
pub const Sparkline = widgets.Sparkline;
pub const Bar = widgets.Bar;
pub const BarDirection = widgets.BarDirection;
pub const BarChart = widgets.BarChart;
pub const TextInput = widgets.TextInput;
pub const Checkbox = widgets.Checkbox;
pub const RadioItem = widgets.RadioItem;
pub const RadioGroup = widgets.RadioGroup;
pub const SpinnerKind = widgets.SpinnerKind;
pub const Spinner = widgets.Spinner;
pub const TreeNode = widgets.TreeNode;
pub const Tree = widgets.Tree;
pub const Canvas = widgets.Canvas;
pub const Popup = widgets.Popup;
pub const Dialog = widgets.Dialog;
pub const Date = widgets.Date;
pub const DatePicker = widgets.DatePicker;
pub const centeredRectPct = widgets.centeredRectPct;
pub const centeredRectFixed = widgets.centeredRectFixed;

pub const Graphics = graphics.Graphics;
pub const KittyGraphics = graphics.KittyGraphics;
pub const Image = graphics.Image;
pub const ImageWidget = widgets.ImageWidget;

pub const init = backend.init;

test {
    std.testing.refAllDecls(@This());
}
