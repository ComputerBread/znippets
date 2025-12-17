const std = @import("std");
test "buffer" {
    const testing = std.testing;

    var buffer: [4]u32 = undefined;
    var q: std.Deque(u32) = .initBuffer(&buffer);

    try testing.expectEqual(null, q.popFront());
    try testing.expectEqual(null, q.popBack());

    try q.pushBackBounded(1);
    try q.pushBackBounded(2);
    try q.pushBackBounded(3);
    try q.pushFrontBounded(0);
    try testing.expectError(error.OutOfMemory, q.pushBackBounded(4));

    try testing.expectEqual(0, q.popFront());
    try testing.expectEqual(1, q.popFront());
    try testing.expectEqual(3, q.popBack());
    try testing.expectEqual(2, q.popFront());
    try testing.expectEqual(null, q.popFront());
    try testing.expectEqual(null, q.popBack());
}
