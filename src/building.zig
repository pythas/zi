const std = @import("std");

const Event = @import("event.zig").Event;
const Vec2i = @import("primitives.zig").Vec2i;
const World = @import("world.zig").World;

pub const Drill = struct {
    timer: f32,
    duration: f32,

    const Self = @This();

    pub fn init(duration: f32) Self {
        return .{
            .timer = 0.0,
            .duration = duration,
        };
    }

    pub fn getProgress(self: *Self) f32 {
        return @min(1.0, self.timer / self.duration);
    }

    pub fn update(
        self: *Self,
        allocator: std.mem.Allocator,
        pos: Vec2i,
        dt: f32,
        world: *World,
        events: *std.ArrayList(Event),
    ) !bool {
        self.timer += dt;

        if (self.timer >= self.duration) {
            self.timer -= self.duration;

            if (world.mineTile(pos)) |mined_tile| {
                if (mined_tile.toResource()) |resource| {
                    try events.append(allocator, .{ .resource_produced = .{ .resource = resource, .amount = 1 } });
                }
                return false;
            } else {
                return true;
            }
        }

        return false;
    }
};

pub const Building = union(enum) {
    drill: Drill,

    const Self = @This();

    pub fn update(
        self: *Self,
        allocator: std.mem.Allocator,
        position: Vec2i,
        dt: f32,
        world: *World,
        events: *std.ArrayList(Event),
    ) !bool {
        return switch (self.*) {
            .drill => |*d| try d.update(allocator, position, dt, world, events),
        };
    }
};
