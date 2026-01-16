const std = @import("std");

pub fn main(init: std.process.Init) !void {
    try std.Io.File.stdout().writeStreamingAll(init.io, "Welcome to the Io world!\n");
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
