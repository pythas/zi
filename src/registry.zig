const std = @import("std");

const Slot = @import("inventory.zig").Slot;
const Vec2i = @import("primitives.zig").Vec2i;
const World = @import("world.zig").World;
const Event = @import("event.zig").Event;
const Direction = @import("components.zig").Direction;
const Color = @import("primitives.zig").Color;
const Camera = @import("camera.zig").Camera;
const GridBounds = @import("world.zig").GridBounds;

const Timer = @import("components.zig").Timer;
const Drill = @import("components.zig").Drill;
const Smelter = @import("components.zig").Smelter;
const Inventory = @import("components.zig").Inventory;
const Selectable = @import("components.zig").Selectable;
const Renderable = @import("components.zig").Renderable;
const systems = @import("systems.zig");

pub const Registry = struct {
    allocator: std.mem.Allocator,

    orientations: std.AutoHashMap(Vec2i, Direction),
    inventories: std.AutoHashMap(Vec2i, Inventory),
    timers: std.AutoHashMap(Vec2i, Timer),

    renderables: std.AutoHashMap(Vec2i, Renderable),
    selectables: std.AutoHashMap(Vec2i, Selectable),

    drills: std.AutoHashMap(Vec2i, Drill),
    smelters: std.AutoHashMap(Vec2i, Smelter),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .orientations = std.AutoHashMap(Vec2i, Direction).init(allocator),
            .inventories = std.AutoHashMap(Vec2i, Inventory).init(allocator),
            .timers = std.AutoHashMap(Vec2i, Timer).init(allocator),
            .renderables = std.AutoHashMap(Vec2i, Renderable).init(allocator),
            .selectables = std.AutoHashMap(Vec2i, Selectable).init(allocator),
            .drills = std.AutoHashMap(Vec2i, Drill).init(allocator),
            .smelters = std.AutoHashMap(Vec2i, Smelter).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.orientations.deinit();
        self.inventories.deinit();
        self.timers.deinit();
        self.renderables.deinit();
        self.selectables.deinit();
        self.drills.deinit();
        self.smelters.deinit();
    }

    pub fn update(
        self: *Self,
        dt: f32,
        world: *World,
    ) !void {
        systems.updateTimers(self, dt);
        systems.updateDrills(self, world);
        systems.updateSmelters(self);
        systems.updateInventories(self);
    }

    pub fn draw(self: *Self, bounds: GridBounds) void {
        systems.renderBuildings(self, bounds);
        systems.renderOrientations(self, bounds);
        systems.renderSelections(self, bounds);
    }

    pub fn getAdjacentInventoryPtr(self: *Self, pos: Vec2i, dir: Direction) ?*Inventory {
        const offset = dir.toVec();
        const neighbor_pos = Vec2i{ pos[0] + offset[0], pos[1] + offset[1] };

        return self.inventories.getPtr(neighbor_pos);
    }

    pub fn placeDrill(self: *Self, world: *World, pos: Vec2i) !bool {
        if (self.drills.contains(pos)) return false;

        const tile = world.getTile(pos) orelse return false;
        if (tile.kind.toResource() == null) return false;

        try self.timers.put(pos, Timer.init(1.0));
        try self.drills.put(pos, Drill.init());
        try self.orientations.put(pos, .north);
        try self.renderables.put(pos, Renderable.init(Color.init(40, 180, 10, 255)));
        try self.inventories.put(pos, Inventory.init(5, 5));
        try self.selectables.put(pos, Selectable.init());

        std.debug.print("Drill placed at {d}, {d}\n", .{ pos[0], pos[1] });

        return true;
    }

    pub fn placeSmelter(self: *Self, pos: Vec2i) !bool {
        if (self.smelters.contains(pos)) return false;

        try self.timers.put(pos, Timer.init(1.0));
        try self.orientations.put(pos, .north);
        try self.smelters.put(pos, Smelter.init());
        try self.renderables.put(pos, Renderable.init(Color.init(180, 40, 10, 255)));
        var inventory = Inventory.init(5, 5);
        inventory.accepted_inputs.insert(.raw_iron);
        try self.inventories.put(pos, inventory);
        try self.selectables.put(pos, Selectable.init());

        std.debug.print("Smelter placed at {d}, {d}\n", .{ pos[0], pos[1] });

        return true;
    }
};
