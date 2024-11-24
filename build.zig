const std = @import("std");

fn copy_dir(src_dir: []const u8, destination_dir: []const u8) !void {
    const alloc = std.heap.page_allocator;
    const cwd = std.fs.cwd();

    var src = try cwd.openDir(src_dir, .{ .iterate = true });
    defer src.close();

    var dest = try cwd.openDir(destination_dir, .{ .iterate = true });
    defer dest.close();

    var walker = try src.walk(alloc);
    defer walker.deinit();

    var paths = std.ArrayList([]const u8).init(alloc);
    defer paths.deinit();

    while (try walker.next()) |entry| {
        try paths.append(entry.path);
    }

    if (paths.items.len == 0) {
        std.debug.print("directory is empty", .{});
        return;
    }

    for (paths.items) |path| {
        try std.fs.Dir.copyFile(src, path, dest, path, .{});
    }
}

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

    exe.addLibraryPath(.{ .cwd_relative = "dependencies/VK/!static" });
    exe.linkSystemLibrary(vulkan);

    exe.addLibraryPath(.{ .cwd_relative = "dependencies/SDL/!static" });
    exe.linkSystemLibrary("SDL3");
    exe.addIncludePath(b.path("./dependencies/SDL"));

    exe.linkLibCpp();
    exe.addCSourceFile(.{ .file = b.path("src/vma_impl.cpp"), .flags = &.{"-I./dependencies/VK"} });
    exe.addIncludePath(b.path("./dependencies/VK"));

    exe.addCSourceFile(.{ .file = b.path("src/miniaudio_impl.c"), .flags = &.{"-I./dependencies"} });
    exe.addIncludePath(b.path("./dependencies"));

    //try copy_dir("./dependencies/VK/!dynamic", "./zig-out/bin");
    //try copy_dir("./dependencies/SDL/!dynamic", "./zig-out/bin");

    b.installArtifact(exe);

    if (target.result.os.tag == .windows) {
        b.installBinFile("./dependencies/SDL/!dynamic/SDL3.dll", "SDL3.dll");
    } else {
        b.installBinFile("./dependencies/SDL/!dynamic/libSDL3.so", "libSDL3.so.0");
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
