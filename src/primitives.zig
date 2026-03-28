const rl = @import("rl.zig").raylib;

pub const Vec2 = @Vector(2, f32);
pub const Vec2i = @Vector(2, i32);

pub const Rectangle = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    const Self = @This();

    pub fn init(x: f32, y: f32, width: f32, height: f32) Self {
        return .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }

    pub fn collides(self: Self, other: Self) bool {
        return rl.CheckCollisionRecs(@bitCast(self), @bitCast(other));
    }
};

pub const Color = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,

    const Self = @This();

    pub fn init(r: u8, g: u8, b: u8, a: u8) Self {
        return .{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};
