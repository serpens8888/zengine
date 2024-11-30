const std = @import("std");

const c = @import("clibs.zig");
const check = @import("check_vk.zig");

const log = std.log.scoped(.vulkan_init);

const version = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

pub const vk_instance_info = struct {
    app_name: [:0]const u8 = "zengine",
    app_version: version,
    engine_name: [:0]const u8 = "zengine",
    engine_version: version,
    api_version: version,
    debug: bool,
    required_extensions: []const [*c]const u8,
    debug_callback: c.PFN_vkDebugUtilsMessengerCallbackEXT,
    alloc_callback: ?*c.VkAllocationCallbacks,
};

pub const Instance = struct {
    handle: c.VkInstance = null,
    debug_messenger: c.VkDebugUtilsMessengerEXT = null,
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
        const prop_name: [*c]const u8 = @ptrCast(prop.layerName[0..]);
        if (std.mem.eql(u8, std.mem.span(layer_name), std.mem.span(prop_name))) {
            return true;
        }
    }
    return false;
}

pub fn create_vulkan_instance(allocator: std.mem.Allocator, app_info: vk_instance_info) !Instance {
    var vulkan_version: u32 = c.VK_MAKE_VERSION(app_info.api_version.major, app_info.api_version.minor, app_info.api_version.minor);

    if (c.vkEnumerateInstanceVersion(&vulkan_version) != c.VK_SUCCESS) {
        log.err("Vulkan version {}.{}.{} not supported.", .{ app_info.api_version.major, app_info.api_version.minor, app_info.api_version.minor });
    }

    const major: u32 = c.VK_VERSION_MAJOR(vulkan_version);
    const minor: u32 = c.VK_VERSION_MINOR(vulkan_version);
    const patch: u32 = c.VK_VERSION_PATCH(vulkan_version);

    log.info(" Vulkan version: {}.{}.{}", .{ major, minor, patch });

    const enable_validation = app_info.debug;

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

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
    var layers = std.ArrayListUnmanaged([*c]const u8){};
    if (enable_validation == true) {
        if (c.vkEnumerateInstanceLayerProperties(&layer_count, null) != c.VK_SUCCESS) {
            log.err("failed to get layer count", .{});
        }

        const layer_props: []c.VkLayerProperties = try arena.alloc(c.VkLayerProperties, layer_count);
        if (c.vkEnumerateInstanceLayerProperties(&extension_count, layer_props.ptr) != c.VK_SUCCESS) {
            log.err("failed to get layer names", .{});
        }

        const validation_layer: [*c]const u8 = "VK_LAYER_KHRONOS_validation";

        if (find_layer(validation_layer, layer_props)) {
            try layers.append(arena, validation_layer);
        }
    }

    instance_ci.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instance_ci.pNext = null;
    instance_ci.pApplicationInfo = &app_ci;
    instance_ci.enabledExtensionCount = @as(u32, @intCast(extensions.items.len));
    instance_ci.ppEnabledExtensionNames = extensions.items.ptr;
    instance_ci.enabledLayerCount = @as(u32, @intCast(layers.items.len));
    instance_ci.ppEnabledLayerNames = layers.items.ptr;

    var instance_handle: c.VkInstance = undefined;
    if (c.vkCreateInstance(&instance_ci, app_info.alloc_callback, &instance_handle) != c.VK_SUCCESS) {
        log.err("failed to create vulkan instance", .{});
    }
    log.info("created vulkan instance", .{});

    const debug_messenger = if (enable_validation)
        try create_debug_callback(instance_handle, app_info)
    else
        null;

    return .{ .handle = instance_handle, .debug_messenger = debug_messenger };
}

fn get_vulkan_instance_func(comptime Fn: type, instance: c.VkInstance, name: [*c]const u8) Fn {
    const get_proc_addr: c.PFN_vkGetInstanceProcAddr = @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr());
    if (get_proc_addr) |get_proc_addr_fn| {
        return @ptrCast(get_proc_addr_fn(instance, name));
    }

    @panic("SDL_Vulkan_GetVkGetInstanceProcAddr returned null");
}

fn create_debug_callback(instance: c.VkInstance, instance_info: vk_instance_info) !c.VkDebugUtilsMessengerEXT {
    const create_fn_opt = get_vulkan_instance_func(c.PFN_vkCreateDebugUtilsMessengerEXT, instance, "vkCreateDebugUtilsMessengerEXT");
    log.info("got debug utils messenger creation function", .{});

    if (create_fn_opt) |create_fn| {
        const create_info: c.VkDebugUtilsMessengerCreateInfoEXT = .{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = instance_info.debug_callback,
            .pUserData = null,
            .flags = 0,
            .pNext = null,
        };
        var debug_messenger: c.VkDebugUtilsMessengerEXT = undefined;
        if (create_fn(instance, &create_info, instance_info.alloc_callback, &debug_messenger) != c.VK_SUCCESS) {
            log.err("failed to create debugs utils messenger", .{});
        }
        return debug_messenger;
    }
    log.err("failed to create debug messenger", .{});
    return null;
}

pub fn destroy_debug_utils_messenger(instance: Instance, alloc_cb: ?*c.VkAllocationCallbacks) void {
    if (instance.debug_messenger != null) {
        return;
    }

    const destroy_fn_opt = get_vulkan_instance_func(c.PFN_vkDestroyDebugUtilsMessengerEXT, instance.handle, "vkDestroyDebugUtilsMessengerEXT");

    if (destroy_fn_opt) |destroy_fn| {
        destroy_fn(instance.handle, instance.debug_messenger, alloc_cb);
        log.info("destroyed debug utils messenger", .{});
    }
}

pub fn destroy_instance(instance: Instance, alloc_cb: ?*c.VkAllocationCallbacks) void {
    c.vkDestroyInstance(instance.handle, alloc_cb);
    log.info("destroyed vulkan instance", .{});
}
