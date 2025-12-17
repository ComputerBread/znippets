const std = @import("std");
test "at" {
    var buffer: [4]u32 = undefined;
    var q: std.Deque(u32) = .initBuffer(&buffer);

    q.pushBackAssumeCapacity(2);
    q.pushBackAssumeCapacity(3);
    q.pushFrontAssumeCapacity(1);
    q.pushFrontAssumeCapacity(0);
    // [0, 1, 2, 3] -> queue

    for (0..q.len) |i| {
        try std.testing.expectEqual(i, q.at(i));
    }
}
