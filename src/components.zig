const std = @import("std");

const Slot = @import("inventory.zig").Slot;
const Vec2i = @import("primitives.zig").Vec2i;
const Color = @import("primitives.zig").Color;
const ResourceKind = @import("inventory.zig").ResourceKind;

pub const Timer = struct {
    timer: f32,
    duration: f32,
    is_active: bool,

    const Self = @This();

    pub fn init(duration: f32) Self {
        return .{
            .timer = 0.0,
            .duration = duration,
            .is_active = true,
        };
    }
};

pub const Drill = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }
};

pub const Smelter = struct {
    processing: ?Slot,

    const Self = @This();

    pub fn init() Self {
        return .{
            .processing = null,
        };
    }
};

pub const Direction = enum {
    north,
    south,
    east,
    west,

    const Self = @This();

    pub fn toVec(self: Self) Vec2i {
        return switch (self) {
            .north => .{ 0, -1 },
            .south => .{ 0, 1 },
            .east => .{ 1, 0 },
            .west => .{ -1, 0 },
        };
    }

    pub fn rotatedCW(self: Self) Self {
        return switch (self) {
            .north => .east,
            .east => .south,
            .south => .west,
            .west => .north,
        };
    }

    pub fn rotatedCCW(self: Self) Self {
        return switch (self) {
            .north => .west,
            .west => .south,
            .south => .east,
            .east => .north,
        };
    }
};

pub const Inventory = struct {
    input: ?Slot,
    output: ?Slot,
    input_buffer: ?Slot,
    output_buffer: ?Slot,
    max_input: u32,
    max_output: u32,
    accepted_inputs: std.EnumSet(ResourceKind),

    const Self = @This();

    pub fn init(max_input: u32, max_output: u32) Self {
        return .{
            .input = null,
            .output = null,
            .input_buffer = null,
            .output_buffer = null,
            .max_input = max_input,
            .max_output = max_output,
            .accepted_inputs = std.EnumSet(ResourceKind).initEmpty(),
        };
    }

    pub fn getInputAmount(self: Self) u32 {
        const input_amount = if (self.input) |slot| slot.amount else 0;
        const input_buffer_amount = if (self.input_buffer) |slot| slot.amount else 0;

        return input_amount + input_buffer_amount;
    }

    pub fn getOutputAmount(self: Self) u32 {
        const output_amount = if (self.output) |slot| slot.amount else 0;
        const output_buffer_amount = if (self.output_buffer) |slot| slot.amount else 0;

        return output_amount + output_buffer_amount;
    }
};

pub const Selectable = struct {
    is_selected: bool,

    const Self = @This();

    pub fn init() Self {
        return .{
            .is_selected = false,
        };
    }
};

pub const Renderable = struct {
    color: Color,

    const Self = @This();

    pub fn init(color: Color) Self {
        return .{
            .color = color,
        };
    }
};
