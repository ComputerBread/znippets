const std = @import("std");
const builtin = @import("builtin");

pub fn main(init: std.process.Init.Minimal) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    // ------------------------------------------------------------------------
    // CLI ARGUMENTS, using iterateAllocator()
    var i: u32 = 0;
    var args = try init.args.iterateAllocator(gpa);
    args.deinit();
    while (args.next()) |arg| : (i += 1) {
        std.debug.print("arg[{d}]={s}\n", .{ i, arg });
    }

    // ------------------------------------------------------------------------
    // CLI ARGUMENTS, using iterate()
    var args2 = init.args.iterate();
    while (args2.next()) |arg| {
        std.debug.print("{s}\n", .{arg});
    }

    // ------------------------------------------------------------------------
    // CLI ARGUMENTS, using toSlice
    var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    // must use an "arena-style allocator"
    const args3 = try init.args.toSlice(arena);
    for (args3) |arg| {
        std.debug.print("arg: {s}\n", .{arg});
    }

    // ------------------------------------------------------------------------
    // ENVIRONMENT VARIABLES
    std.debug.print("contains HOME: {any}\n", .{init.environ.contains(arena, "HOME")});
    std.debug.print("contains HOME (unempty): {any}\n", .{init.environ.containsUnempty(arena, "HOME")});
    std.debug.print("contains EDITOR: {any}\n", .{init.environ.containsConstant("EDITOR")});
    std.debug.print("contains EDITOR (unempty): {any}\n", .{init.environ.containsUnemptyConstant("EDITOR")});

    std.debug.print("EDITOR: {s}\n", .{try init.environ.getAlloc(arena, "HOME")});
    if (builtin.os.tag == .windows) {
        std.debug.print("HOME: {?s}\n", .{init.environ.getWindows("HOME")});
    } else if (builtin.os.tag != .wasi or builtin.link_libc) {
        std.debug.print("HOME: {?s}\n", .{init.environ.getPosix("HOME")});
    }

    const environ_map = try init.environ.createMap(arena);
    for (environ_map.keys(), environ_map.values()) |key, value| {
        std.debug.print("env: {s}={s}\n", .{ key, value });
    }
}

// Ignore below
test {
    try main(.{
        .environ = .{ .block = &.{"HOME='/home'"} },
        .args = .{ .vector = &[_][*:0]const u8{} },
    });
}
