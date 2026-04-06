const std = @import("std");

pub const ResourceKind = enum {
    raw_iron,
    iron_ingot,
};

pub const Slot = struct {
    resource: ResourceKind,
    amount: u32,
};
