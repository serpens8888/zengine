const std = @import("std");

const c = @import("clibs.zig");

const vk = @import("vulkan.zig");

const audio = @import("audio/audio.zig");

const log = std.log.scoped(.main);

pub fn main() !void {
    std.debug.print("Hello, World!\n\n", .{});

    const playback_device: c.ma_device = try audio.setup_audio();
    _ = playback_device;

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != true) {
        log.err("SDL init failed", .{});
    }
    log.info("initialized SDL3", .{});

    const window = c.SDL_CreateWindow("zengine window", 600, 600, c.SDL_WINDOW_VULKAN);
    log.info("created SDL window", .{});

    const instance = try vk.get_vk_instance();

    var event: c.SDL_Event = undefined;
    var running: bool = true;
    while (running) {
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    running = false;
                    break;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    if (event.key.key == c.SDLK_ESCAPE) {
                        running = false;
                        break;
                    }
                },
                else => {},
            }
        }

        // simulate
    }

    try vk.destroy_vk_instance(instance);
    c.SDL_DestroyWindow(window);
    log.info("destroyed window", .{});
    c.SDL_Quit();
    log.info("quit sdl", .{});
}
