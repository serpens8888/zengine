const std = @import("std");

pub fn ring_buffer(T: type) type {
    return struct {
        const Self = @This();
        len: usize = 0,
        read_index: usize = 0,
        write_index: usize = 0,
        buffer: []T = undefined,
        allocator: std.mem.Allocator = undefined,

        pub fn init(self: *Self, N: usize, allocator: std.mem.Allocator) !void {
            self.len = N;
            self.buffer = try allocator.alloc(T, N);
            self.allocator = allocator;
        }

        pub fn deinit(self: *Self) !void {
            self.allocator.free(self.buffer);
        }

        pub fn read(self: *Self) T {
            const value = self.buffer[self.read_index];
            self.read_index = (self.read_index + 1) % (self.len);
            return value;
        }

        pub fn write(self: *Self, value: *T) !void {
            self.buffer[self.write_index] = value.*;
            self.write_index = (self.write_index + 1) % (self.len);
        }
    };
}
