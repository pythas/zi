const std = @import("std");

const Camera = @import("camera.zig").Camera;
const fastnoise = @import("libs/fastnoise.zig");
const Rectangle = @import("primitives.zig").Rectangle;
const Vec2 = @import("primitives.zig").Vec2;
const Vec2i = @import("primitives.zig").Vec2i;
const Color = @import("primitives.zig").Color;

const rl = @import("rl.zig").raylib;

pub const TileKind = enum {
    rock,
    iron,
};

pub const Tile = struct {
    kind: TileKind,

    const Self = @This();

    pub const size = 32;

    pub fn init(kind: TileKind) Self {
        return .{
            .kind = kind,
        };
    }
};

pub const Chunk = struct {
    position: Vec2i,

    tiles: [size * size]?Tile,

    pub const size = 16;
    pub const size_pixels = size * Tile.size;

    const Self = @This();

    pub fn init(position: Vec2i) Self {
        return .{
            .position = position,
            .tiles = .{null} ** (size * size),
        };
    }

    pub fn getTile(self: *Self, local_x: usize, local_y: usize) ?Tile {
        return self.tiles[local_y * size + local_x];
    }

    pub fn draw(self: *Self, viewport: Rectangle) void {
        const chunk_pixel_x = @as(f32, @floatFromInt(self.position[0])) * Chunk.size_pixels;
        const chunk_pixel_y = @as(f32, @floatFromInt(self.position[1])) * Chunk.size_pixels;

        const chunk_rect = Rectangle.init(
            chunk_pixel_x,
            chunk_pixel_y,
            Chunk.size_pixels,
            Chunk.size_pixels,
        );

        if (!chunk_rect.collides(viewport)) {
            return;
        }

        var local_y: usize = 0;
        while (local_y < size) : (local_y += 1) {
            var local_x: usize = 0;
            while (local_x < size) : (local_x += 1) {
                if (self.getTile(local_x, local_y)) |tile| {
                    const draw_x = chunk_pixel_x + (@as(f32, @floatFromInt(local_x)) * Tile.size);
                    const draw_y = chunk_pixel_y + (@as(f32, @floatFromInt(local_y)) * Tile.size);

                    const color = switch (tile.kind) {
                        .rock => Color.init(80, 80, 80, 255),
                        .iron => Color.init(186, 110, 64, 255),
                    };

                    rl.DrawRectangleRec(.{
                        .x = draw_x,
                        .y = draw_y,
                        .width = Tile.size,
                        .height = Tile.size,
                    }, @bitCast(color));
                }
            }
        }
    }
};

const WorldGenerator = struct {
    seed: i32,
    terrain_noise: fastnoise.Noise(f32),
    ore_noise: fastnoise.Noise(f32),

    pub const density_threshold = 0.2;
    pub const NoiseMap = [Chunk.size * Chunk.size]f32;

    const Self = @This();

    pub fn init(seed: i32) Self {
        const terrain_noise = fastnoise.Noise(f32){
            .seed = seed,
            .noise_type = .simplex,
            .frequency = 0.05,
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

    fn generateNoiseMap(_: *Self, noise: *fastnoise.Noise(f32), offset: Vec2) NoiseMap {
        var noise_map: [Chunk.size * Chunk.size]f32 = undefined;
        for (0..noise_map.len) |i| {
            noise_map[i] = noise.genNoise2D(
                offset[0] + @as(f32, @floatFromInt(i % Chunk.size)),
                offset[1] + @as(f32, @floatFromInt(i / Chunk.size)),
            );
        }

        return noise_map;
    }

    pub fn generateChunk(self: *Self, chunk_position: Vec2i) Chunk {
        var chunk = Chunk.init(chunk_position);

        const chunk_offset = @as(Vec2, @floatFromInt(chunk_position)) * @as(Vec2, @splat(Chunk.size));

        const terrain_map = self.generateNoiseMap(&self.terrain_noise, chunk_offset);
        for (terrain_map, 0..) |terrain_value, i| {
            if (terrain_value > density_threshold) {
                const ore_x = @as(f32, @floatFromInt(i % Chunk.size));
                const ore_y = @as(f32, @floatFromInt(i / Chunk.size));

                const ore_value = self.ore_noise.genNoise2D(chunk_offset[0] + ore_x, chunk_offset[1] + ore_y);
                if (ore_value > 0.55) {
                    chunk.tiles[i] = Tile.init(.iron);
                } else {
                    chunk.tiles[i] = Tile.init(.rock);
                }
            }
        }

        return chunk;
    }
};

pub const Drill = struct {
    timer: f32 = 0.0,
    duration: f32 = 2.0,

    const Self = @This();

    pub fn getProgress(self: *Self) f32 {
        return @min(1.0, self.timer / self.duration);
    }

    pub fn update(self: *Self, dt: f32) bool {
        self.timer += dt;

        if (self.timer >= self.duration) {
            return true;
        }

        return false;
    }
};

pub const WorldPosition = struct {
    chunk_pos: Vec2i,
    tile_index: usize,
    local_x: usize,
    local_y: usize,

    pub fn toGlobalTilePosition(self: @This()) Vec2i {
        return .{
            (self.chunk_pos[0] * Chunk.size) + @as(i32, @intCast(self.local_x)),
            (self.chunk_pos[1] * Chunk.size) + @as(i32, @intCast(self.local_y)),
        };
    }
};

pub const World = struct {
    allocator: std.mem.Allocator,
    generator: WorldGenerator,
    chunks: std.AutoHashMap(Vec2i, Chunk),

    active_drills: std.AutoHashMap(Vec2i, Drill),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, seed: i32) Self {
        return .{
            .allocator = allocator,
            .generator = WorldGenerator.init(seed),
            .chunks = std.AutoHashMap(Vec2i, Chunk).init(allocator),
            .active_drills = std.AutoHashMap(Vec2i, Drill).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.chunks.deinit();
        self.active_drills.deinit();
    }

    pub fn draw(self: *Self, camera: *Camera) void {
        const viewport = camera.getViewport();

        var it = self.chunks.valueIterator();
        while (it.next()) |chunk| {
            chunk.draw(viewport);
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
                try unload_drills.append(self.allocator, position);
                self.clearTile(position);
            }
        }

        for (unload_drills.items) |unload_drill| {
            _ = self.active_drills.remove(unload_drill);
        }
    }

    pub fn getTileAtScreenPosition(self: *Self, screen_pos: rl.Vector2, camera: *Camera) ?WorldPosition {
        const world_pos = rl.GetScreenToWorld2D(screen_pos, camera.rl_camera);

        const chunk_x: i32 = @intFromFloat(@floor(world_pos.x / @as(f32, @floatFromInt(Chunk.size_pixels))));
        const chunk_y: i32 = @intFromFloat(@floor(world_pos.y / @as(f32, @floatFromInt(Chunk.size_pixels))));
        const chunk_pos = Vec2i{ chunk_x, chunk_y };

        if (!self.chunks.contains(chunk_pos)) {
            return null;
        }

        const local_pixel_x = world_pos.x - (@as(f32, @floatFromInt(chunk_x)) * @as(f32, @floatFromInt(Chunk.size_pixels)));
        const local_pixel_y = world_pos.y - (@as(f32, @floatFromInt(chunk_y)) * @as(f32, @floatFromInt(Chunk.size_pixels)));

        const local_x: usize = @intFromFloat(@floor(local_pixel_x / @as(f32, @floatFromInt(Tile.size))));
        const local_y: usize = @intFromFloat(@floor(local_pixel_y / @as(f32, @floatFromInt(Tile.size))));

        const tile_index = (local_y * Chunk.size) + local_x;

        return WorldPosition{
            .chunk_pos = chunk_pos,
            .tile_index = tile_index,
            .local_x = local_x,
            .local_y = local_y,
        };
    }

    pub fn clearTile(self: *Self, position: Vec2i) void {
        const chunk_size = @as(i32, @intCast(Chunk.size));

        const chunk_pos = Vec2i{
            @divFloor(position[0], chunk_size),
            @divFloor(position[1], chunk_size),
        };

        const local_x: usize = @intCast(@mod(position[0], chunk_size));
        const local_y: usize = @intCast(@mod(position[1], chunk_size));

        const tile_index = (local_y * Chunk.size) + local_x;

        if (self.chunks.getPtr(chunk_pos)) |chunk| {
            chunk.tiles[tile_index] = null;
        }
    }

    pub fn loadChunk(self: *Self, position: Vec2i) !void {
        if (self.chunks.contains(position)) return;

        const chunk = self.generator.generateChunk(position);

        try self.chunks.put(position, chunk);

        std.debug.print("LOAD CHUNK: {d} {d}\n", .{ position[0], position[1] });
    }

    pub fn loadVisibleChunks(self: *Self, viewport: Rectangle) !void {
        const bounds = chunkBounds(viewport, 1.0);

        var chunk_y = bounds.min_y;
        while (chunk_y <= bounds.max_y) : (chunk_y += 1) {
            var chunk_x = bounds.min_x;
            while (chunk_x <= bounds.max_x) : (chunk_x += 1) {
                try self.loadChunk(.{ chunk_x, chunk_y });
            }
        }
    }

    pub fn unloadDistantChunks(self: *Self, viewport: Rectangle) !void {
        const bounds = chunkBounds(viewport, 3.0);

        var unloads: std.ArrayList(Vec2i) = .empty;
        defer unloads.deinit(self.allocator);

        var it = self.chunks.keyIterator();
        while (it.next()) |pos_ptr| {
            const pos = pos_ptr.*;

            if (pos[0] < bounds.min_x or pos[0] > bounds.max_x or
                pos[1] < bounds.min_y or pos[1] > bounds.max_y)
            {
                try unloads.append(self.allocator, pos);
            }
        }

        for (unloads.items) |unload_pos| {
            _ = self.chunks.remove(unload_pos);
            std.debug.print("UNLOAD CHUNK: {d} {d}\n", .{ unload_pos[0], unload_pos[1] });
        }
    }

    fn chunkBounds(viewport: Rectangle, padding: f32) struct { min_x: i32, min_y: i32, max_x: i32, max_y: i32 } {
        const padding_pixels = @as(f32, @floatFromInt(Chunk.size_pixels)) * padding;

        return .{
            .min_x = @intFromFloat(@floor((viewport.x - padding_pixels) / Chunk.size_pixels)),
            .min_y = @intFromFloat(@floor((viewport.y - padding_pixels) / Chunk.size_pixels)),
            .max_x = @intFromFloat(@floor((viewport.x + viewport.width + padding_pixels) / Chunk.size_pixels)),
            .max_y = @intFromFloat(@floor((viewport.y + viewport.height + padding_pixels) / Chunk.size_pixels)),
        };
    }
};
