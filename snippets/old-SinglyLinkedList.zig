test {
    const T = struct {
        stuff: u32 = 1,
    };
    const L = SinglyLinkedList(T);
    var list = L{};

    var d: [3]T = @splat(.{});
    var one = L.Node{ .data = d[0] };
    var two = L.Node{ .data = d[1] };
    var five = L.Node{ .data = d[2] };

    list.prepend(&two); // {2}
    two.insertAfter(&five); // {2, 5}
    list.prepend(&one); // {1, 2, 5}

    d[0].stuff *= 10;
    d[1].stuff *= 11;
    d[2].stuff *= 12;

    var it = list.first;
    var i: usize = 0;
    while (it) |node| : (it = node.next) {
        try std.testing.expect(node.data.stuff != d[i].stuff);
        i += 1;
    }
}

const std = @import("std");
const SinglyLinkedList = std.SinglyLinkedList;
