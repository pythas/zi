const std = @import("std");

const Event = @import("event.zig").Event;
const Vec2i = @import("primitives.zig").Vec2i;
const Color = @import("primitives.zig").Color;
const rl = @import("rl.zig").raylib;
const World = @import("world.zig").World;
const Tile = @import("world.zig").Tile;

pub const Drill = struct {
    allocator: std.mem.Allocator,
    timer: f32,
    duration: f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, duration: f32) Self {
        return .{
            .allocator = allocator,
            .timer = 0.0,
            .duration = duration,
        };
    }

    pub fn getProgress(self: *Self) f32 {
        return @min(1.0, self.timer / self.duration);
    }

    pub fn update(
        self: *Self,
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
                    try events.append(self.allocator, .{ .resource_produced = .{ .resource = resource, .amount = 1 } });
                }
                return false;
            } else {
                return true;
            }
        }

        return false;
    }

    pub fn draw(_: Self, pos: Vec2i) void {
        const color = Color.init(255, 110, 64, 255);

        const draw_pos = World.gridToWorld(pos);

        rl.DrawRectangleRec(.{
            .x = draw_pos[0],
            .y = draw_pos[1],
            .width = Tile.size,
            .height = Tile.size,
        }, @bitCast(color));
    }
};

pub const Smelter = struct {
    allocator: std.mem.Allocator,
    timer: f32,
    duration: f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, duration: f32) Self {
        return .{
            .allocator = allocator,
            .timer = 0.0,
            .duration = duration,
        };
    }

    pub fn getProgress(self: *Self) f32 {
        return @min(1.0, self.timer / self.duration);
    }

    pub fn update(
        self: *Self,
        pos: Vec2i,
        dt: f32,
        world: *World,
        events: *std.ArrayList(Event),
    ) !bool {
        self.timer += dt;

        if (self.timer >= self.duration) {
            self.timer -= self.duration;

            _ = pos;
            _ = world;
            _ = events;

            // if (world.mineTile(pos)) |mined_tile| {
            //     if (mined_tile.toResource()) |resource| {
            //         try events.append(allocator, .{ .resource_produced = .{ .resource = resource, .amount = 1 } });
            //     }
            //     return false;
            // } else {
            //     return true;
            // }
        }

        return false;
    }

    pub fn draw(_: Self, pos: Vec2i) void {
        const color = Color.init(186, 255, 64, 255);

        const draw_pos = World.gridToWorld(pos);

        rl.DrawRectangleRec(.{
            .x = draw_pos[0],
            .y = draw_pos[1],
            .width = Tile.size,
            .height = Tile.size,
        }, @bitCast(color));
    }
};

pub const Building = union(enum) {
    drill: Drill,
    smelter: Smelter,

    const Self = @This();

    pub fn update(
        self: *Self,
        pos: Vec2i,
        dt: f32,
        world: *World,
        events: *std.ArrayList(Event),
    ) !bool {
        return switch (self.*) {
            .drill => |*d| try d.update(pos, dt, world, events),
            .smelter => |*s| try s.update(pos, dt, world, events),
        };
    }

    pub fn draw(self: *Self, pos: Vec2i) void {
        switch (self.*) {
            .drill => |d| d.draw(pos),
            .smelter => |s| s.draw(pos),
        }
    }
};
