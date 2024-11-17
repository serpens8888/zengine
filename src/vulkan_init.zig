const std = @import("std");

const c = @import("clibs.zig");

const log = std.log.scoped(.vulkan_init);

const version = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

pub const vk_app_info = struct {
    app_name: [:0]const u8 = "zengine",
    app_version: version,
    engine_name: [:0]const u8 = "zengine",
    engine_version: version,
};

pub const instance = struct {
    handle: c.VkInstance,
};

pub fn create_vulkan_instance(app_info: vk_app_info) !instance {
    var vulkan_version: u32 = undefined;
    _ = c.vkEnumerateInstanceVersion(&vulkan_version);

    const major: u32 = c.VK_VERSION_MAJOR(vulkan_version);
    const minor: u32 = c.VK_VERSION_MINOR(vulkan_version);
    const patch: u32 = c.VK_VERSION_PATCH(vulkan_version);

    log.info(" Vulkan version: {}.{}.{}\n", .{ major, minor, patch });

    const a: instance = std.mem.zeroInit(instance, .{null});

    var app_ci: c.VkApplicationInfo = std.mem.zeroInit(c.VkApplicationInfo, .{0});

    app_ci.sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app_ci.pNext = null;
    app_ci.apiVersion = c.VK_MAKE_API_VERSION(0, 1, 3, 0);
    app_ci.pApplicationName = app_info.app_name;
    app_ci.applicationVersion = c.VK_MAKE_VERSION(app_info.app_version.major, app_info.app_version.minor, app_info.app_version.patch);
    app_ci.pEngineName = app_info.engine_name;
    app_ci.engineVersion = c.VK_MAKE_VERSION(app_info.engine_version.major, app_info.engine_version.minor, app_info.engine_version.patch);

    var instance_ci: c.VkInstanceCreateInfo = std.mem.zeroInit(c.VkInstanceCreateInfo, .{0});

    instance_ci.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instance_ci.pNext = null;
    instance_ci.pApplicationInfo = &app_ci;

    return a;
}
