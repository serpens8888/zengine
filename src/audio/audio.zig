const std = @import("std");
const c = @import("../clibs.zig");
const rb = @import("ring_buffer.zig");
const wf = @import("waveforms.zig");
const ma = @import("miniaudio.zig");

fn data_callback(device: ?*anyopaque, output: ?*anyopaque, input: ?*const anyopaque, frame_count: c.ma_uint32) callconv(.C) void {
    _ = device;
    _ = input;
    _ = output;
    _ = frame_count;

    //    const playback_device: *c.ma_device = @as(*c.ma_device, @ptrCast(@alignCast(device.?)));
    //
    //   const audio = @as(*rb.ring_buffer(f32), @alignCast(@ptrCast(playback_device.pUserData.?)));
    //
    //   const f_output: [*]f32 = @ptrCast(@alignCast(output.?));
    //   for (0..frame_count) |i| {
    //       const sample: f32 = audio.*.read();
    //       for (0..2) |j| {
    //           f_output[i * 2 + j] = sample;
    //       }
    //   }
}

pub fn setup_audio() !c.ma_device {
    const audio_device: c.ma_device = try ma.get_playback_device(.{
        .format = c.ma_format_f32,
        .channel_count = 2,
        .sample_rate = 48000,
        .frame_size = 480,
        .data_callback = data_callback,
        .user_data = undefined,
    });

    return audio_device;
}
