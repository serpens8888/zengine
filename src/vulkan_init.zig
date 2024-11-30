const std = @import("std");

const c = @import("clibs.zig");

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

    const debug_extension: [*c]const u8 = "VK_EXT_debug_utils";
    if (find_extension(debug_extension, extension_props)) {
        log.info("found debug extension", .{});
        try extensions.append(arena, debug_extension);
    }

    var layer_count: u32 = 0;
    var layers = std.ArrayListUnmanaged([*c]const u8){};
    if (enable_validation == true) {
        if (c.vkEnumerateInstanceLayerProperties(&layer_count, null) != c.VK_SUCCESS) {
            log.err("failed to get layer count", .{});
        }

        const layer_props: []c.VkLayerProperties = try arena.alloc(c.VkLayerProperties, layer_count);
        try check_vk(c.vkEnumerateInstanceLayerProperties(&layer_count, layer_props.ptr));

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
        log.info("created debug utils messenger", .{});
        return debug_messenger;
    }
    log.err("failed to create debug messenger", .{});
    return null;
}

pub fn destroy_debug_utils_messenger(instance: Instance, alloc_cb: ?*c.VkAllocationCallbacks) void {
    if (instance.debug_messenger == null) {
        return;
    }

    const destroy_fn_opt = get_vulkan_instance_func(c.PFN_vkDestroyDebugUtilsMessengerEXT, instance.handle, "vkDestroyDebugUtilsMessengerEXT");
    log.info("got debug utils messenger destroy functoion", .{});

    if (destroy_fn_opt) |destroy_fn| {
        destroy_fn(instance.handle, instance.debug_messenger, alloc_cb);
        log.info("destroyed debug utils messenger", .{});
    }
}

pub fn destroy_instance(instance: Instance, alloc_cb: ?*c.VkAllocationCallbacks) void {
    c.vkDestroyInstance(instance.handle, alloc_cb);
    log.info("destroyed vulkan instance", .{});
}

pub fn default_debug_callback(severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT, msg_type: c.VkDebugUtilsMessageTypeFlagsEXT, callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT, user_data: ?*anyopaque) callconv(.C) c.VkBool32 {
    _ = user_data;
    const severity_str = switch (severity) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "verbose",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "info",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "warning",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "error",
        else => "unknown",
    };

    const type_str = switch (msg_type) {
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "general",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "performance",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT => "device address",
        else => "unknown",
    };

    const message: [*c]const u8 = if (callback_data) |cb_data| cb_data.pMessage else "NO MESSAGE!";
    log.err("[{s}][{s}]. Message:\n  {s}", .{ severity_str, type_str, message });

    if (severity >= c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) {
        @panic("Unrecoverable vulkan error.");
    }

    return c.VK_FALSE;
}

pub fn check_vk(result: c.VkResult) !void {
    return switch (result) {
        c.VK_SUCCESS => {},
        c.VK_NOT_READY => error.vk_not_ready,
        c.VK_TIMEOUT => error.vk_timeout,
        c.VK_EVENT_SET => error.vk_event_set,
        c.VK_EVENT_RESET => error.vk_event_reset,
        c.VK_INCOMPLETE => error.vk_incomplete,
        c.VK_ERROR_OUT_OF_HOST_MEMORY => error.vk_error_out_of_host_memory,
        c.VK_ERROR_OUT_OF_DEVICE_MEMORY => error.vk_error_out_of_device_memory,
        c.VK_ERROR_INITIALIZATION_FAILED => error.vk_error_initialization_failed,
        c.VK_ERROR_DEVICE_LOST => error.vk_error_device_lost,
        c.VK_ERROR_MEMORY_MAP_FAILED => error.vk_error_memory_map_failed,
        c.VK_ERROR_LAYER_NOT_PRESENT => error.vk_error_layer_not_present,
        c.VK_ERROR_EXTENSION_NOT_PRESENT => error.vk_error_extension_not_present,
        c.VK_ERROR_FEATURE_NOT_PRESENT => error.vk_error_feature_not_present,
        c.VK_ERROR_INCOMPATIBLE_DRIVER => error.vk_error_incompatible_driver,
        c.VK_ERROR_TOO_MANY_OBJECTS => error.vk_error_too_many_objects,
        c.VK_ERROR_FORMAT_NOT_SUPPORTED => error.vk_error_format_not_supported,
        c.VK_ERROR_FRAGMENTED_POOL => error.vk_error_fragmented_pool,
        c.VK_ERROR_UNKNOWN => error.vk_error_unknown,
        c.VK_ERROR_OUT_OF_POOL_MEMORY => error.vk_error_out_of_pool_memory,
        c.VK_ERROR_INVALID_EXTERNAL_HANDLE => error.vk_error_invalid_external_handle,
        c.VK_ERROR_FRAGMENTATION => error.vk_error_fragmentation,
        c.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS => error.vk_error_invalid_opaque_capture_address,
        c.VK_PIPELINE_COMPILE_REQUIRED => error.vk_pipeline_compile_required,
        c.VK_ERROR_SURFACE_LOST_KHR => error.vk_error_surface_lost_khr,
        c.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR => error.vk_error_native_window_in_use_khr,
        c.VK_SUBOPTIMAL_KHR => error.vk_suboptimal_khr,
        c.VK_ERROR_OUT_OF_DATE_KHR => error.vk_error_out_of_date_khr,
        c.VK_ERROR_INCOMPATIBLE_DISPLAY_KHR => error.vk_error_incompatible_display_khr,
        c.VK_ERROR_VALIDATION_FAILED_EXT => error.vk_error_validation_failed_ext,
        c.VK_ERROR_INVALID_SHADER_NV => error.vk_error_invalid_shader_nv,
        c.VK_ERROR_IMAGE_USAGE_NOT_SUPPORTED_KHR => error.vk_error_image_usage_not_supported_khr,
        c.VK_ERROR_VIDEO_PICTURE_LAYOUT_NOT_SUPPORTED_KHR => error.vk_error_video_picture_layout_not_supported_khr,
        c.VK_ERROR_VIDEO_PROFILE_OPERATION_NOT_SUPPORTED_KHR => error.vk_error_video_profile_operation_not_supported_khr,
        c.VK_ERROR_VIDEO_PROFILE_FORMAT_NOT_SUPPORTED_KHR => error.vk_error_video_profile_format_not_supported_khr,
        c.VK_ERROR_VIDEO_PROFILE_CODEC_NOT_SUPPORTED_KHR => error.vk_error_video_profile_codec_not_supported_khr,
        c.VK_ERROR_VIDEO_STD_VERSION_NOT_SUPPORTED_KHR => error.vk_error_video_std_version_not_supported_khr,
        c.VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT => error.vk_error_invalid_drm_format_modifier_plane_layout_ext,
        c.VK_ERROR_NOT_PERMITTED_KHR => error.vk_error_not_permitted_khr,
        c.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT => error.vk_error_full_screen_exclusive_mode_lost_ext,
        c.VK_THREAD_IDLE_KHR => error.vk_thread_idle_khr,
        c.VK_THREAD_DONE_KHR => error.vk_thread_done_khr,
        c.VK_OPERATION_DEFERRED_KHR => error.vk_operation_deferred_khr,
        c.VK_OPERATION_NOT_DEFERRED_KHR => error.vk_operation_not_deferred_khr,
        c.VK_ERROR_COMPRESSION_EXHAUSTED_EXT => error.vk_error_compression_exhausted_ext,
        c.VK_ERROR_INCOMPATIBLE_SHADER_BINARY_EXT => error.vk_error_incompatible_shader_binary_ext,
        else => error.vk_errror_unknown,
    };
}
