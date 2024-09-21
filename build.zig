const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "flv",
        .root_source_file = b.path("src/flv.zig"),
        .target = target,
        .optimize = optimize,
        .strip = true,
        .pic = true,
    });

    b.installArtifact(lib);
}
