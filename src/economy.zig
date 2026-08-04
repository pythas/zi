const std = @import("std");

const ResourceKind = @import("inventory.zig").ResourceKind;

pub const BuildingKind = enum {
    drill,
    smelter,
    storage,
};

pub const BuildingCost = std.EnumMap(ResourceKind, u32);

pub fn getCost(building_kind: BuildingKind) BuildingCost {
    var cost = BuildingCost.initFull(0);

    switch (building_kind) {
        .drill => {
            cost.put(.raw_iron, 50);
        },
        .smelter => {
            cost.put(.raw_iron, 50);
        },
        .storage => {
            cost.put(.iron_ingot, 50);
        },
    }

    return cost;
}
