const std = @import("std");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    std.debug.print("Getting environment variable HOME:\n", .{});
    const home = try std.process.getEnvVarOwned(gpa, "HOME");
    defer gpa.free(home);
    std.debug.print("  Home: {s}\n", .{home});

    std.debug.print("Accessing CLI arg using std.os.argv:\n", .{});
    for (std.os.argv, 0..) |arg, i| {
        std.debug.print("  arg[{d}]: {s}\n", .{ i, arg });
    }

    std.debug.print("Accessing CLI arg using std.process:\n", .{});
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    for (args, 0..) |arg, i| {
        std.debug.print("  arg[{d}]: {s}\n", .{ i, arg });
    }
}

test {
    try main();
    try std.testing.expect(true);
}
