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

fn printExtensions(extensions: []c.VkExtensionProperties, extension_count: u32) !void {
    for (extensions[0..extension_count]) |extension| {
        std.debug.print("extension: {s}, spec version: {d}\n", .{ extension.extensionName, extension.specVersion });
    }
}

pub fn create_vulkan_instance(allocator: std.mem.Allocator, app_info: vk_app_info) !instance {
    var vulkan_version: u32 = 0;

    if (c.vkEnumerateInstanceVersion(&vulkan_version) != c.VK_SUCCESS) {
        log.err("Failed to get vulkan version", .{});
    }

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

    var extension_count: u32 = 0;

    if (c.vkEnumerateInstanceExtensionProperties(null, &extension_count, null) != c.VK_SUCCESS) {
        log.err("failed to get vulkan extension count", .{});
    }

    log.info(" extension count : {}\n", .{extension_count});

    const extensions: []c.VkExtensionProperties = try allocator.alloc(c.VkExtensionProperties, extension_count);

    defer allocator.free(extensions);

    if (c.vkEnumerateInstanceExtensionProperties(null, &extension_count, extensions.ptr) != c.VK_SUCCESS) {
        log.err("failed to get  vulkan extension names", .{});
    }

    try printExtensions(extensions, extension_count);

    instance_ci.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instance_ci.pNext = null;
    instance_ci.pApplicationInfo = &app_ci;
    instance_ci.enabledExtensionCount = extension_count;
    //    instance_ci.ppEnabledExtensionNames =
    //    instance_ci.enabledLayerCount =
    //    instance_ci.ppEnabledLayerNames =

    return a;
}
