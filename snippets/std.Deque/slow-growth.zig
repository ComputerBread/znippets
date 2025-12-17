const std = @import("std");
test "slow growth" {
    const testing = std.testing;
    const gpa = testing.allocator;

    var q: std.Deque(i32) = .empty;
    defer q.deinit(gpa);

    try q.ensureTotalCapacityPrecise(gpa, 1);
    q.pushBackAssumeCapacity(1);
    try q.ensureTotalCapacityPrecise(gpa, 2);
    q.pushFrontAssumeCapacity(0);
    try q.ensureTotalCapacityPrecise(gpa, 3);
    q.pushBackAssumeCapacity(2);
    try q.ensureTotalCapacityPrecise(gpa, 5);
    q.pushBackAssumeCapacity(3);
    q.pushFrontAssumeCapacity(-1);
    try q.ensureTotalCapacityPrecise(gpa, 6);
    q.pushFrontAssumeCapacity(-2);

    try testing.expectEqual(-2, q.popFront());
    try testing.expectEqual(-1, q.popFront());
    try testing.expectEqual(3, q.popBack());
    try testing.expectEqual(0, q.popFront());
    try testing.expectEqual(2, q.popBack());
    try testing.expectEqual(1, q.popBack());
    try testing.expectEqual(null, q.popFront());
    try testing.expectEqual(null, q.popBack());
}
