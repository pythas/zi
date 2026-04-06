const std = @import("std");

const GridBounds = @import("world.zig").GridBounds;
const Regsitry = @import("registry.zig").Registry;
const Color = @import("primitives.zig").Color;
const Vec2i = @import("primitives.zig").Vec2i;
const ResourceKind = @import("inventory.zig").ResourceKind;
const World = @import("world.zig").World;
const Tile = @import("world.zig").Tile;
const rl = @import("rl.zig").raylib;

pub fn updateTimers(registry: *Regsitry, dt: f32) void {
    var it = registry.timers.iterator();
    while (it.next()) |entry| {
        var timer = entry.value_ptr;

        if (!timer.is_active) continue;

        timer.timer += dt;
    }
}

pub fn updateDrills(registry: *Regsitry, world: *World) void {
    var it = registry.drills.iterator();
    while (it.next()) |entry| {
        const position = entry.key_ptr.*;

        var timer = registry.timers.getPtr(position) orelse continue;
        var inventory = registry.inventories.getPtr(position) orelse continue;

        if (timer.timer >= timer.duration) {
            const output_amount = if (inventory.output) |slot| slot.amount else 0;
            const output_buffer_amount = if (inventory.output_buffer) |slot| slot.amount else 0;
            const total_output = output_amount + output_buffer_amount;

            if (total_output >= inventory.max_output) {
                timer.timer = timer.duration;
                return;
            }

            timer.timer -= timer.duration;

            const mined_kind = world.mineTile(position) orelse return;
            const resource = mined_kind.toResource() orelse return;

            std.debug.print("[Drill] Mined 1 {s} at {d}, {d}\n", .{ @tagName(resource), position[0], position[1] });

            if (inventory.output_buffer) |*output_buffer| {
                output_buffer.amount += 1;
                std.debug.print("[Drill] Buffer incremented. Now holding: {d} {s}\n", .{ output_buffer.amount, @tagName(output_buffer.resource) });
            } else {
                inventory.output_buffer = .{
                    .resource = resource,
                    .amount = 1,
                };
                std.debug.print("[Drill] Buffer initialized with 1 {s}\n", .{@tagName(resource)});
            }
        }

        if (inventory.output_buffer) |*output_buffer| {
            if (output_buffer.amount == 0) return;
            if (inventory.output != null) return;

            inventory.output = .{
                .resource = output_buffer.resource,
                .amount = 1,
            };

            output_buffer.amount -= 1;
            std.debug.print("[Drill] Moved 1 {s} to output. Buffer remaining: {d}\n", .{ @tagName(output_buffer.resource), output_buffer.amount });

            if (output_buffer.amount == 0) {
                inventory.output_buffer = null;
                std.debug.print("[Drill] Buffer is now empty.\n", .{});
            }
        }
    }
}

pub fn updateSmelters(registry: *Regsitry) void {
    var it = registry.smelters.iterator();
    while (it.next()) |entry| {
        const position = entry.key_ptr.*;
        const smelter = entry.value_ptr;

        var timer = registry.timers.getPtr(position) orelse continue;
        var inventory = registry.inventories.getPtr(position) orelse continue;

        // push to output
        if (inventory.output_buffer) |*output_buffer| {
            if (inventory.output == null and output_buffer.amount > 0 and output_buffer.amount < inventory.max_output) {
                inventory.output = .{ .resource = output_buffer.resource, .amount = 1 };
                output_buffer.amount -= 1;

                std.debug.print("[Smelter] Pushed 1 {s} to output.\n", .{@tagName(output_buffer.resource)});

                if (output_buffer.amount == 0) inventory.output_buffer = null;
            }
        }

        if (smelter.processing) |processing| {
            if (timer.timer >= timer.duration) {
                const result_resource: ResourceKind = switch (processing.resource) {
                    .raw_iron => .iron_ingot,
                    else => unreachable,
                };

                var output_successful = false;

                if (inventory.output_buffer == null) {
                    inventory.output_buffer = .{ .resource = result_resource, .amount = 1 };
                    output_successful = true;
                } else if (inventory.output_buffer.?.resource == result_resource) {
                    const output_amount = if (inventory.output) |slot| slot.amount else 0;
                    const output_buffer_amount = if (inventory.output_buffer) |slot| slot.amount else 0;
                    const total_output = output_buffer_amount + output_amount;

                    if (total_output < inventory.max_output) {
                        inventory.output_buffer.?.amount += 1;
                        output_successful = true;
                    } else {
                        output_successful = false;
                    }
                }

                if (output_successful) {
                    std.debug.print("[Smelter] Finished smelting 1 {s}!\n", .{@tagName(result_resource)});
                    smelter.processing = null;
                    timer.timer -= timer.duration;
                    timer.is_active = false;
                } else {
                    timer.timer = timer.duration;
                }
            }
        } else {
            // nothing is processing. grab from input_buffer
            if (inventory.input_buffer) |*input_buffer| {
                if (input_buffer.amount > 0) {
                    smelter.processing = .{ .resource = input_buffer.resource, .amount = 1 };
                    input_buffer.amount -= 1;
                    timer.timer = 0.0;
                    timer.is_active = true;

                    std.debug.print("[Smelter] Started smelting 1 {s}...\n", .{@tagName(input_buffer.resource)});

                    if (input_buffer.amount == 0) inventory.input_buffer = null;
                }
            }
        }

        // pull from input
        if (inventory.input) |input| {
            const input_buffer_amount = if (inventory.input_buffer) |slot| slot.amount else 0;
            const total_input = input.amount + input_buffer_amount;

            if (total_input < inventory.max_input) {
                if (inventory.input_buffer == null) {
                    inventory.input_buffer = input;
                    inventory.input = null;
                    std.debug.print("[Smelter] Pulled {d} {s} into input buffer.\n", .{ input.amount, @tagName(input.resource) });
                } else if (inventory.input_buffer.?.resource == input.resource) {
                    inventory.input_buffer.?.amount += input.amount;
                    inventory.input = null;
                    std.debug.print("[Smelter] Pulled {d} {s} into input buffer.\n", .{ input.amount, @tagName(input.resource) });
                }
            }
        }
    }
}

pub fn updateInventories(registry: *Regsitry) void {
    var it = registry.inventories.iterator();
    while (it.next()) |entry| {
        const position = entry.key_ptr.*;
        const inventory = entry.value_ptr;

        const output = inventory.output orelse continue;
        const direction = registry.orientations.get(position) orelse continue;
        const adj_inventory = registry.getAdjacentInventoryPtr(position, direction) orelse continue;

        if (adj_inventory.input != null) continue;

        if (!adj_inventory.accepted_inputs.contains(output.resource)) {
            continue;
        }

        adj_inventory.input = output;
        inventory.output = null;
    }
}

pub fn renderBuildings(registry: *Regsitry, bounds: GridBounds) void {
    var it = registry.renderables.iterator();
    while (it.next()) |entry| {
        const position = entry.key_ptr.*;
        const renderable = entry.value_ptr;

        if (!inBounds(position, bounds)) continue;

        const draw_pos = World.gridToWorld(position);

        rl.DrawRectangleRec(
            .{
                .x = draw_pos[0],
                .y = draw_pos[1],
                .width = Tile.size,
                .height = Tile.size,
            },
            @bitCast(renderable.color),
        );
    }
}

pub fn renderOrientations(registry: *Regsitry, bounds: GridBounds) void {
    var it = registry.orientations.iterator();
    while (it.next()) |entry| {
        const position = entry.key_ptr.*;
        const direction = entry.value_ptr.*;

        if (!inBounds(position, bounds)) continue;

        const draw_pos = World.gridToWorld(position);

        const center_x = draw_pos[0] + (Tile.size / 2.0);
        const center_y = draw_pos[1] + (Tile.size / 2.0);

        const offset = Tile.size / 8.0;

        var v1: rl.Vector2 = undefined;
        var v2: rl.Vector2 = undefined;
        var v3: rl.Vector2 = undefined;

        switch (direction) {
            .north => {
                v1 = .{ .x = center_x, .y = center_y - offset };
                v2 = .{ .x = center_x - offset, .y = center_y + offset };
                v3 = .{ .x = center_x + offset, .y = center_y + offset };
            },
            .south => {
                v1 = .{ .x = center_x, .y = center_y + offset };
                v2 = .{ .x = center_x + offset, .y = center_y - offset };
                v3 = .{ .x = center_x - offset, .y = center_y - offset };
            },
            .east => {
                v1 = .{ .x = center_x + offset, .y = center_y };
                v2 = .{ .x = center_x - offset, .y = center_y - offset };
                v3 = .{ .x = center_x - offset, .y = center_y + offset };
            },
            .west => {
                v1 = .{ .x = center_x - offset, .y = center_y };
                v2 = .{ .x = center_x + offset, .y = center_y + offset };
                v3 = .{ .x = center_x + offset, .y = center_y - offset };
            },
        }

        rl.DrawTriangle(v1, v2, v3, rl.WHITE);
    }
}

pub fn renderSelections(registry: *Regsitry, bounds: GridBounds) void {
    var it = registry.selectables.iterator();
    while (it.next()) |entry| {
        const position = entry.key_ptr.*;
        const selectable = entry.value_ptr;

        if (!selectable.is_selected) continue;
        if (!inBounds(position, bounds)) continue;

        const draw_pos = World.gridToWorld(position);

        rl.DrawRectangleLinesEx(
            .{
                .x = draw_pos[0],
                .y = draw_pos[1],
                .width = Tile.size,
                .height = Tile.size,
            },
            2,
            @bitCast(Color.init(255, 255, 255, 100)),
        );
    }
}

fn inBounds(position: Vec2i, bounds: GridBounds) bool {
    return position[0] >= bounds.min_x and position[0] <= bounds.max_x and
        position[1] >= bounds.min_y and position[1] <= bounds.max_y;
}
