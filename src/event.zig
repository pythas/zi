const ResourceKind = @import("inventory.zig").ResourceKind;

pub const Event = union(enum) {
    resource_produced: struct { resource: ResourceKind, amount: u32 },
};
