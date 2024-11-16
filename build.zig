const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "foo",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("vulkan");

    exe.linkLibCpp();
    exe.addCSourceFile(.{ .file = b.path("src/vma_impl.cpp"), .flags = &.{""} });
    exe.addIncludePath(b.path("vk_mem_alloc.h"));

    exe.addCSourceFile(.{ .file = b.path("src/miniaudio_impl.c"), .flags = &.{"-I./c_include"} });
    exe.addIncludePath(b.path("c_include/miniaudio.h"));

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "run the application");
    run_step.dependOn(&run_exe.step);
}
