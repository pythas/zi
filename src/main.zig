const std = @import("std");

const Camera = @import("camera.zig").Camera;
const Color = @import("primitives.zig").Color;
const Regsitry = @import("registry.zig").Registry;
const Drill = @import("components.zig").Drill;
const Event = @import("event.zig").Event;
const InputState = @import("input.zig").InputState;
const Rectangle = @import("primitives.zig").Rectangle;
const Vec2i = @import("primitives.zig").Vec2i;
const rl = @import("rl.zig").raylib;
const Ui = @import("ui.zig").Ui;
const World = @import("world.zig").World;

pub const Tool = enum {
    drill,
    smelter,
};

pub fn main(init: std.process.Init) !void {
    rl.InitWindow(800, 600, "zi");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    const allocator = init.gpa;

    var world = try World.init(allocator, 0xdead);
    defer world.deinit();

    var registry = Regsitry.init(allocator);
    defer registry.deinit();

    // var events: std.ArrayList(Event) = .empty;
    // defer events.deinit(allocator);

    var camera = Camera.init(.{ 0, 0 });

    // var inventory = Inventory.init();

    var active_tool: Tool = .drill;

    var ui = Ui.init();
    var inspected: ?Vec2i = null;

    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();

        // input
        var input_state = InputState{
            .move_direction = .{ 0, 0 },
            .zoom_direction = 0,
        };

        if (rl.IsKeyDown(rl.KEY_W)) input_state.move_direction[1] -= 1.0;
        if (rl.IsKeyDown(rl.KEY_S)) input_state.move_direction[1] += 1.0;
        if (rl.IsKeyDown(rl.KEY_A)) input_state.move_direction[0] -= 1.0;
        if (rl.IsKeyDown(rl.KEY_D)) input_state.move_direction[0] += 1.0;

        input_state.zoom_direction = rl.GetMouseWheelMove();

        if (rl.IsKeyPressed(rl.KEY_R)) {
            const mouse_pos = rl.GetMousePosition();
            const grid_pos = World.screenToGrid(mouse_pos, &camera);

            if (registry.orientations.getPtr(grid_pos)) |direction| {
                if (rl.IsKeyDown(rl.KEY_LEFT_SHIFT)) {
                    direction.* = direction.rotatedCCW();
                } else {
                    direction.* = direction.rotatedCW();
                }
            }
        }

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            const mouse_pos = rl.GetMousePosition();
            const grid_pos = World.screenToGrid(mouse_pos, &camera);

            if (registry.selectables.getPtr(grid_pos)) |selectable| {
                if (inspected) |old_pos| {
                    if (old_pos[0] != grid_pos[0] or old_pos[1] != grid_pos[1]) {
                        if (registry.selectables.getPtr(old_pos)) |old_selectable| {
                            old_selectable.is_selected = false;
                        }
                    }
                }

                selectable.is_selected = true;
                inspected = grid_pos;
            } else {
                if (inspected) |old_pos| {
                    if (registry.selectables.getPtr(old_pos)) |old_selectable| {
                        old_selectable.is_selected = false;
                    }
                    inspected = null;
                }

                const has_placed_building = switch (active_tool) {
                    .drill => try registry.placeDrill(&world, grid_pos),
                    .smelter => try registry.placeSmelter(grid_pos),
                };

                if (has_placed_building) {
                    inspected = grid_pos;

                    if (registry.selectables.getPtr(grid_pos)) |selectable| {
                        selectable.is_selected = true;
                    }
                }
            }
        }

        // update state
        camera.update(input_state);
        try registry.update(dt, &world);

        // handle events
        // for (events.items) |event| {
        //     switch (event) {
        //         .resource_produced => |data| {
        //             const current_amount = inventory.items.get(data.resource) orelse 0;
        //
        //             inventory.items.put(data.resource, current_amount + data.amount);
        //
        //             std.debug.print("Inventory now has {d} {s}\n", .{ current_amount + data.amount, @tagName(data.resource) });
        //         },
        //     }
        // }
        // events.clearRetainingCapacity();

        const viewport = camera.getViewport();
        const grid_bounds = World.getBounds(viewport, 3.0);

        {
            rl.BeginDrawing();
            defer rl.EndDrawing();

            rl.ClearBackground(rl.BLACK);

            {
                rl.BeginMode2D(camera.rl_camera);
                defer rl.EndMode2D();

                world.draw(grid_bounds);
                registry.draw(grid_bounds);
            }

            // ui
            ui.panel(Rectangle.init(0, 0, 800, 40), Color.init(20, 20, 40, 255));

            if (ui.button(Rectangle.init(10, 10, 60, 20), active_tool == .drill, "Drill").is_clicked) {
                active_tool = .drill;
            }

            if (ui.button(Rectangle.init(80, 10, 60, 20), active_tool == .smelter, "Smelter").is_clicked) {
                active_tool = .smelter;
            }

            // {
            //     var buffer: [64]u8 = undefined;
            //     const text = try std.fmt.bufPrintZ(&buffer, "Raw iron: {d}", .{inventory.items.get(.raw_iron).?});
            //     ui.label(.{ 200, 10 }, text, 10, Color.init(230, 230, 230, 255));
            // }

            if (inspected) |building_pos| {
                if (registry.inventories.get(building_pos)) |inventory| {
                    ui.panel(Rectangle.init(600, 40, 200, 600), Color.init(20, 20, 40, 255));

                    const input_amount = inventory.getInputAmount();
                    const output_amount = inventory.getOutputAmount();

                    {
                        var buffer: [64]u8 = undefined;
                        const text = try std.fmt.bufPrintZ(&buffer, "Input: {d}", .{input_amount});
                        ui.label(.{ 610, 50 }, text, 10, Color.init(230, 230, 230, 255));
                    }

                    {
                        var buffer: [64]u8 = undefined;
                        const text = try std.fmt.bufPrintZ(&buffer, "Output: {d}", .{output_amount});
                        ui.label(.{ 610, 60 }, text, 10, Color.init(230, 230, 230, 255));
                    }
                }
            }

            // rl.DrawFPS(10, 10);
        }
    }
}
