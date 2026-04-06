// TODO: create a base struct Entity or something that contains direction, is_selected etc

const std = @import("std");

const Event = @import("event.zig").Event;
const Vec2i = @import("primitives.zig").Vec2i;
const Color = @import("primitives.zig").Color;
const rl = @import("rl.zig").raylib;
const World = @import("world.zig").World;
const Tile = @import("world.zig").Tile;
const ResourceKind = @import("inventory.zig").ResourceKind;

pub const Slot = struct {
    resource: ResourceKind,
    amount: u32,
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

    pub fn rotate(self: *Self) void {
        self.* = switch (self.*) {
            .north => .east,
            .east => .south,
            .south => .west,
            .west => .north,
        };
    }
};

pub const Drill = struct {
    allocator: std.mem.Allocator,
    timer: f32,
    duration: f32,
    direction: Direction,

    input: ?Slot,
    output: ?Slot,

    input_buffer: ?Slot,
    output_buffer: ?Slot,

    is_selected: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, duration: f32) Self {
        return .{
            .allocator = allocator,
            .timer = 0.0,
            .duration = duration,
            .direction = .north,
            .input = null,
            .output = null,
            .input_buffer = null,
            .output_buffer = null,
            .is_selected = false,
        };
    }

    pub fn getProgress(self: *Self) f32 {
        return @min(1.0, self.timer / self.duration);
    }

    // TODO: add local prop should_destroy instead of passing through update

    pub fn update(
        self: *Self,
        pos: Vec2i,
        dt: f32,
        world: *World,
    ) !void {
        self.timer += dt;

        if (self.timer >= self.duration) {
            self.timer -= self.duration;

            const mined_tile = world.mineTile(pos) orelse return;
            const resource = mined_tile.toResource() orelse return;

            std.debug.print("[Drill] Mined 1 {s} at {d}, {d}\n", .{ @tagName(resource), pos[0], pos[1] });

            if (self.output_buffer) |*output_buffer| {
                output_buffer.amount += 1;
                std.debug.print("[Drill] Buffer incremented. Now holding: {d} {s}\n", .{ output_buffer.amount, @tagName(output_buffer.resource) });
            } else {
                self.output_buffer = .{
                    .resource = resource,
                    .amount = 1,
                };
                std.debug.print("[Drill] Buffer initialized with 1 {s}\n", .{@tagName(resource)});
            }
        }

        if (self.output_buffer) |*output_buffer| {
            if (output_buffer.amount == 0) return;
            if (self.output != null) return;

            self.output = .{
                .resource = output_buffer.resource,
                .amount = 1,
            };

            output_buffer.amount -= 1;
            std.debug.print("[Drill] Moved 1 {s} to output. Buffer remaining: {d}\n", .{ @tagName(output_buffer.resource), output_buffer.amount });

            if (output_buffer.amount == 0) {
                self.output_buffer = null;
                std.debug.print("[Drill] Buffer is now empty.\n", .{});
            }
        }
    }

    pub fn draw(self: Self, pos: Vec2i) void {
        const draw_pos = World.gridToWorld(pos);

        rl.DrawRectangleRec(
            .{
                .x = draw_pos[0],
                .y = draw_pos[1],
                .width = Tile.size,
                .height = Tile.size,
            },
            @bitCast(Color.init(200, 110, 64, 255)),
        );

        if (self.is_selected) {
            rl.DrawRectangleLinesEx(
                .{
                    .x = draw_pos[0],
                    .y = draw_pos[1],
                    .width = Tile.size,
                    .height = Tile.size,
                },
                2,
                @bitCast(Color.init(255, 110, 64, 255)),
            );
        }

        const center_x = draw_pos[0] + (Tile.size / 2.0);
        const center_y = draw_pos[1] + (Tile.size / 2.0);

        const offset = Tile.size / 8.0;

        var v1: rl.Vector2 = undefined;
        var v2: rl.Vector2 = undefined;
        var v3: rl.Vector2 = undefined;

        switch (self.direction) {
            .north => {
                v1 = .{ .x = center_x, .y = center_y - offset };
                v2 = .{ .x = center_x - offset, .y = center_y + offset };
                v3 = .{ .x = center_x + offset, .y = center_y + offset };
            },
            .south => {
                v1 = .{ .x = center_x, .y = center_y + offset };
                v2 = .{ .x = center_x + offset, .y = center_y - offset };
                v3 = .{ .x = center_x - offset, .y = center_y - offset };
            },
            .east => {
                v1 = .{ .x = center_x + offset, .y = center_y };
                v2 = .{ .x = center_x - offset, .y = center_y - offset };
                v3 = .{ .x = center_x - offset, .y = center_y + offset };
            },
            .west => {
                v1 = .{ .x = center_x - offset, .y = center_y };
                v2 = .{ .x = center_x + offset, .y = center_y + offset };
                v3 = .{ .x = center_x + offset, .y = center_y - offset };
            },
        }

        rl.DrawTriangle(v1, v2, v3, rl.WHITE);
    }

    pub fn rotate(self: *Self) void {
        self.direction.rotate();
    }
};

pub const Smelter = struct {
    allocator: std.mem.Allocator,
    timer: f32,
    duration: f32,
    direction: Direction,

    processing: ?Slot,

    input: ?Slot,
    output: ?Slot,

    input_buffer: ?Slot,
    output_buffer: ?Slot,

    is_selected: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, duration: f32) Self {
        return .{
            .allocator = allocator,
            .timer = 0.0,
            .duration = duration,
            .direction = .north,
            .processing = null,
            .input = null,
            .output = null,
            .input_buffer = null,
            .output_buffer = null,
            .is_selected = false,
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
    ) !void {
        _ = pos;
        _ = world;

        // push to output
        if (self.output_buffer) |*output_buffer| {
            if (self.output == null and output_buffer.amount > 0) {
                self.output = .{ .resource = output_buffer.resource, .amount = 1 };
                output_buffer.amount -= 1;

                std.debug.print("[Smelter] Pushed 1 {s} to output.\n", .{@tagName(output_buffer.resource)});

                if (output_buffer.amount == 0) self.output_buffer = null;
            }
        }

        if (self.processing) |processing| {
            // process
            self.timer += dt;

            if (self.timer >= self.duration) {
                const result_resource: ResourceKind = switch (processing.resource) {
                    .raw_iron => .iron_ingot,
                    else => unreachable,
                };

                var output_successful = false;

                if (self.output_buffer == null) {
                    self.output_buffer = .{ .resource = result_resource, .amount = 1 };
                    output_successful = true;
                } else if (self.output_buffer.?.resource == result_resource) {
                    self.output_buffer.?.amount += 1;
                    output_successful = true;
                }

                if (output_successful) {
                    std.debug.print("[Smelter] Finished smelting 1 {s}!\n", .{@tagName(result_resource)});
                    self.processing = null;
                    self.timer -= self.duration;
                } else {
                    self.timer = self.duration;
                }
            }
        } else {
            // nothing is processing. grab from input_buffer
            if (self.input_buffer) |*input_buffer| {
                if (input_buffer.amount > 0) {
                    self.processing = .{ .resource = input_buffer.resource, .amount = 1 };
                    input_buffer.amount -= 1;
                    self.timer = 0.0;

                    std.debug.print("[Smelter] Started smelting 1 {s}...\n", .{@tagName(input_buffer.resource)});

                    if (input_buffer.amount == 0) self.input_buffer = null;
                }
            }
        }

        // pull from input
        if (self.input) |input| {
            if (self.input_buffer == null) {
                self.input_buffer = input;
                self.input = null;
                std.debug.print("[Smelter] Pulled {d} {s} into input buffer.\n", .{ input.amount, @tagName(input.resource) });
            } else if (self.input_buffer.?.resource == input.resource) {
                self.input_buffer.?.amount += input.amount;
                self.input = null;
                std.debug.print("[Smelter] Pulled {d} {s} into input buffer.\n", .{ input.amount, @tagName(input.resource) });
            }
        }
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

    pub fn rotate(self: *Self) void {
        self.direction.rotate();
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
    ) !void {
        switch (self.*) {
            .drill => |*d| try d.update(pos, dt, world),
            .smelter => |*s| try s.update(pos, dt, world),
        }
    }

    pub fn getOutputPtr(self: *Self) *?Slot {
        return switch (self.*) {
            inline else => |*building| &building.output,
        };
    }

    pub fn getInputPtr(self: *Self) *?Slot {
        return switch (self.*) {
            inline else => |*building| &building.input,
        };
    }

    pub fn getOutputBufferPtr(self: *Self) *?Slot {
        return switch (self.*) {
            inline else => |*building| &building.output_buffer,
        };
    }

    pub fn getInputBufferPtr(self: *Self) *?Slot {
        return switch (self.*) {
            inline else => |*building| &building.input_buffer,
        };
    }

    pub fn setSelected(self: *Self, is_selected: bool) void {
        return switch (self.*) {
            inline else => |*building| building.is_selected = is_selected,
        };
    }

    pub fn rotate(self: *Self) void {
        return switch (self.*) {
            inline else => |*building| building.rotate(),
        };
    }

    pub fn getDirection(self: *Self) ?Direction {
        return switch (self.*) {
            inline else => |building| building.direction,
        };
    }

    pub fn draw(self: *Self, pos: Vec2i) void {
        switch (self.*) {
            inline else => |building| building.draw(pos),
        }
    }
};
