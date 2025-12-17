const std = @import("std");
test "at" {
    var buffer: [4]u32 = undefined;
    var q: std.Deque(u32) = .initBuffer(&buffer);

    q.pushBackAssumeCapacity(2);
    q.pushBackAssumeCapacity(3);
    q.pushFrontAssumeCapacity(1);
    q.pushFrontAssumeCapacity(0);
    // [0, 1, 2, 3] -> queue

    try std.testing.expectEqual(0, q.at(0));
    try std.testing.expectEqual(1, q.at(1));
    try std.testing.expectEqual(2, q.at(2));
    try std.testing.expectEqual(3, q.at(3));

    // [2, 3, 0, 1] -> buffer
    try std.testing.expectEqual(2, buffer[0]);
    try std.testing.expectEqual(3, buffer[1]);
    try std.testing.expectEqual(0, buffer[2]);
    try std.testing.expectEqual(1, buffer[3]);
}
