const TileKind = @import("world.zig").TileKind;

pub const Event = union(enum) {
    ore_mined: struct { kind: TileKind, amount: u32 },
};
