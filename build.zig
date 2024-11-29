const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "foo",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = b.host,
    });

    exe.linkLibC();

    const vulkan = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan";

    exe.addLibraryPath(.{ .cwd_relative = "dependencies/VK/lib" });
    exe.linkSystemLibrary(vulkan);

    exe.addLibraryPath(.{ .cwd_relative = "dependencies/SDL/lib" });
    exe.linkSystemLibrary("SDL3");
    exe.addIncludePath(b.path("./dependencies/SDL"));

    exe.linkLibCpp();
    exe.addCSourceFile(.{ .file = b.path("src/vma_impl.cpp"), .flags = &.{"-I./dependencies/VK"} });
    exe.addIncludePath(b.path("./dependencies/VK"));

    exe.addCSourceFile(.{ .file = b.path("src/miniaudio_impl.c"), .flags = &.{"-I./dependencies"} });
    exe.addIncludePath(b.path("./dependencies"));

    b.installArtifact(exe);

    if (target.result.os.tag == .windows) {
        b.installBinFile("./dependencies/SDL/lib/SDL3.dll", "SDL3.dll");
    } else {
        b.installBinFile("./dependencies/SDL/lib/libSDL3.so", "libSDL3.so.0");
        exe.root_module.addRPathSpecial("$ORIGIN");
    }

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_step = b.step("run", "run the application");
    run_step.dependOn(&run_exe.step);
}
