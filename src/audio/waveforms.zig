const std = @import("std");

const rb = @import("ring_buffer.zig");

fn sine_approximation(x: f32) f32 {
    const a: f32 = @mod(x + 1, 2) - 1;
    return (4 * a) * (1 - @abs(a));
}
pub fn sine_wave(frequency: f32, amplitude: f32, allocator: std.mem.Allocator) !rb.ring_buffer(f32) {
    const len: f32 = (48000 / frequency);

    var instance: rb.ring_buffer(f32) = .{};
    try instance.init(@as(usize, @intFromFloat(@ceil(len))), allocator);

    for (0..instance.len + 1) |i| { // .. ranges are are not inclusive, must use +1
        const angle: f32 = 2 * @as(f32, @floatFromInt(i)) / len;
        var sample = sine_approximation(angle) * amplitude;
        try instance.write(&sample);
    }

    return instance;
}
