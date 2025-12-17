const std = @import("std");
test "buffer" {
    var buffer: [4]u32 = undefined;
    var q: std.Deque(u32) = .initBuffer(&buffer);

    try std.testing.expectEqual(null, q.popFront());
    try std.testing.expectEqual(null, q.popBack());

    q.pushBackAssumeCapacity(2);
    try q.pushBackBounded(3);
    q.pushFrontAssumeCapacity(1);
    try q.pushFrontBounded(0);

    try std.testing.expectError(error.OutOfMemory, q.pushBackBounded(4));

    try std.testing.expectEqual(0, q.popFront());
    try std.testing.expectEqual(1, q.popFront());
    try std.testing.expectEqual(3, q.popBack());
    try std.testing.expectEqual(2, q.popFront());
    try std.testing.expectEqual(null, q.popFront());
    try std.testing.expectEqual(null, q.popBack());
}

test "2" {
    var buffer: [4]u32 = undefined;
    var q: std.Deque(u32) = .initBuffer(&buffer);

    q.pushBackAssumeCapacity(2);
    try q.pushBackBounded(3);
    q.pushFrontAssumeCapacity(1);
    try q.pushFrontBounded(0);

    try std.testing.expectEqual(0, q.front());
    try std.testing.expectEqual(3, q.back());

    try std.testing.expectEqual(3, q.popBack());
    try std.testing.expectEqual(0, q.popFront());
}
