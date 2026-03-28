const std = @import("std");

const Camera = @import("camera.zig").Camera;
const InputState = @import("input.zig").InputState;
const rl = @import("rl.zig").raylib;
const World = @import("world.zig").World;
const Ui = @import("ui.zig").Ui;
const Rectangle = @import("primitives.zig").Rectangle;
const Color = @import("primitives.zig").Color;

pub fn main(init: std.process.Init) !void {
    rl.InitWindow(800, 600, "zi");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    const allocator = init.gpa;

    var world = World.init(allocator, 0xdead);
    defer world.deinit();

    var camera = Camera.init(.{ 0, 0 });

    var ui = Ui.init();

    while (!rl.WindowShouldClose()) {
        // input
        var input = InputState{
            .move_direction = .{ 0, 0 },
            .zoom_direction = 0,
        };

        if (rl.IsKeyDown(rl.KEY_W)) input.move_direction[1] -= 1.0;
        if (rl.IsKeyDown(rl.KEY_S)) input.move_direction[1] += 1.0;
        if (rl.IsKeyDown(rl.KEY_A)) input.move_direction[0] -= 1.0;
        if (rl.IsKeyDown(rl.KEY_D)) input.move_direction[0] += 1.0;

        input.zoom_direction = rl.GetMouseWheelMove();

        // chunks
        const viewport = camera.getViewport();
        try world.loadVisibleChunks(viewport);
        try world.unloadDistantChunks(viewport);

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            const mouse_pos = rl.GetMousePosition();

            if (world.getTileAtScreenPosition(mouse_pos, &camera)) |hit| {
                const chunk = world.chunks.getPtr(hit.chunk_pos).?;

                if (chunk.tiles[hit.tile_index]) |tile| {
                    if (tile.kind == .iron) {
                        try world.active_drills.put(hit.toGlobalTilePosition(), .{});
                    }
                }
            }
        }

        // update state
        camera.update(input);
        try world.update();

        {
            rl.BeginDrawing();
            defer rl.EndDrawing();

            rl.ClearBackground(rl.BLACK);

            {
                rl.BeginMode2D(camera.rl_camera);
                defer rl.EndMode2D();

                world.draw(&camera);
            }

            // ui
            ui.panel(Rectangle.init(0, 0, 800, 100), Color.init(20, 20, 40, 255));

            if (ui.button(Rectangle.init(10, 10, 60, 20), "Drill").is_clicked) {
                // ...
            }

            // rl.DrawFPS(10, 10);
        }
    }
}
