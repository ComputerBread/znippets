const std = @import("std");

test "iterator" {
    var buffer: [4]u32 = undefined;
    var q: std.Deque(u32) = .initBuffer(&buffer);
    q.pushBackAssumeCapacity(2);
    q.pushBackAssumeCapacity(3);
    q.pushFrontAssumeCapacity(1);
    q.pushFrontAssumeCapacity(0);

    var it = q.iterator();
    var i: u32 = 0;
    while (it.next()) |elem| : (i += 1) {
        try std.testing.expectEqual(i, elem);
    }
}
