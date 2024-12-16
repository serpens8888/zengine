const std = @import("std");
const c = @import("../clibs.zig");

pub const playback_device_config = struct {
    format: c.ma_uint32 = c.ma_format_f32,
    channel_count: usize = 2,
    sample_rate: usize = 48000,
    frame_size: usize = 480,
    data_callback: fn (?*anyopaque, ?*anyopaque, ?*const anyopaque, c.ma_uint32) callconv(.C) void = undefined,
    user_data: ?*anyopaque = undefined,
};

pub fn get_playback_device(config: playback_device_config) !c.ma_device {
    var device: c.ma_device = std.mem.zeroes(c.ma_device);

    var device_config: c.ma_device_config = c.ma_device_config_init(c.ma_device_type_playback);
    device_config.playback.format = config.format;
    device_config.playback.channels = config.channel_count;
    device_config.sampleRate = config.sample_rate;
    device_config.periodSizeInFrames = config.frame_size;
    device_config.dataCallback = config.data_callback;
    device_config.pUserData = config.user_data;

    if (c.ma_device_init(null, &device_config, &device) != c.MA_SUCCESS) {
        return error.failed_to_init_device;
    }

    return device;
}

pub fn destroy_playback_device(device: *c.ma_device) !void {
    if (c.ma_device_uninit(device) != c.MA_SUCCESS) {
        return error.failed_to_destroy_device;
    }
}

pub fn start_playback(device: *c.ma_device) !void {
    if (c.ma_device_start(device) != c.MA_SUCCESS) {
        c.ma_device_uninit(device);
        return error.failed_to_start_device;
    }
}

pub fn end_playback(device: *c.ma_device) !void {
    if (c.ma_device_stop(device) != c.MA_SUCCESS) {
        return error.failed_to_stop_device;
    }
}
