const std = @import("std");

const Rectangle = @import("primitives.zig").Rectangle;
const Vec2 = @import("primitives.zig").Vec2;
const Vec2i = @import("primitives.zig").Vec2i;
const InputState = @import("player.zig").InputState;

const rl = @import("rl.zig").raylib;

pub const Camera = struct {
    rl_camera: rl.Camera2D,

    const zoom_speed = 0.1;

    const Self = @This();

    pub fn init(target_position: Vec2) Self {
        return .{
            .rl_camera = .{
                .offset = .{ .x = 400.0, .y = 300.0 },
                .target = .{ .x = target_position[0], .y = target_position[1] },
                .rotation = 0.0,
                .zoom = 1.0,
            },
        };
    }

    pub fn follow(self: *Self, target_pos: Vec2) void {
        self.rl_camera.target = .{
            .x = target_pos[0],
            .y = target_pos[1],
        };
    }

    pub fn getViewport(self: *Self) Rectangle {
        const top_left = rl.GetScreenToWorld2D(.{ .x = 0.0, .y = 0.0 }, self.rl_camera);
        const bottom_right = rl.GetScreenToWorld2D(.{ .x = 800.0, .y = 600.0 }, self.rl_camera);

        return Rectangle.init(
            top_left.x,
            top_left.y,
            bottom_right.x - top_left.x,
            bottom_right.y - top_left.y,
        );
    }

    pub fn update(self: *Self, input: InputState) void {
        self.rl_camera.zoom += input.zoom_direction * zoom_speed;
        self.rl_camera.zoom = std.math.clamp(self.rl_camera.zoom, 0.2, 3.0);
    }
};
