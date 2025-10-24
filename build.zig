const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // This creates a module for the library so it can be used
    // as a dependency with @import("conzole")
    const conzole_module = b.addModule("conzole", .{
        .root_source_file = b.path("lib/root.zig"),
        .target = target,
    });

    // Test step for the library (includes all tests via refAllDecls)
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Create test step that runs all tests (now includes all module tests via refAllDecls)
    const test_step = b.step("test", "Run all library tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Container example - comprehensive Docker-like CLI demonstrating all features
    const container_example = b.addExecutable(.{
        .name = "container",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/container.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "conzole", .module = conzole_module },
            },
        }),
    });

    b.installArtifact(container_example);

    const run_container_example = b.addRunArtifact(container_example);
    if (b.args) |args| {
        run_container_example.addArgs(args);
    }

    const run_container_example_step = b.step("run-container", "Run the container management example");
    run_container_example_step.dependOn(&run_container_example.step);
}
