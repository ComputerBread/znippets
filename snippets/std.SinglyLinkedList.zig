const std = @import("std");

// example a bunch of tasks with an order!
const Task = struct {
    data: u32,
    node: std.SinglyLinkedList.Node = .{},
};

test {
    var one: Task = .{ .data = 1, .node = .{} };
    var two: Task = .{ .data = 2 };
    var thr: Task = .{ .data = 3 };
    var fou: Task = .{ .data = 4 };
    var fiv: Task = .{ .data = 5 };

    var list: std.SinglyLinkedList = .{};
    list.prepend(&fou.node); // 4
    fou.node.insertAfter(&fiv.node); // 4, 5
    list.prepend(&thr.node); // 3, 4, 5
    list.prepend(&one.node); // 1, 3, 4, 5
    one.node.insertAfter(&two.node);

    var it = list.first;
    var nb_of_nodes: u32 = 0;
    while (it) |node| : (it = node.next) {
        const t: *Task = @fieldParentPtr("node", node);
        t.data -= 1;
        try std.testing.expectEqual(nb_of_nodes, t.data);
        nb_of_nodes += 1;
    }

    const field_ptr: *std.SinglyLinkedList.Node = &one.node;
    const d_struct_ptr: *Task = @fieldParentPtr("node", field_ptr);
    d_struct_ptr.data = 10;
    try std.testing.expectEqual(one.data, d_struct_ptr.data);
}
