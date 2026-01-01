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
}
