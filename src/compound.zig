const std = @import("std");

const Building = @import("building.zig").Building;
const Vec2i = @import("primitives.zig").Vec2i;
const World = @import("world.zig").World;
const Event = @import("event.zig").Event;
const Drill = @import("building.zig").Drill;
const Smelter = @import("building.zig").Smelter;
const Camera = @import("camera.zig").Camera;
const GridBounds = @import("world.zig").GridBounds;

pub const Compound = struct {
    allocator: std.mem.Allocator,
    buildings: std.AutoHashMap(Vec2i, Building),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .buildings = std.AutoHashMap(Vec2i, Building).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.buildings.deinit();
    }

    pub fn update(
        self: *Self,
        dt: f32,
        world: *World,
    ) !void {
        var unload_list: std.ArrayList(Vec2i) = .empty;
        defer unload_list.deinit(self.allocator);

        var it = self.buildings.iterator();
        while (it.next()) |entry| {
            const position = entry.key_ptr.*;
            var building = entry.value_ptr;

            // const should_destroy = try building.update(position, dt, world);
            //
            // if (should_destroy) {
            //     try unload_list.append(self.allocator, position);
            // }

            // tick
            try building.update(position, dt, world);

            // get output
            const output_ptr = building.getOutputPtr();

            if (output_ptr.*) |*output| {
                var buffer: [4]*Building = undefined;
                const adj_building_ptrs = self.getAdjacentBuildingsPtr(position, &buffer);

                for (adj_building_ptrs) |adj_building_ptr| {
                    const neighbor_input_ptr = adj_building_ptr.getInputPtr();

                    if (neighbor_input_ptr.* == null) {
                        neighbor_input_ptr.* = output.*;

                        std.debug.print("{?}\n", .{neighbor_input_ptr.*});

                        output_ptr.* = null;

                        break;
                    }
                }
            }
        }

        for (unload_list.items) |pos| {
            _ = self.buildings.remove(pos);
        }
    }

    pub fn draw(self: *Self, bounds: GridBounds) void {
        var it = self.buildings.iterator();
        while (it.next()) |entry| {
            const pos = entry.key_ptr.*;

            if (pos[0] >= bounds.min_x and pos[0] <= bounds.max_x and
                pos[1] >= bounds.min_y and pos[1] <= bounds.max_y)
            {
                const building = entry.value_ptr;

                building.draw(pos);
            }
        }
    }

    pub fn getBuildingPtr(self: *Self, pos: Vec2i) ?*Building {
        return self.buildings.getPtr(pos);
    }

    pub fn getAdjacentBuildingsPtr(self: *Self, pos: Vec2i, buffer: *[4]*Building) []*Building {
        var count: usize = 0;
        const directions = [_]Vec2i{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };

        for (directions) |dir| {
            const neighbor_pos = Vec2i{ pos[0] + dir[0], pos[1] + dir[1] };

            if (self.buildings.getPtr(neighbor_pos)) |building| {
                buffer[count] = building;
                count += 1;
            }
        }

        return buffer[0..count];
    }

    pub fn placeDrill(self: *Self, world: *World, pos: Vec2i) !bool {
        if (self.buildings.contains(pos)) return false;

        const tile = world.getTile(pos) orelse return false;

        if (tile.kind != .iron) return false;

        try self.buildings.put(pos, .{ .drill = Drill.init(self.allocator, 1.0) });
        std.debug.print("Drill placed at {d}, {d}\n", .{ pos[0], pos[1] });

        return true;
    }

    pub fn placeSmelter(self: *Self, world: *World, pos: Vec2i) !bool {
        _ = world;

        if (self.buildings.contains(pos)) return false;

        // var buffer: [4]*Building = undefined;
        // const adj_building_ptrs = self.getAdjacentBuildingsPtr(pos, &buffer);
        //
        // var is_next_to_drill = false;
        // for (adj_building_ptrs) |adj_building_ptr| {
        //     switch (adj_building_ptr.*) {
        //         .drill => {
        //             is_next_to_drill = true;
        //             break;
        //         },
        //         else => {},
        //     }
        // }
        //
        // if (!is_next_to_drill) return false;

        try self.buildings.put(pos, .{ .smelter = Smelter.init(self.allocator, 1.0) });
        std.debug.print("Smelter placed at {d}, {d}\n", .{ pos[0], pos[1] });

        return true;
    }
};
