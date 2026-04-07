const std = @import("std");

pub const ResourceKind = enum {
    raw_iron,
    iron_ingot,

    const Self = @This();

    pub fn toLabel(self: Self) []const u8 {
        return switch (self) {
            .raw_iron => "Raw iron",
            .iron_ingot => "Iron ingot",
        };
    }
};

pub const Slot = struct {
    resource: ResourceKind,
    amount: u32,
};
