const std = @import("std");

const c = @import("clibs.zig");

const log = std.log.scoped(.vulkan_init);

const version = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

pub const vk_info = struct {
    app_name: [:0]const u8 = "zengine",
    app_version: version,
    engine_name: [:0]const u8 = "zengine",
    engine_version: version,
    api_version: version,
    debug: bool,
    required_extensions: []const [*c]const u8,
};

pub const instance = struct {
    handle: c.VkInstance,
};

fn find_extension(ext_name: [*c]const u8, ext_props: []c.VkExtensionProperties) bool {
    for (ext_props) |prop| {
        const prop_name: [*c]const u8 = @ptrCast(prop.extensionName[0..]);
        if (std.mem.eql(u8, std.mem.span(ext_name), std.mem.span(prop_name))) {
            return true;
        }
    }
    return false;
}

fn find_layer(layer_name: [*c]const u8, layer_props: []c.VkLayerProperties) bool {
    for (layer_props) |prop| {
        const prop_name: [*c]const u8 = @ptrCast(prop.extensionName[0..]);
        if (std.mem.eql(u8, std.mem.span(layer_name), std.mem.span(prop_name))) {
            return true;
        }
    }
    return false;
}

pub fn create_vulkan_instance(allocator: std.mem.Allocator, app_info: vk_info) !instance {
    var vulkan_version: u32 = c.VK_MAKE_VERSION(app_info.api_version.major, app_info.api_version.minor, app_info.api_version.minor);

    if (c.vkEnumerateInstanceVersion(&vulkan_version) != c.VK_SUCCESS) {
        log.err("Vulkan version {}.{}.{} not supported.", .{ app_info.api_version.major, app_info.api_version.minor, app_info.api_version.minor });
    }

    const major: u32 = c.VK_VERSION_MAJOR(vulkan_version);
    const minor: u32 = c.VK_VERSION_MINOR(vulkan_version);
    const patch: u32 = c.VK_VERSION_PATCH(vulkan_version);

    log.info(" Vulkan version: {}.{}.{}", .{ major, minor, patch });

    //var enable_validation = app_info.debug;

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

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
        log.err("failed to get extension count", .{});
    }

    log.info(" Vulkan extension count : {}", .{extension_count});

    const extension_props: []c.VkExtensionProperties = try arena.alloc(c.VkExtensionProperties, extension_count);

    if (c.vkEnumerateInstanceExtensionProperties(null, &extension_count, extension_props.ptr) != c.VK_SUCCESS) {
        log.err("failed to get extension names", .{});
    }

    var extensions = std.ArrayListUnmanaged([*c]const u8){};

    for (app_info.required_extensions) |required_ext| {
        if (find_extension(required_ext, extension_props)) {
            try extensions.append(arena, required_ext);
        } else {
            log.err("Required vulkan extension not supported: {s}", .{required_ext});
        }
    }

    var layer_count: u32 = 0;
    if (c.vkEnumerateInstanceLayerProperties(&layer_count, null) != c.VK_SUCCESS) {
        log.err("failed to get layer count", .{});
    }

    instance_ci.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instance_ci.pNext = null;
    instance_ci.pApplicationInfo = &app_ci;
    instance_ci.enabledExtensionCount = @as(u32, @intCast(extensions.items.len));
    instance_ci.ppEnabledExtensionNames = extensions.items.ptr;
    //    instance_ci.enabledLayerCount =
    //    instance_ci.ppEnabledLayerNames =

    return a;
}
