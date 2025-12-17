const std = @import("std");

test "empty init" {
    const gpa = std.testing.allocator;
    var q: std.Deque(u32) = try .initCapacity(gpa, 4);
    defer q.deinit(gpa);

    try std.testing.expectEqual(null, q.popFront());
    try std.testing.expectEqual(null, q.popBack());

    try q.pushBack(gpa, 1);
    try q.pushBack(gpa, 2);
    try q.pushFront(gpa, 0);
    try q.pushBack(gpa, 3);

    try std.testing.expectEqual(0, q.popFront());
    try std.testing.expectEqual(1, q.popFront());
    try std.testing.expectEqual(3, q.popBack());
    try std.testing.expectEqual(2, q.popFront());
    try std.testing.expectEqual(null, q.popFront());
    try std.testing.expectEqual(null, q.popBack());
}
