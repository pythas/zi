const std = @import("std");

const Camera = @import("camera.zig").Camera;
const InputState = @import("player.zig").InputState;
const fastnoise = @import("libs/fastnoise.zig");
const Player = @import("player.zig").Player;
const Rectangle = @import("primitives.zig").Rectangle;
const Vec2 = @import("primitives.zig").Vec2;
const Vec2i = @import("primitives.zig").Vec2i;
const World = @import("world.zig").World;

const rl = @import("rl.zig").raylib;

pub fn main(init: std.process.Init) !void {
    rl.InitWindow(800, 600, "zi");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    const allocator = init.gpa;

    var world = World.init(allocator, 0xdead);
    defer world.deinit();

    var player = Player.init(.{ 0, 0 });
    var camera = Camera.init(.{ 0, 0 });

    while (!rl.WindowShouldClose()) {
        var input = InputState{
            .move_direction = .{ 0, 0 },
        };

        if (rl.IsKeyDown(rl.KEY_W)) input.move_direction[1] -= 1.0;
        if (rl.IsKeyDown(rl.KEY_S)) input.move_direction[1] += 1.0;
        if (rl.IsKeyDown(rl.KEY_A)) input.move_direction[0] -= 1.0;
        if (rl.IsKeyDown(rl.KEY_D)) input.move_direction[0] += 1.0;

        try world.loadVisibleChunks(&camera);

        player.update(input);
        camera.follow(player.position);

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.RAYWHITE);

        rl.BeginMode2D(camera.rl_camera);

        world.draw(&camera);

        rl.EndMode2D();

        rl.DrawFPS(10, 10);
    }
}
