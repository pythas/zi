const std = @import("std");

const Camera = @import("camera.zig").Camera;
const Color = @import("primitives.zig").Color;
const Drill = @import("world.zig").Drill;
const InputState = @import("input.zig").InputState;
const Rectangle = @import("primitives.zig").Rectangle;
const rl = @import("rl.zig").raylib;
const Ui = @import("ui.zig").Ui;
const World = @import("world.zig").World;

pub fn main(init: std.process.Init) !void {
    rl.InitWindow(800, 600, "zi");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    const allocator = init.gpa;

    var world = try World.init(allocator, 0xdead);
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

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            const mouse_pos = rl.GetMousePosition();
            const global_pos = World.screenToGrid(mouse_pos, &camera);

            if (world.getTile(global_pos)) |tile| {
                if (tile.kind == .iron) {
                    try world.active_drills.put(global_pos, Drill.init(10.0));
                    std.debug.print("Drill placed at {d}, {d}\n", .{ global_pos[0], global_pos[1] });
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
