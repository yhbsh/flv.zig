const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const flv_lib = b.addStaticLibrary(.{
        .name = "flv",
        .root_source_file = b.path("src/flv.zig"),
        .target = target,
        .optimize = optimize,
    });

    const flv_module = b.addModule("flv", .{
        .root_source_file = b.path("src/flv.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(flv_lib);

    const flv_test = b.addTest(.{
        .root_source_file = b.path("src/flv_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    flv_test.root_module.addImport("flv", flv_module);

    const run_flv_test = b.addRunArtifact(flv_test);

    const test_step = b.step("test", "Run flv unit tests");
    test_step.dependOn(&run_flv_test.step);
}
