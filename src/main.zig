const std = @import("std");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});

    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        std.debug.print("Failed to initialize SDL: {s}\n", .{sdl.SDL_GetError()});
        return;
    }

    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow(
        "Hello, SDL!".ptr,
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        600,
        800,
        sdl.SDL_WINDOW_SHOWN,
    );

    if (window == null) {
        std.debug.print("Failed to create window: {s}\n", .{sdl.SDL_GetError()});
        return;
    }

    defer sdl.SDL_DestroyWindow(window);

    const windowSurface = sdl.SDL_GetWindowSurface(window);

    _ = (sdl.SDL_FillRect(windowSurface, null, sdl.SDL_MapRGB(windowSurface.*.format, 0x2f, 0xf3, 0xbf)) != 0);

    _ = sdl.SDL_UpdateWindowSurface(window);

    var e: sdl.SDL_Event = undefined;
    var quit: bool = false;

    while (quit == false) {
        while (sdl.SDL_PollEvent(&e) != 0) {
            if (e.type == sdl.SDL_QUIT) {
                quit = true;
            }
        }
    }
}
