const std = @import("std");
const fastnoise = @import("libs/fastnoise.zig");

const rl = @cImport({
    @cInclude("raylib.h");
});

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

    pub fn draw(self: Self, color: rl.Color) void {
        rl.DrawRectangleRec(@bitCast(self), color);
    }

    pub fn collides(self: Self, other: Self) bool {
        return rl.CheckCollisionRecs(@bitCast(self), @bitCast(other));
    }
};

pub const Tile = struct {
    const Self = @This();

    pub const size = 32;

    pub fn init() Self {
        return .{};
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
                    _ = tile;

                    const draw_x = chunk_pixel_x + (@as(f32, @floatFromInt(local_x)) * Tile.size);
                    const draw_y = chunk_pixel_y + (@as(f32, @floatFromInt(local_y)) * Tile.size);

                    rl.DrawRectangleRec(.{
                        .x = draw_x,
                        .y = draw_y,
                        .width = Tile.size,
                        .height = Tile.size,
                    }, rl.DARKGREEN);
                }
            }
        }
    }
};

pub const Camera = struct {
    rl_camera: rl.Camera2D,

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
};

pub const Player = struct {
    position: Vec2,
    speed: f32,

    const Self = @This();

    pub fn init(position: Vec2) Self {
        return .{
            .position = position,
            .speed = 5.0,
        };
    }

    pub fn update(self: *Self, input: InputState) void {
        const velocity = input.move_direction * @as(Vec2, @splat(self.speed));
        self.position = self.position + velocity;
    }
};

pub const WorldGenerator = struct {
    seed: i32,
    terrain_noise: fastnoise.Noise(f32),

    pub const density_threshold = 0.2;
    pub const NoiseMap = [Chunk.size * Chunk.size]f32;

    const Self = @This();

    pub fn init(seed: i32) Self {
        const noise = fastnoise.Noise(f32){
            .seed = seed,
            .noise_type = .simplex,
            .frequency = 0.05,
            .fractal_type = .fbm,
        };

        return .{
            .seed = seed,
            .terrain_noise = noise,
        };
    }

    fn generateTerrainMap(self: *Self, offset: Vec2) NoiseMap {
        var noise_map: [Chunk.size * Chunk.size]f32 = undefined;
        for (0..noise_map.len) |i| {
            noise_map[i] = self.terrain_noise.genNoise2D(
                offset[0] + @as(f32, @floatFromInt(i % Chunk.size)),
                offset[1] + @as(f32, @floatFromInt(i / Chunk.size)),
            );
        }

        return noise_map;
    }

    pub fn generateChunk(self: *Self, chunk_position: Vec2i) Chunk {
        var chunk = Chunk.init(chunk_position);

        const terrain_map = self.generateTerrainMap(@as(Vec2, @floatFromInt(chunk_position)) * @as(Vec2, @splat(Chunk.size)));
        for (terrain_map, 0..) |value, i| {
            if (value > density_threshold) {
                chunk.tiles[i] = Tile.init();
            }
        }

        return chunk;
    }
};

pub const World = struct {
    allocator: std.mem.Allocator,
    generator: WorldGenerator,
    chunks: std.AutoHashMap(Vec2i, Chunk),
    load_distance: i32,
    unload_distance: i32,
    prev_chunk: ?Vec2i,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, seed: i32) Self {
        return .{
            .allocator = allocator,
            .generator = WorldGenerator.init(seed),
            .chunks = std.AutoHashMap(Vec2i, Chunk).init(allocator),
            .load_distance = 1,
            .unload_distance = 2,
            .prev_chunk = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.chunks.deinit();
    }

    pub fn draw(self: *Self, camera: *Camera) void {
        const viewport = camera.getViewport();

        var it = self.chunks.valueIterator();
        while (it.next()) |chunk| {
            chunk.draw(viewport);
        }
    }

    pub fn loadChunk(self: *Self, position: Vec2i) !void {
        if (self.chunks.contains(position)) return;

        const chunk = self.generator.generateChunk(position);

        try self.chunks.put(position, chunk);

        std.debug.print("LOAD CHUNK: {d} {d}\n", .{ position[0], position[1] });
    }

    pub fn loadVisibleChunks(self: *Self, camera: *Camera) !void {
        const player_chunk_x: i32 = @intFromFloat(@floor(camera.rl_camera.target.x / Chunk.size_pixels));
        const player_chunk_y: i32 = @intFromFloat(@floor(camera.rl_camera.target.y / Chunk.size_pixels));
        const player_chunk = Vec2i{ player_chunk_x, player_chunk_y };

        var chunk_y: i32 = player_chunk_y - self.load_distance;
        while (chunk_y <= player_chunk_y + self.load_distance) : (chunk_y += 1) {
            var chunk_x: i32 = player_chunk_x - self.load_distance;
            while (chunk_x <= player_chunk_x + self.load_distance) : (chunk_x += 1) {
                const position = .{ chunk_x, chunk_y };

                try self.loadChunk(position);
            }
        }

        if (self.prev_chunk) |prev_chunk| {
            if (!std.meta.eql(prev_chunk, player_chunk)) {
                var unloads: std.ArrayList(Vec2i) = .empty;
                defer unloads.deinit(self.allocator);

                var it = self.chunks.valueIterator();
                while (it.next()) |chunk| {
                    const d = @abs(chunk.position - player_chunk);

                    if (@max(d[0], d[1]) > self.unload_distance) {
                        try unloads.append(self.allocator, chunk.position);
                    }
                }

                for (unloads.items) |unload| {
                    if (!self.chunks.remove(unload)) continue;

                    std.debug.print("UNLOAD CHUNK: {d} {d}\n", .{ unload[0], unload[1] });
                }
            }
        }

        self.prev_chunk = player_chunk;
    }
};

pub const InputState = struct {
    move_direction: Vec2,
};

pub fn main(init: std.process.Init) !void {
    rl.InitWindow(800, 600, "zi");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    const allocator = init.gpa;

    var world = World.init(allocator, 0xdead);
    defer world.deinit();

    var player = Player.init(.{ 0, 0 });
    var camera = Camera.init(.{ 0, 0 });

    while (!rl.WindowShouldClose()) {
        var input = InputState{
            .move_direction = .{ 0, 0 },
        };

        if (rl.IsKeyDown(rl.KEY_W)) input.move_direction[1] -= 1.0;
        if (rl.IsKeyDown(rl.KEY_S)) input.move_direction[1] += 1.0;
        if (rl.IsKeyDown(rl.KEY_A)) input.move_direction[0] -= 1.0;
        if (rl.IsKeyDown(rl.KEY_D)) input.move_direction[0] += 1.0;

        try world.loadVisibleChunks(&camera);

        player.update(input);
        camera.follow(player.position);

        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.RAYWHITE);

        rl.BeginMode2D(camera.rl_camera);

        world.draw(&camera);

        rl.EndMode2D();

        rl.DrawFPS(10, 10);
    }
}
