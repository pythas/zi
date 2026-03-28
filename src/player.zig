const std = @import("std");

const InputState = @import("input.zig").InputState;
const fastnoise = @import("libs/fastnoise.zig");
const Rectangle = @import("primitives.zig").Rectangle;
const Vec2 = @import("primitives.zig").Vec2;
const Vec2i = @import("primitives.zig").Vec2i;

pub const Player = struct {
    position: Vec2,
    speed: f32,

    const Self = @This();

    pub fn init(position: Vec2) Self {
        return .{
            .position = position,
            .speed = 5.0,
        };
    }

    pub fn update(self: *Self, input: InputState) void {
        const velocity = input.move_direction * @as(Vec2, @splat(self.speed));
        self.position = self.position + velocity;
    }
};
