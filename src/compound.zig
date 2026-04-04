const std = @import("std");

const Building = @import("building.zig").Building;
const Vec2i = @import("primitives.zig").Vec2i;
const World = @import("world.zig").World;
const Event = @import("event.zig").Event;

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

    pub fn update(self: *Self, dt: f32, world: *World, events: *std.ArrayList(Event)) !void {
        var unload_list: std.ArrayList(Vec2i) = .empty;
        defer unload_list.deinit(self.allocator);

        var it = self.buildings.iterator();
        while (it.next()) |entry| {
            const position = entry.key_ptr.*;
            var building = entry.value_ptr;

            const should_destroy = try building.update(self.allocator, position, dt, world, events);

            if (should_destroy) {
                try unload_list.append(self.allocator, position);
            }
        }

        for (unload_list.items) |pos| {
            _ = self.buildings.remove(pos);
        }
    }
};
