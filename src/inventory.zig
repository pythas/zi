const std = @import("std");

pub const ResourceKind = enum {
    raw_iron,
    iron_ingot,
};

pub const Inventory = struct {
    items: std.EnumMap(ResourceKind, u64),

    const Self = @This();

    pub fn init() Self {
        return .{
            .items = std.EnumMap(ResourceKind, u64).initFull(0),
        };
    }
};
