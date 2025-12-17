const std = @import("std");

const Bread = struct {
    proteins: u32,
    carbs: u32,
    fat: u16,
    calories: u8,
};

test {
    const mr_bread = Bread{
        .calories = 66,
        .fat = 820,
        .proteins = 1900,
        .carbs = 12650,
    };

    const good_bread: *const Bread = @fieldParentPtr("carbs", &mr_bread.carbs);
    try std.testing.expectEqual(good_bread, &mr_bread);

    try std.testing.expectEqual(&mr_bread.carbs, &good_bread.carbs);
    try std.testing.expectEqual(&mr_bread.proteins, &good_bread.proteins);
    try std.testing.expectEqual(&mr_bread.fat, &good_bread.fat);
    try std.testing.expectEqual(&mr_bread.calories, &good_bread.calories);

    try std.testing.expectEqual(&mr_bread.carbs, @as(*u32, @ptrFromInt(@intFromPtr(&mr_bread) + @offsetOf(Bread, "carbs"))));
    try std.testing.expectEqual(&mr_bread.proteins, @as(*u32, @ptrFromInt(@intFromPtr(&mr_bread) + @offsetOf(Bread, "proteins"))));
    try std.testing.expectEqual(&mr_bread.fat, @as(*u16, @ptrFromInt(@intFromPtr(&mr_bread) + @offsetOf(Bread, "fat"))));
    try std.testing.expectEqual(&mr_bread.calories, @as(*u8, @ptrFromInt(@intFromPtr(&mr_bread) + @offsetOf(Bread, "calories"))));
}
