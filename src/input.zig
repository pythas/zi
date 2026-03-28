const Vec2 = @import("primitives.zig").Vec2;

pub const InputState = struct {
    move_direction: Vec2,
    zoom_direction: f32,
};
