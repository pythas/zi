const std = @import("std");

const Slot = @import("inventory.zig").Slot;
const ResourceKind = @import("inventory.zig").ResourceKind;
const Vec2i = @import("primitives.zig").Vec2i;
const World = @import("world.zig").World;
const Direction = @import("components.zig").Direction;
const Color = @import("primitives.zig").Color;
const Camera = @import("camera.zig").Camera;
const GridBounds = @import("world.zig").GridBounds;

const Timer = @import("components.zig").Timer;
const Station = @import("components.zig").Station;
const Drill = @import("components.zig").Drill;
const Smelter = @import("components.zig").Smelter;
const Storage = @import("components.zig").Storage;
const Inventory = @import("components.zig").Inventory;
const Selectable = @import("components.zig").Selectable;
const Renderable = @import("components.zig").Renderable;
const systems = @import("systems.zig");

pub const Registry = struct {
    allocator: std.mem.Allocator,

    transfer_timer: f32,
    transfer_duration: f32,

    orientations: std.AutoHashMap(Vec2i, Direction),
    inventories: std.AutoHashMap(Vec2i, Inventory),
    timers: std.AutoHashMap(Vec2i, Timer),

    renderables: std.AutoHashMap(Vec2i, Renderable),
    selectables: std.AutoHashMap(Vec2i, Selectable),

    stations: std.AutoHashMap(Vec2i, Station),
    drills: std.AutoHashMap(Vec2i, Drill),
    smelters: std.AutoHashMap(Vec2i, Smelter),
    storage: std.AutoHashMap(Vec2i, Storage),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .transfer_timer = 0.0,
            .transfer_duration = 0.25,
            .orientations = std.AutoHashMap(Vec2i, Direction).init(allocator),
            .inventories = std.AutoHashMap(Vec2i, Inventory).init(allocator),
            .timers = std.AutoHashMap(Vec2i, Timer).init(allocator),
            .renderables = std.AutoHashMap(Vec2i, Renderable).init(allocator),
            .selectables = std.AutoHashMap(Vec2i, Selectable).init(allocator),
            .stations = std.AutoHashMap(Vec2i, Station).init(allocator),
            .drills = std.AutoHashMap(Vec2i, Drill).init(allocator),
            .smelters = std.AutoHashMap(Vec2i, Smelter).init(allocator),
            .storage = std.AutoHashMap(Vec2i, Storage).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.orientations.deinit();
        self.inventories.deinit();
        self.timers.deinit();
        self.renderables.deinit();
        self.selectables.deinit();
        self.stations.deinit();
        self.drills.deinit();
        self.smelters.deinit();
        self.storage.deinit();
    }

    pub fn update(
        self: *Self,
        dt: f32,
        world: *World,
    ) !void {
        self.transfer_timer += dt;
        const transfer_ready = self.transfer_timer >= self.transfer_duration;

        systems.updateTimers(self, dt);
        systems.updateDrills(self, world);
        systems.updateSmelters(self);
        systems.updateInventories(self, transfer_ready);
        systems.updateStorage(self, transfer_ready);

        if (transfer_ready) {
            self.transfer_timer -= self.transfer_duration;
        }
    }

    pub fn draw(self: *Self, bounds: GridBounds) void {
        systems.renderBuildings(self, bounds);
        systems.renderOrientations(self, bounds);
        systems.renderSelections(self, bounds);
    }

    pub fn getResourceCount(self: *Self, resource: ResourceKind) u32 {
        _ = self;
        _ = resource;

        return 0;
    }

    pub fn getInventory(self: *Self) std.EnumMap(ResourceKind, u32) {
        var global_map = std.EnumMap(ResourceKind, u32).initFull(0);
        var it = self.stations.iterator();

        while (it.next()) |entry| {
            const station = entry.value_ptr;
            var item_it = station.items.iterator();

            while (item_it.next()) |item_entry| {
                const kind = item_entry.key;
                const amount = item_entry.value.*;

                if (amount > 0) {
                    const current_total = global_map.get(kind).?;
                    global_map.put(kind, current_total + amount);
                }
            }
        }

        return global_map;
    }

    pub fn hasBuilding(self: *Self, pos: Vec2i) bool {
        return self.drills.contains(pos) or
            self.smelters.contains(pos) or
            self.storage.contains(pos);
    }

    pub fn removeEntity(self: *Self, pos: Vec2i) void {
        _ = self.orientations.remove(pos);
        _ = self.inventories.remove(pos);
        _ = self.timers.remove(pos);
        _ = self.renderables.remove(pos);
        _ = self.selectables.remove(pos);
        _ = self.stations.remove(pos);
        _ = self.drills.remove(pos);
        _ = self.smelters.remove(pos);
        _ = self.storage.remove(pos);
    }

    pub fn placeStation(self: *Self, world: *World, pos: Vec2i) !bool {
        if (self.hasBuilding(pos)) return false;

        const tile = world.getTile(pos) orelse return false;
        if (tile.kind.toResource() != null) return false;

        try self.timers.put(pos, Timer.init(1.0));
        try self.stations.put(pos, Station.init());
        try self.renderables.put(pos, Renderable.init(Color.init(40, 40, 40, 255)));
        try self.selectables.put(pos, Selectable.init());

        return true;
    }

    pub fn placeDrill(self: *Self, world: *World, pos: Vec2i) !bool {
        if (self.hasBuilding(pos)) return false;

        const tile = world.getTile(pos) orelse return false;
        if (tile.kind.toResource() == null) return false;

        try self.timers.put(pos, Timer.init(1.0));
        try self.drills.put(pos, Drill.init());
        try self.orientations.put(pos, .north);
        try self.renderables.put(pos, Renderable.init(Color.init(40, 180, 10, 255)));
        try self.selectables.put(pos, Selectable.init());
        try self.inventories.put(pos, Inventory.init(0, 10));

        return true;
    }

    pub fn placeSmelter(self: *Self, pos: Vec2i) !bool {
        if (self.hasBuilding(pos)) return false;

        try self.timers.put(pos, Timer.init(0.5));
        try self.orientations.put(pos, .north);
        try self.smelters.put(pos, Smelter.init());
        try self.renderables.put(pos, Renderable.init(Color.init(180, 80, 80, 255)));
        try self.selectables.put(pos, Selectable.init());

        var inventory = Inventory.init(5, 10);
        inventory.accepted_inputs.insert(.raw_iron);
        try self.inventories.put(pos, inventory);

        return true;
    }

    pub fn placeStorage(self: *Self, pos: Vec2i) !bool {
        if (self.hasBuilding(pos)) return false;

        try self.orientations.put(pos, .north);
        try self.storage.put(pos, Storage.init());
        try self.renderables.put(pos, Renderable.init(Color.init(40, 40, 180, 255)));
        try self.selectables.put(pos, Selectable.init());

        return true;
    }
};
