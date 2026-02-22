const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Module export for other projects
    const zigtui_module = b.addModule("zigtui", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    // Tests
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);

    // Examples step
    const examples_step = b.step("examples", "Build example applications");

    // Example: Dashboard (System Monitor)
    const dashboard_example = b.addExecutable(.{
        .name = "dashboard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/dashboard.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigtui", .module = zigtui_module },
            },
        }),
    });
    const install_dashboard = b.addInstallArtifact(dashboard_example, .{});
    examples_step.dependOn(&install_dashboard.step);

    // Run dashboard example
    const run_dashboard = b.addRunArtifact(dashboard_example);
    run_dashboard.step.dependOn(&install_dashboard.step);
    const run_dashboard_step = b.step("run-dashboard", "Run system monitor dashboard");
    run_dashboard_step.dependOn(&run_dashboard.step);

    // Example: Kitty Graphics
    const kitty_example = b.addExecutable(.{
        .name = "kitty_graphics",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/kitty_graphics.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigtui", .module = zigtui_module },
            },
        }),
    });
    const install_kitty = b.addInstallArtifact(kitty_example, .{});
    examples_step.dependOn(&install_kitty.step);

    // Run kitty graphics example
    const run_kitty = b.addRunArtifact(kitty_example);
    run_kitty.step.dependOn(&install_kitty.step);
    const run_kitty_step = b.step("run-kitty", "Run Kitty graphics demo");
    run_kitty_step.dependOn(&run_kitty.step);

    // Example: Themes Demo
    const themes_example = b.addExecutable(.{
        .name = "themes_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/themes_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigtui", .module = zigtui_module },
            },
        }),
    });
    const install_themes = b.addInstallArtifact(themes_example, .{});
    examples_step.dependOn(&install_themes.step);

    // Run themes demo example
    const run_themes = b.addRunArtifact(themes_example);
    run_themes.step.dependOn(&install_themes.step);
    const run_themes_step = b.step("run-themes", "Run themes demo");
    run_themes_step.dependOn(&run_themes.step);

    // Example: Mouse Demo
    const mouse_example = b.addExecutable(.{
        .name = "mouse_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/mouse_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigtui", .module = zigtui_module },
            },
        }),
    });
    const install_mouse = b.addInstallArtifact(mouse_example, .{});
    examples_step.dependOn(&install_mouse.step);

    const run_mouse = b.addRunArtifact(mouse_example);
    run_mouse.step.dependOn(&install_mouse.step);
    const run_mouse_step = b.step("run-mouse", "Run mouse demo");
    run_mouse_step.dependOn(&run_mouse.step);

    // Example: Widgets Demo (new widgets showcase)
    const widgets_demo_example = b.addExecutable(.{
        .name = "widgets_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/widgets_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigtui", .module = zigtui_module },
            },
        }),
    });
    const install_widgets_demo = b.addInstallArtifact(widgets_demo_example, .{});
    examples_step.dependOn(&install_widgets_demo.step);

    const run_widgets_demo = b.addRunArtifact(widgets_demo_example);
    run_widgets_demo.step.dependOn(&install_widgets_demo.step);
    const run_widgets_demo_step = b.step("run-widgets-demo", "Run new widgets showcase");
    run_widgets_demo_step.dependOn(&run_widgets_demo.step);
}
