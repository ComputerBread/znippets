const std = @import("std");
const builtin = @import("builtin");

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    while (args.next()) |arg| {
        std.debug.print("{s}\n", .{arg});
    }

    const arena = init.arena.allocator();

    std.debug.print("contains HOME: {any}\n", .{init.minimal.environ.contains(arena, "HOME")});
    std.debug.print("contains EDITOR: {any}\n", .{init.minimal.environ.containsConstant("EDITOR")});

    for (init.environ_map.keys(), init.environ_map.values()) |key, value| {
        std.debug.print("env: {s}={s}\n", .{ key, value });
    }
}

// Ignore below
test {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    var minimal: std.process.Init.Minimal = .{
        .environ = .empty,
        .args = .{ .vector = &[_][*:0]const u8{} },
    };
    var env_map = try minimal.environ.createMap(std.testing.allocator);
    try main(.{
        .minimal = minimal,
        .io = std.testing.io,
        .arena = &arena_allocator,
        .gpa = std.testing.allocator,
        .environ_map = &env_map,
        .preopens = .empty,
    });
}
