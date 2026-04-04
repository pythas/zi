const std = @import("std");

const Camera = @import("camera.zig").Camera;
const fastnoise = @import("libs/fastnoise.zig");
const Rectangle = @import("primitives.zig").Rectangle;
const Vec2 = @import("primitives.zig").Vec2;
const Vec2i = @import("primitives.zig").Vec2i;
const Color = @import("primitives.zig").Color;
const Event = @import("event.zig").Event;
const ResourceKind = @import("inventory.zig").ResourceKind;

const rl = @import("rl.zig").raylib;

pub const TileKind = enum {
    rock,
    iron,

    const Self = @This();

    pub fn toResource(self: Self) ?ResourceKind {
        return switch (self) {
            .rock => null,
            .iron => .raw_iron,
        };
    }
};

pub const Tile = struct {
    kind: TileKind,
    yield: u32,

    const Self = @This();

    pub const size = 32;
    pub const size_f = 32.0;

    pub fn init(kind: TileKind) Self {
        return .{
            .kind = kind,
            .yield = 5, // TODO: set through WorldGenerator
        };
    }
};

pub const AsteroidConfig = struct {
    min_radius: f32 = 4.0,
    max_radius: f32 = 12.0,
    noise_amplitude: f32 = 6.0,
    iron_threshold: f32 = 0.55,
};

const WorldGenerator = struct {
    seed: i64,
    terrain_noise: fastnoise.Noise(f32),
    ore_noise: fastnoise.Noise(f32),

    const Self = @This();

    pub fn init(seed: i32) Self {
        const terrain_noise = fastnoise.Noise(f32){
            .seed = seed,
            .noise_type = .simplex,
            .frequency = 0.03,
            .fractal_type = .fbm,
        };

        const ore_noise = fastnoise.Noise(f32){
            .seed = seed + 1,
            .noise_type = .simplex,
            .frequency = 0.15,
            .fractal_type = .fbm,
        };

        return .{
            .seed = seed,
            .terrain_noise = terrain_noise,
            .ore_noise = ore_noise,
        };
    }

    pub fn generateAsteroids(
        self: *Self,
        tiles: []?Tile,
        count: usize,
        spawn_radius: f32,
        config: AsteroidConfig,
    ) void {
        const radius_variance = config.max_radius - config.min_radius;
        const box_padding: i32 = @intFromFloat(@ceil(config.noise_amplitude));

        var prng = std.Random.DefaultPrng.init(@bitCast(@as(i64, self.seed)));
        const random = prng.random();

        const world_size: i32 = World.size;
        const center_offset = @as(f32, @floatFromInt(world_size / 2));

        for (0..count) |_| {
            const angle = random.float(f32) * std.math.tau;
            const distance = @sqrt(random.float(f32)) * spawn_radius;
            const center_x: i32 = @intFromFloat(center_offset + (distance * @cos(angle)));
            const center_y: i32 = @intFromFloat(center_offset + (distance * @sin(angle)));

            const base_radius = (random.float(f32) * radius_variance) + config.min_radius;

            const min_x = @max(0, center_x - @as(i32, @intFromFloat(base_radius)) - box_padding);
            const max_x = @min(world_size - 1, center_x + @as(i32, @intFromFloat(base_radius)) + box_padding);
            const min_y = @max(0, center_y - @as(i32, @intFromFloat(base_radius)) - box_padding);
            const max_y = @min(world_size - 1, center_y + @as(i32, @intFromFloat(base_radius)) + box_padding);

            var y = min_y;
            while (y <= max_y) : (y += 1) {
                var x = min_x;
                while (x <= max_x) : (x += 1) {
                    const dx = @as(f32, @floatFromInt(x - center_x));
                    const dy = @as(f32, @floatFromInt(y - center_y));
                    const tile_dist = @sqrt((dx * dx) + (dy * dy));

                    const noise_val = self.terrain_noise.genNoise2D(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y)));
                    const bumpy_radius = base_radius + (noise_val * config.noise_amplitude);

                    if (tile_dist <= bumpy_radius) {
                        const index = @as(usize, @intCast(y)) * @as(usize, @intCast(world_size)) + @as(usize, @intCast(x));

                        const ore_val = self.ore_noise.genNoise2D(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y)));

                        if (ore_val > config.iron_threshold) {
                            tiles[index] = Tile.init(.iron);
                        } else {
                            if (tiles[index] == null or tiles[index].?.kind != .iron) {
                                tiles[index] = Tile.init(.rock);
                            }
                        }
                    }
                }
            }
        }
    }
};

pub const Drill = struct {
    timer: f32,
    duration: f32,

    const Self = @This();

    pub fn init(duration: f32) Self {
        return .{
            .timer = 0.0,
            .duration = duration,
        };
    }

    pub fn getProgress(self: *Self) f32 {
        return @min(1.0, self.timer / self.duration);
    }

    pub fn update(self: *Self, dt: f32) bool {
        self.timer += dt;

        if (self.timer >= self.duration) {
            self.timer -= self.duration;
            return true;
        }

        return false;
    }
};

pub const World = struct {
    allocator: std.mem.Allocator,
    generator: WorldGenerator,
    tiles: []?Tile,
    events: std.ArrayList(Event),

    active_drills: std.AutoHashMap(Vec2i, Drill),

    pub const size = 1024;

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, seed: i32) !Self {
        const tiles = try allocator.alloc(?Tile, size * size);
        @memset(tiles, null);

        var self = Self{
            .allocator = allocator,
            .generator = WorldGenerator.init(seed),
            .tiles = tiles,
            .events = .empty,
            .active_drills = std.AutoHashMap(Vec2i, Drill).init(allocator),
        };

        self.generator.generateAsteroids(
            self.tiles,
            5,
            100.0,
            .{
                .min_radius = 5.0,
                .max_radius = 15.0,
                .noise_amplitude = 6.0,
                .iron_threshold = 0.30,
            },
        );

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.tiles);
        self.events.deinit(self.allocator);
        self.active_drills.deinit();
    }

    pub fn draw(self: *Self, camera: *Camera) void {
        const viewport = camera.getViewport();
        const bounds = getBounds(viewport, 3.0);

        var tile_y: i32 = bounds.min_y;
        while (tile_y <= bounds.max_y) : (tile_y += 1) {
            var tile_x: i32 = bounds.min_x;
            while (tile_x <= bounds.max_x) : (tile_x += 1) {
                const tile = self.getTile(.{ tile_x, tile_y }) orelse continue;
                const draw_pos = gridToWorld(.{ @as(i32, @intCast(tile_x)), @as(i32, @intCast(tile_y)) });
                const color = switch (tile.kind) {
                    .rock => Color.init(80, 80, 80, 255),
                    .iron => Color.init(186, 110, 64, 255),
                };

                rl.DrawRectangleRec(.{
                    .x = draw_pos[0],
                    .y = draw_pos[1],
                    .width = Tile.size,
                    .height = Tile.size,
                }, @bitCast(color));
            }
        }
    }

    pub fn update(self: *Self) !void {
        var unload_drills: std.ArrayList(Vec2i) = .empty;
        defer unload_drills.deinit(self.allocator);

        var it = self.active_drills.iterator();
        while (it.next()) |entry| {
            const position = entry.key_ptr.*;
            var active_drill = entry.value_ptr;

            if (active_drill.update(rl.GetFrameTime())) {
                const is_depleted = try self.mineTile(position);

                if (is_depleted) {
                    try unload_drills.append(self.allocator, position);
                }
            }
        }

        for (unload_drills.items) |unload_drill| {
            _ = self.active_drills.remove(unload_drill);
        }
    }

    pub fn getTile(self: *Self, pos: Vec2i) ?Tile {
        if (self.getTilePtr(pos)) |tile_slot| {
            return tile_slot.*;
        }

        return null;
    }

    pub fn getTilePtr(self: *Self, pos: Vec2i) ?*?Tile {
        // TODO: bounds check

        const x: usize = @intCast(pos[0]);
        const y: usize = @intCast(pos[1]);

        return &self.tiles[y * size + x];
    }

    pub fn worldToGrid(world_pos: Vec2) Vec2i {
        const offset: i32 = size / 2;

        return .{
            @as(i32, @intFromFloat(@floor(world_pos[0] / Tile.size_f))) + offset,
            @as(i32, @intFromFloat(@floor(world_pos[1] / Tile.size_f))) + offset,
        };
    }

    pub fn gridToWorld(grid_pos: Vec2i) Vec2 {
        const offset: i32 = size / 2;

        return .{
            @as(f32, @floatFromInt(grid_pos[0] - offset)) * Tile.size_f,
            @as(f32, @floatFromInt(grid_pos[1] - offset)) * Tile.size_f,
        };
    }

    pub fn screenToGrid(
        screen_pos: rl.Vector2,
        camera: *Camera,
    ) Vec2i {
        const world_pos = rl.GetScreenToWorld2D(screen_pos, camera.rl_camera);

        return worldToGrid(.{ world_pos.x, world_pos.y });
    }

    fn getBounds(viewport: Rectangle, padding: f32) struct {
        min_x: i32,
        min_y: i32,
        max_x: i32,
        max_y: i32,
    } {
        const padding_pixels = Tile.size_f * padding;

        const top_left = Vec2{ viewport.x - padding_pixels, viewport.y - padding_pixels };
        const bottom_right = Vec2{ viewport.x + viewport.width + padding_pixels, viewport.y + viewport.height + padding_pixels };

        const grid_min = worldToGrid(top_left);
        const grid_max = worldToGrid(bottom_right);

        const max_index: i32 = size - 1;

        const clamped_min_x = @max(0, @min(max_index, grid_min[0]));
        const clamped_min_y = @max(0, @min(max_index, grid_min[1]));
        const clamped_max_x = @max(0, @min(max_index, grid_max[0]));
        const clamped_max_y = @max(0, @min(max_index, grid_max[1]));

        return .{
            .min_x = @intCast(clamped_min_x),
            .min_y = @intCast(clamped_min_y),
            .max_x = @intCast(clamped_max_x),
            .max_y = @intCast(clamped_max_y),
        };
    }

    pub fn mineTile(self: *Self, position: Vec2i) !bool {
        const tile_slot = self.getTilePtr(position) orelse return false;

        if (tile_slot.*) |*tile| {
            tile.yield -= 1;

            try self.events.append(self.allocator, .{ .ore_mined = .{ .kind = tile.kind, .amount = 1 } });

            std.debug.print("Mined 1 ore. Remaining: {d}\n", .{tile.yield});

            if (tile.yield == 0) {
                tile_slot.* = null;
                return true;
            }
        }

        return false;
    }
};
