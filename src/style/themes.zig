//! Built-in themes for ZigTUI
//! Provides pre-configured color schemes for terminal applications

const style = @import("mod.zig");
const Color = style.Color;
const Style = style.Style;
const Modifier = style.Modifier;

/// A complete theme definition with all semantic colors
pub const Theme = struct {
    /// Theme metadata
    name: []const u8,
    description: []const u8,

    /// Base colors
    background: Color,
    foreground: Color,

    /// Primary accent colors
    primary: Color,
    secondary: Color,
    accent: Color,

    /// Semantic colors
    success: Color,
    warning: Color,
    error_color: Color,
    info: Color,

    /// UI element colors
    border: Color,
    border_focused: Color,
    selection: Color,
    highlight: Color,

    /// Text colors
    text: Color,
    text_muted: Color,
    text_inverted: Color,

    // ============================================
    // Convenience methods to create styled elements
    // ============================================

    /// Get style for primary elements (buttons, active items)
    pub fn primaryStyle(self: Theme) Style {
        return Style{ .fg = self.primary };
    }

    /// Get style for secondary elements
    pub fn secondaryStyle(self: Theme) Style {
        return Style{ .fg = self.secondary };
    }

    /// Get style for accent/highlighted elements
    pub fn accentStyle(self: Theme) Style {
        return Style{ .fg = self.accent };
    }

    /// Get style for success messages/indicators
    pub fn successStyle(self: Theme) Style {
        return Style{ .fg = self.success };
    }

    /// Get style for warning messages/indicators
    pub fn warningStyle(self: Theme) Style {
        return Style{ .fg = self.warning };
    }

    /// Get style for error messages/indicators
    pub fn errorStyle(self: Theme) Style {
        return Style{ .fg = self.error_color };
    }

    /// Get style for info messages
    pub fn infoStyle(self: Theme) Style {
        return Style{ .fg = self.info };
    }

    /// Get style for borders
    pub fn borderStyle(self: Theme) Style {
        return Style{ .fg = self.border };
    }

    /// Get style for focused borders
    pub fn borderFocusedStyle(self: Theme) Style {
        return Style{ .fg = self.border_focused };
    }

    /// Get style for selected items
    pub fn selectionStyle(self: Theme) Style {
        return Style{ .fg = self.text_inverted, .bg = self.selection };
    }

    /// Get style for highlighted items (hover, current)
    pub fn highlightStyle(self: Theme) Style {
        return Style{ .fg = self.foreground, .bg = self.highlight };
    }

    /// Get base text style
    pub fn textStyle(self: Theme) Style {
        return Style{ .fg = self.text };
    }

    /// Get muted/dimmed text style
    pub fn textMutedStyle(self: Theme) Style {
        return Style{ .fg = self.text_muted };
    }

    /// Get base style with background
    pub fn baseStyle(self: Theme) Style {
        return Style{ .fg = self.foreground, .bg = self.background };
    }

    /// Get title style (bold primary)
    pub fn titleStyle(self: Theme) Style {
        return Style{ .fg = self.primary, .modifier = Modifier.BOLD };
    }

    /// Create a block style configuration
    pub fn blockConfig(self: Theme, focused: bool) BlockStyle {
        return BlockStyle{
            .style = self.baseStyle(),
            .border_style = if (focused) self.borderFocusedStyle() else self.borderStyle(),
            .title_style = self.titleStyle(),
        };
    }

    /// Block style configuration helper
    pub const BlockStyle = struct {
        style: Style,
        border_style: Style,
        title_style: Style,
    };

    /// Get a gauge/progress bar style based on percentage
    pub fn gaugeStyle(self: Theme, percent: u8) Style {
        if (percent >= 90) {
            return Style{ .fg = self.error_color };
        } else if (percent >= 70) {
            return Style{ .fg = self.warning };
        } else {
            return Style{ .fg = self.success };
        }
    }

    /// Get style for list items
    pub fn listItemStyle(self: Theme, selected: bool, focused: bool) Style {
        if (selected and focused) {
            return self.selectionStyle().addModifier(Modifier.BOLD);
        } else if (selected) {
            return self.highlightStyle();
        } else {
            return self.textStyle();
        }
    }

    /// Get style for table headers
    pub fn tableHeaderStyle(self: Theme) Style {
        return Style{ .fg = self.primary, .modifier = Modifier.BOLD };
    }

    /// Get style for table rows (alternating)
    pub fn tableRowStyle(self: Theme, row_index: usize, selected: bool) Style {
        if (selected) {
            return self.selectionStyle();
        } else if (row_index % 2 == 0) {
            return self.textStyle();
        } else {
            return self.textMutedStyle();
        }
    }
};

// ============================================
// Built-in Themes
// ============================================

/// Default dark theme - balanced and easy on the eyes
pub const default = Theme{
    .name = "Default",
    .description = "Balanced dark theme with cyan accents",
    .background = .reset,
    .foreground = .white,
    .primary = .cyan,
    .secondary = .blue,
    .accent = .magenta,
    .success = .green,
    .warning = .yellow,
    .error_color = .red,
    .info = .light_blue,
    .border = .gray,
    .border_focused = .cyan,
    .selection = .blue,
    .highlight = .dark_gray,
    .text = .white,
    .text_muted = .gray,
    .text_inverted = .white,
};

/// Nord theme - Arctic, north-bluish color palette
pub const nord = Theme{
    .name = "Nord",
    .description = "Arctic, north-bluish color palette",
    .background = Color{ .rgb = .{ .r = 46, .g = 52, .b = 64 } }, // nord0
    .foreground = Color{ .rgb = .{ .r = 236, .g = 239, .b = 244 } }, // nord6
    .primary = Color{ .rgb = .{ .r = 136, .g = 192, .b = 208 } }, // nord8 (frost)
    .secondary = Color{ .rgb = .{ .r = 129, .g = 161, .b = 193 } }, // nord9
    .accent = Color{ .rgb = .{ .r = 180, .g = 142, .b = 173 } }, // nord15 (purple)
    .success = Color{ .rgb = .{ .r = 163, .g = 190, .b = 140 } }, // nord14 (green)
    .warning = Color{ .rgb = .{ .r = 235, .g = 203, .b = 139 } }, // nord13 (yellow)
    .error_color = Color{ .rgb = .{ .r = 191, .g = 97, .b = 106 } }, // nord11 (red)
    .info = Color{ .rgb = .{ .r = 94, .g = 129, .b = 172 } }, // nord10
    .border = Color{ .rgb = .{ .r = 76, .g = 86, .b = 106 } }, // nord3
    .border_focused = Color{ .rgb = .{ .r = 136, .g = 192, .b = 208 } }, // nord8
    .selection = Color{ .rgb = .{ .r = 67, .g = 76, .b = 94 } }, // nord2
    .highlight = Color{ .rgb = .{ .r = 59, .g = 66, .b = 82 } }, // nord1
    .text = Color{ .rgb = .{ .r = 236, .g = 239, .b = 244 } }, // nord6
    .text_muted = Color{ .rgb = .{ .r = 216, .g = 222, .b = 233 } }, // nord4
    .text_inverted = Color{ .rgb = .{ .r = 236, .g = 239, .b = 244 } },
};

/// Dracula theme - Dark theme with vibrant colors
pub const dracula = Theme{
    .name = "Dracula",
    .description = "Dark theme with vibrant colors",
    .background = Color{ .rgb = .{ .r = 40, .g = 42, .b = 54 } }, // background
    .foreground = Color{ .rgb = .{ .r = 248, .g = 248, .b = 242 } }, // foreground
    .primary = Color{ .rgb = .{ .r = 189, .g = 147, .b = 249 } }, // purple
    .secondary = Color{ .rgb = .{ .r = 139, .g = 233, .b = 253 } }, // cyan
    .accent = Color{ .rgb = .{ .r = 255, .g = 121, .b = 198 } }, // pink
    .success = Color{ .rgb = .{ .r = 80, .g = 250, .b = 123 } }, // green
    .warning = Color{ .rgb = .{ .r = 255, .g = 184, .b = 108 } }, // orange
    .error_color = Color{ .rgb = .{ .r = 255, .g = 85, .b = 85 } }, // red
    .info = Color{ .rgb = .{ .r = 139, .g = 233, .b = 253 } }, // cyan
    .border = Color{ .rgb = .{ .r = 68, .g = 71, .b = 90 } }, // current line
    .border_focused = Color{ .rgb = .{ .r = 189, .g = 147, .b = 249 } }, // purple
    .selection = Color{ .rgb = .{ .r = 68, .g = 71, .b = 90 } }, // current line
    .highlight = Color{ .rgb = .{ .r = 68, .g = 71, .b = 90 } },
    .text = Color{ .rgb = .{ .r = 248, .g = 248, .b = 242 } },
    .text_muted = Color{ .rgb = .{ .r = 98, .g = 114, .b = 164 } }, // comment
    .text_inverted = Color{ .rgb = .{ .r = 248, .g = 248, .b = 242 } },
};

/// Monokai Pro theme - Refined Monokai colors
pub const monokai = Theme{
    .name = "Monokai Pro",
    .description = "Refined Monokai color palette",
    .background = Color{ .rgb = .{ .r = 45, .g = 42, .b = 46 } },
    .foreground = Color{ .rgb = .{ .r = 252, .g = 252, .b = 250 } },
    .primary = Color{ .rgb = .{ .r = 255, .g = 216, .b = 102 } }, // yellow
    .secondary = Color{ .rgb = .{ .r = 120, .g = 220, .b = 232 } }, // cyan
    .accent = Color{ .rgb = .{ .r = 255, .g = 97, .b = 136 } }, // pink
    .success = Color{ .rgb = .{ .r = 169, .g = 220, .b = 118 } }, // green
    .warning = Color{ .rgb = .{ .r = 255, .g = 216, .b = 102 } }, // yellow
    .error_color = Color{ .rgb = .{ .r = 255, .g = 97, .b = 136 } }, // red/pink
    .info = Color{ .rgb = .{ .r = 120, .g = 220, .b = 232 } }, // cyan
    .border = Color{ .rgb = .{ .r = 114, .g = 109, .b = 118 } },
    .border_focused = Color{ .rgb = .{ .r = 255, .g = 216, .b = 102 } },
    .selection = Color{ .rgb = .{ .r = 73, .g = 72, .b = 62 } },
    .highlight = Color{ .rgb = .{ .r = 60, .g = 58, .b = 54 } },
    .text = Color{ .rgb = .{ .r = 252, .g = 252, .b = 250 } },
    .text_muted = Color{ .rgb = .{ .r = 147, .g = 146, .b = 147 } },
    .text_inverted = Color{ .rgb = .{ .r = 252, .g = 252, .b = 250 } },
};

/// Gruvbox Dark theme - Retro groove color scheme
pub const gruvbox_dark = Theme{
    .name = "Gruvbox Dark",
    .description = "Retro groove color scheme (dark)",
    .background = Color{ .rgb = .{ .r = 40, .g = 40, .b = 40 } }, // bg0
    .foreground = Color{ .rgb = .{ .r = 235, .g = 219, .b = 178 } }, // fg1
    .primary = Color{ .rgb = .{ .r = 250, .g = 189, .b = 47 } }, // yellow
    .secondary = Color{ .rgb = .{ .r = 131, .g = 165, .b = 152 } }, // aqua
    .accent = Color{ .rgb = .{ .r = 211, .g = 134, .b = 155 } }, // purple
    .success = Color{ .rgb = .{ .r = 184, .g = 187, .b = 38 } }, // green
    .warning = Color{ .rgb = .{ .r = 250, .g = 189, .b = 47 } }, // yellow
    .error_color = Color{ .rgb = .{ .r = 251, .g = 73, .b = 52 } }, // red
    .info = Color{ .rgb = .{ .r = 131, .g = 165, .b = 152 } }, // aqua
    .border = Color{ .rgb = .{ .r = 146, .g = 131, .b = 116 } }, // fg4
    .border_focused = Color{ .rgb = .{ .r = 250, .g = 189, .b = 47 } }, // yellow
    .selection = Color{ .rgb = .{ .r = 80, .g = 73, .b = 69 } }, // bg2
    .highlight = Color{ .rgb = .{ .r = 60, .g = 56, .b = 54 } }, // bg1
    .text = Color{ .rgb = .{ .r = 235, .g = 219, .b = 178 } },
    .text_muted = Color{ .rgb = .{ .r = 168, .g = 153, .b = 132 } }, // fg3
    .text_inverted = Color{ .rgb = .{ .r = 235, .g = 219, .b = 178 } },
};

/// Gruvbox Light theme - Retro groove color scheme (light variant)
pub const gruvbox_light = Theme{
    .name = "Gruvbox Light",
    .description = "Retro groove color scheme (light)",
    .background = Color{ .rgb = .{ .r = 251, .g = 241, .b = 199 } }, // bg0
    .foreground = Color{ .rgb = .{ .r = 60, .g = 56, .b = 54 } }, // fg1
    .primary = Color{ .rgb = .{ .r = 181, .g = 118, .b = 20 } }, // yellow
    .secondary = Color{ .rgb = .{ .r = 66, .g = 123, .b = 88 } }, // aqua
    .accent = Color{ .rgb = .{ .r = 143, .g = 63, .b = 113 } }, // purple
    .success = Color{ .rgb = .{ .r = 121, .g = 116, .b = 14 } }, // green
    .warning = Color{ .rgb = .{ .r = 181, .g = 118, .b = 20 } }, // yellow
    .error_color = Color{ .rgb = .{ .r = 204, .g = 36, .b = 29 } }, // red
    .info = Color{ .rgb = .{ .r = 66, .g = 123, .b = 88 } }, // aqua
    .border = Color{ .rgb = .{ .r = 124, .g = 111, .b = 100 } }, // fg4
    .border_focused = Color{ .rgb = .{ .r = 181, .g = 118, .b = 20 } }, // yellow
    .selection = Color{ .rgb = .{ .r = 213, .g = 196, .b = 161 } }, // bg2
    .highlight = Color{ .rgb = .{ .r = 235, .g = 219, .b = 178 } }, // bg1
    .text = Color{ .rgb = .{ .r = 60, .g = 56, .b = 54 } },
    .text_muted = Color{ .rgb = .{ .r = 102, .g = 92, .b = 84 } }, // fg3
    .text_inverted = Color{ .rgb = .{ .r = 251, .g = 241, .b = 199 } },
};

/// Solarized Dark theme - Precision colors for machines and people
pub const solarized_dark = Theme{
    .name = "Solarized Dark",
    .description = "Precision colors for machines and people (dark)",
    .background = Color{ .rgb = .{ .r = 0, .g = 43, .b = 54 } }, // base03
    .foreground = Color{ .rgb = .{ .r = 131, .g = 148, .b = 150 } }, // base0
    .primary = Color{ .rgb = .{ .r = 38, .g = 139, .b = 210 } }, // blue
    .secondary = Color{ .rgb = .{ .r = 42, .g = 161, .b = 152 } }, // cyan
    .accent = Color{ .rgb = .{ .r = 108, .g = 113, .b = 196 } }, // violet
    .success = Color{ .rgb = .{ .r = 133, .g = 153, .b = 0 } }, // green
    .warning = Color{ .rgb = .{ .r = 181, .g = 137, .b = 0 } }, // yellow
    .error_color = Color{ .rgb = .{ .r = 220, .g = 50, .b = 47 } }, // red
    .info = Color{ .rgb = .{ .r = 42, .g = 161, .b = 152 } }, // cyan
    .border = Color{ .rgb = .{ .r = 88, .g = 110, .b = 117 } }, // base01
    .border_focused = Color{ .rgb = .{ .r = 38, .g = 139, .b = 210 } }, // blue
    .selection = Color{ .rgb = .{ .r = 7, .g = 54, .b = 66 } }, // base02
    .highlight = Color{ .rgb = .{ .r = 7, .g = 54, .b = 66 } },
    .text = Color{ .rgb = .{ .r = 131, .g = 148, .b = 150 } },
    .text_muted = Color{ .rgb = .{ .r = 88, .g = 110, .b = 117 } },
    .text_inverted = Color{ .rgb = .{ .r = 253, .g = 246, .b = 227 } },
};

/// Solarized Light theme - Precision colors (light variant)
pub const solarized_light = Theme{
    .name = "Solarized Light",
    .description = "Precision colors for machines and people (light)",
    .background = Color{ .rgb = .{ .r = 253, .g = 246, .b = 227 } }, // base3
    .foreground = Color{ .rgb = .{ .r = 101, .g = 123, .b = 131 } }, // base00
    .primary = Color{ .rgb = .{ .r = 38, .g = 139, .b = 210 } }, // blue
    .secondary = Color{ .rgb = .{ .r = 42, .g = 161, .b = 152 } }, // cyan
    .accent = Color{ .rgb = .{ .r = 108, .g = 113, .b = 196 } }, // violet
    .success = Color{ .rgb = .{ .r = 133, .g = 153, .b = 0 } }, // green
    .warning = Color{ .rgb = .{ .r = 181, .g = 137, .b = 0 } }, // yellow
    .error_color = Color{ .rgb = .{ .r = 220, .g = 50, .b = 47 } }, // red
    .info = Color{ .rgb = .{ .r = 42, .g = 161, .b = 152 } }, // cyan
    .border = Color{ .rgb = .{ .r = 147, .g = 161, .b = 161 } }, // base1
    .border_focused = Color{ .rgb = .{ .r = 38, .g = 139, .b = 210 } }, // blue
    .selection = Color{ .rgb = .{ .r = 238, .g = 232, .b = 213 } }, // base2
    .highlight = Color{ .rgb = .{ .r = 238, .g = 232, .b = 213 } },
    .text = Color{ .rgb = .{ .r = 101, .g = 123, .b = 131 } },
    .text_muted = Color{ .rgb = .{ .r = 147, .g = 161, .b = 161 } },
    .text_inverted = Color{ .rgb = .{ .r = 0, .g = 43, .b = 54 } },
};

/// Tokyo Night theme - Clean dark theme inspired by Tokyo city lights
pub const tokyo_night = Theme{
    .name = "Tokyo Night",
    .description = "Clean dark theme inspired by Tokyo city lights",
    .background = Color{ .rgb = .{ .r = 26, .g = 27, .b = 38 } },
    .foreground = Color{ .rgb = .{ .r = 192, .g = 202, .b = 245 } },
    .primary = Color{ .rgb = .{ .r = 122, .g = 162, .b = 247 } }, // blue
    .secondary = Color{ .rgb = .{ .r = 125, .g = 207, .b = 255 } }, // cyan
    .accent = Color{ .rgb = .{ .r = 187, .g = 154, .b = 247 } }, // purple
    .success = Color{ .rgb = .{ .r = 158, .g = 206, .b = 106 } }, // green
    .warning = Color{ .rgb = .{ .r = 224, .g = 175, .b = 104 } }, // yellow/orange
    .error_color = Color{ .rgb = .{ .r = 247, .g = 118, .b = 142 } }, // red
    .info = Color{ .rgb = .{ .r = 125, .g = 207, .b = 255 } }, // cyan
    .border = Color{ .rgb = .{ .r = 41, .g = 46, .b = 66 } },
    .border_focused = Color{ .rgb = .{ .r = 122, .g = 162, .b = 247 } },
    .selection = Color{ .rgb = .{ .r = 41, .g = 46, .b = 66 } },
    .highlight = Color{ .rgb = .{ .r = 36, .g = 40, .b = 59 } },
    .text = Color{ .rgb = .{ .r = 192, .g = 202, .b = 245 } },
    .text_muted = Color{ .rgb = .{ .r = 86, .g = 95, .b = 137 } },
    .text_inverted = Color{ .rgb = .{ .r = 192, .g = 202, .b = 245 } },
};

/// Catppuccin Mocha theme - Soothing pastel theme (dark)
pub const catppuccin_mocha = Theme{
    .name = "Catppuccin Mocha",
    .description = "Soothing pastel theme for the high-spirited",
    .background = Color{ .rgb = .{ .r = 30, .g = 30, .b = 46 } }, // base
    .foreground = Color{ .rgb = .{ .r = 205, .g = 214, .b = 244 } }, // text
    .primary = Color{ .rgb = .{ .r = 137, .g = 180, .b = 250 } }, // blue
    .secondary = Color{ .rgb = .{ .r = 148, .g = 226, .b = 213 } }, // teal
    .accent = Color{ .rgb = .{ .r = 245, .g = 194, .b = 231 } }, // pink
    .success = Color{ .rgb = .{ .r = 166, .g = 227, .b = 161 } }, // green
    .warning = Color{ .rgb = .{ .r = 249, .g = 226, .b = 175 } }, // yellow
    .error_color = Color{ .rgb = .{ .r = 243, .g = 139, .b = 168 } }, // red
    .info = Color{ .rgb = .{ .r = 137, .g = 220, .b = 235 } }, // sky
    .border = Color{ .rgb = .{ .r = 69, .g = 71, .b = 90 } }, // surface1
    .border_focused = Color{ .rgb = .{ .r = 203, .g = 166, .b = 247 } }, // mauve
    .selection = Color{ .rgb = .{ .r = 88, .g = 91, .b = 112 } }, // surface2
    .highlight = Color{ .rgb = .{ .r = 49, .g = 50, .b = 68 } }, // surface0
    .text = Color{ .rgb = .{ .r = 205, .g = 214, .b = 244 } },
    .text_muted = Color{ .rgb = .{ .r = 166, .g = 173, .b = 200 } }, // subtext0
    .text_inverted = Color{ .rgb = .{ .r = 205, .g = 214, .b = 244 } },
};

/// Catppuccin Latte theme - Soothing pastel theme (light)
pub const catppuccin_latte = Theme{
    .name = "Catppuccin Latte",
    .description = "Soothing pastel theme (light variant)",
    .background = Color{ .rgb = .{ .r = 239, .g = 241, .b = 245 } }, // base
    .foreground = Color{ .rgb = .{ .r = 76, .g = 79, .b = 105 } }, // text
    .primary = Color{ .rgb = .{ .r = 30, .g = 102, .b = 245 } }, // blue
    .secondary = Color{ .rgb = .{ .r = 23, .g = 146, .b = 153 } }, // teal
    .accent = Color{ .rgb = .{ .r = 234, .g = 118, .b = 203 } }, // pink
    .success = Color{ .rgb = .{ .r = 64, .g = 160, .b = 43 } }, // green
    .warning = Color{ .rgb = .{ .r = 223, .g = 142, .b = 29 } }, // yellow
    .error_color = Color{ .rgb = .{ .r = 210, .g = 15, .b = 57 } }, // red
    .info = Color{ .rgb = .{ .r = 4, .g = 165, .b = 229 } }, // sky
    .border = Color{ .rgb = .{ .r = 188, .g = 192, .b = 204 } }, // surface1
    .border_focused = Color{ .rgb = .{ .r = 136, .g = 57, .b = 239 } }, // mauve
    .selection = Color{ .rgb = .{ .r = 172, .g = 176, .b = 190 } }, // surface2
    .highlight = Color{ .rgb = .{ .r = 204, .g = 208, .b = 218 } }, // surface0
    .text = Color{ .rgb = .{ .r = 76, .g = 79, .b = 105 } },
    .text_muted = Color{ .rgb = .{ .r = 108, .g = 111, .b = 133 } }, // subtext0
    .text_inverted = Color{ .rgb = .{ .r = 239, .g = 241, .b = 245 } },
};

/// One Dark theme - Atom's iconic dark theme
pub const one_dark = Theme{
    .name = "One Dark",
    .description = "Atom's iconic dark theme",
    .background = Color{ .rgb = .{ .r = 40, .g = 44, .b = 52 } },
    .foreground = Color{ .rgb = .{ .r = 171, .g = 178, .b = 191 } },
    .primary = Color{ .rgb = .{ .r = 97, .g = 175, .b = 239 } }, // blue
    .secondary = Color{ .rgb = .{ .r = 86, .g = 182, .b = 194 } }, // cyan
    .accent = Color{ .rgb = .{ .r = 198, .g = 120, .b = 221 } }, // purple
    .success = Color{ .rgb = .{ .r = 152, .g = 195, .b = 121 } }, // green
    .warning = Color{ .rgb = .{ .r = 229, .g = 192, .b = 123 } }, // yellow
    .error_color = Color{ .rgb = .{ .r = 224, .g = 108, .b = 117 } }, // red
    .info = Color{ .rgb = .{ .r = 86, .g = 182, .b = 194 } }, // cyan
    .border = Color{ .rgb = .{ .r = 62, .g = 68, .b = 81 } },
    .border_focused = Color{ .rgb = .{ .r = 97, .g = 175, .b = 239 } },
    .selection = Color{ .rgb = .{ .r = 62, .g = 68, .b = 81 } },
    .highlight = Color{ .rgb = .{ .r = 50, .g = 56, .b = 66 } },
    .text = Color{ .rgb = .{ .r = 171, .g = 178, .b = 191 } },
    .text_muted = Color{ .rgb = .{ .r = 92, .g = 99, .b = 112 } },
    .text_inverted = Color{ .rgb = .{ .r = 171, .g = 178, .b = 191 } },
};

/// Cyberpunk theme - Neon colors on dark background
pub const cyberpunk = Theme{
    .name = "Cyberpunk",
    .description = "Neon colors inspired by cyberpunk aesthetics",
    .background = Color{ .rgb = .{ .r = 13, .g = 2, .b = 33 } },
    .foreground = Color{ .rgb = .{ .r = 255, .g = 0, .b = 255 } }, // magenta
    .primary = Color{ .rgb = .{ .r = 0, .g = 255, .b = 255 } }, // cyan
    .secondary = Color{ .rgb = .{ .r = 255, .g = 0, .b = 255 } }, // magenta
    .accent = Color{ .rgb = .{ .r = 255, .g = 255, .b = 0 } }, // yellow
    .success = Color{ .rgb = .{ .r = 0, .g = 255, .b = 128 } }, // neon green
    .warning = Color{ .rgb = .{ .r = 255, .g = 165, .b = 0 } }, // orange
    .error_color = Color{ .rgb = .{ .r = 255, .g = 0, .b = 64 } }, // hot pink
    .info = Color{ .rgb = .{ .r = 0, .g = 191, .b = 255 } }, // deep sky blue
    .border = Color{ .rgb = .{ .r = 128, .g = 0, .b = 128 } }, // purple
    .border_focused = Color{ .rgb = .{ .r = 0, .g = 255, .b = 255 } }, // cyan
    .selection = Color{ .rgb = .{ .r = 75, .g = 0, .b = 130 } }, // indigo
    .highlight = Color{ .rgb = .{ .r = 48, .g = 0, .b = 48 } },
    .text = Color{ .rgb = .{ .r = 224, .g = 224, .b = 255 } },
    .text_muted = Color{ .rgb = .{ .r = 128, .g = 128, .b = 192 } },
    .text_inverted = Color{ .rgb = .{ .r = 13, .g = 2, .b = 33 } },
};

/// Matrix theme - Classic green-on-black terminal look
pub const matrix = Theme{
    .name = "Matrix",
    .description = "Classic green-on-black hacker aesthetic",
    .background = .black,
    .foreground = .green,
    .primary = .light_green,
    .secondary = .green,
    .accent = .light_green,
    .success = .light_green,
    .warning = Color{ .rgb = .{ .r = 128, .g = 255, .b = 0 } },
    .error_color = Color{ .rgb = .{ .r = 255, .g = 64, .b = 64 } },
    .info = .green,
    .border = .green,
    .border_focused = .light_green,
    .selection = Color{ .rgb = .{ .r = 0, .g = 64, .b = 0 } },
    .highlight = Color{ .rgb = .{ .r = 0, .g = 32, .b = 0 } },
    .text = .green,
    .text_muted = Color{ .rgb = .{ .r = 0, .g = 128, .b = 0 } },
    .text_inverted = .black,
};

/// High Contrast theme - Maximum readability
pub const high_contrast = Theme{
    .name = "High Contrast",
    .description = "Maximum readability with stark contrasts",
    .background = .black,
    .foreground = .white,
    .primary = .light_cyan,
    .secondary = .light_yellow,
    .accent = .light_magenta,
    .success = .light_green,
    .warning = .light_yellow,
    .error_color = .light_red,
    .info = .light_cyan,
    .border = .white,
    .border_focused = .light_cyan,
    .selection = .white,
    .highlight = .dark_gray,
    .text = .white,
    .text_muted = .gray,
    .text_inverted = .black,
};

// ============================================
// Theme List and Utilities
// ============================================

/// Array of all built-in themes for iteration
pub const all_themes = [_]*const Theme{
    &default,
    &nord,
    &dracula,
    &monokai,
    &gruvbox_dark,
    &gruvbox_light,
    &solarized_dark,
    &solarized_light,
    &tokyo_night,
    &catppuccin_mocha,
    &catppuccin_latte,
    &one_dark,
    &cyberpunk,
    &matrix,
    &high_contrast,
};

/// Get a theme by name (case-insensitive)
pub fn getByName(name: []const u8) ?*const Theme {
    for (all_themes) |theme| {
        if (eqlIgnoreCase(theme.name, name)) {
            return theme;
        }
    }
    return null;
}

/// Get theme names as a slice (useful for menus/selection)
pub fn getThemeNames() [all_themes.len][]const u8 {
    var names: [all_themes.len][]const u8 = undefined;
    for (all_themes, 0..) |theme, i| {
        names[i] = theme.name;
    }
    return names;
}

/// Case-insensitive string comparison
fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        const la = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lb = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (la != lb) return false;
    }
    return true;
}

// ============================================
// Tests
// ============================================

const std = @import("std");

test "theme style generation" {
    const theme = default;
    
    const primary = theme.primaryStyle();
    try std.testing.expect(primary.fg != null);
    try std.testing.expect(primary.fg.?.eql(.cyan));
    
    const success = theme.successStyle();
    try std.testing.expect(success.fg.?.eql(.green));
}

test "get theme by name" {
    const theme = getByName("Nord");
    try std.testing.expect(theme != null);
    try std.testing.expectEqualStrings("Nord", theme.?.name);
    
    const invalid = getByName("NonExistent");
    try std.testing.expect(invalid == null);
    
    // Case insensitive
    const dracula_theme = getByName("DRACULA");
    try std.testing.expect(dracula_theme != null);
}

test "all themes accessible" {
    for (all_themes) |theme| {
        try std.testing.expect(theme.name.len > 0);
        try std.testing.expect(theme.description.len > 0);
    }
}
