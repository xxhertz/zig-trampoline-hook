const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .cpu_arch = .x86 } });
    const optimize = b.standardOptimizeOption(.{});

    const zigwin32_dep = b.dependency("zigwin32", .{});

    const exe = b.addExecutable(.{
        .name = "zig-trampoline-hook",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // exe.subsystem = .Windows; // no console (known as "GUI only" on mslearn)

    exe.root_module.addImport("zigwin32", zigwin32_dep.module("zigwin32"));

    b.installArtifact(exe);
}
