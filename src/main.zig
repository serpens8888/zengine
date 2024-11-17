const std = @import("std");

const c = @import("clibs.zig");

const vk_init = @import("vulkan_init.zig");

pub fn main() !void {
    std.debug.print("Hello, World!\n\n", .{});

    _ = try vk_init.create_vulkan_instance(std.heap.c_allocator, .{
        .app_name = "zengine",
        .app_version = .{ .major = 0, .minor = 0, .patch = 0 },
        .engine_name = "zengine",
        .engine_version = .{ .major = 0, .minor = 0, .patch = 0 },
    });
}
