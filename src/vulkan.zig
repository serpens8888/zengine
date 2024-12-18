const std = @import("std");

const c = @import("clibs.zig");

const vk_init = @import("vulkan_init.zig");

const log = std.log.scoped(.vulkan);

pub fn get_vk_instance() !vk_init.Instance {
    var sdl_required_extension_count: u32 = undefined;
    const sdl_extensions = c.SDL_Vulkan_GetInstanceExtensions(&sdl_required_extension_count);
    const sdl_extensions_slice = sdl_extensions[0..sdl_required_extension_count];

    const instance: vk_init.Instance = try vk_init.create_vulkan_instance(std.heap.page_allocator, .{
        .app_name = "zengine",
        .app_version = .{ .major = 0, .minor = 0, .patch = 0 },
        .engine_name = "zengine",
        .engine_version = .{ .major = 0, .minor = 0, .patch = 0 },
        .api_version = .{ .major = 1, .minor = 3, .patch = 0 },
        .debug = true,
        .required_extensions = sdl_extensions_slice,
        .alloc_callback = null,
        .debug_callback = vk_init.default_debug_callback,
    });

    return instance;
}
pub fn destroy_vk_instance(instance: vk_init.Instance) !void {
    vk_init.destroy_debug_utils_messenger(instance, null);
    vk_init.destroy_instance(instance, null);
}
