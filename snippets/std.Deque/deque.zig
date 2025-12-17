const std = @import("std");

test {
    const alloc = std.testing.allocator;
    var q: std.Deque(u32) = .empty;
    defer q.deinit(alloc);

    try q.pushBack(alloc, 1);
    try q.pushBack(alloc, 2);
    try q.pushFront(alloc, 0);

    var it = q.iterator();
    var res: u32 = 0;
    while (it.next()) |el| : (res += 1) {
        try std.testing.expectEqual(res, el);
    }
}
