const std = @import("std");

const InputState = @import("input.zig").InputState;
const Rectangle = @import("primitives.zig").Rectangle;
const rl = @import("rl.zig").raylib;
const Vec2 = @import("primitives.zig").Vec2;
const Vec2i = @import("primitives.zig").Vec2i;

pub const Camera = struct {
    rl_camera: rl.Camera2D,

    const zoom_step = 0.1;
    const base_pad_speed = 10.0;

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
        const pan_speed = base_pad_speed / self.rl_camera.zoom;
        self.rl_camera.target.x += input.move_direction[0] * pan_speed;
        self.rl_camera.target.y += input.move_direction[1] * pan_speed;

        self.rl_camera.zoom += input.zoom_direction * zoom_step;
        self.rl_camera.zoom = std.math.clamp(self.rl_camera.zoom, 0.2, 3.0);
    }
};
