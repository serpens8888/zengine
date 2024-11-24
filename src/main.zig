const std = @import("std");

const c = @import("clibs.zig");

const vk_init = @import("vulkan_init.zig");

const log = std.log.scoped(.main);

pub fn main() !void {
    std.debug.print("Hello, World!\n\n", .{});

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != true) {
        log.err("SDL init failed", .{});
    }
    defer c.SDL_Quit();

    var sdl_required_extension_count: u32 = undefined;
    const sdl_extensions = c.SDL_Vulkan_GetInstanceExtensions(&sdl_required_extension_count);
    const sdl_extensions_slice = sdl_extensions[0..sdl_required_extension_count];

    _ = try vk_init.create_vulkan_instance(std.heap.page_allocator, .{
        .app_name = "zengine",
        .app_version = .{ .major = 0, .minor = 0, .patch = 0 },
        .engine_name = "zengine",
        .engine_version = .{ .major = 0, .minor = 0, .patch = 0 },
        .debug = true,
        .required_extensions = sdl_extensions_slice,
    });
}
