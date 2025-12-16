const std = @import("std");
test "arraylist" {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    try list.append('H');
    try list.append('e');
    try list.append('l');
    try list.append('l');
    try list.append('o');
    try list.appendSlice(" World!");

    try std.testing.expectEqualStrings(list.items, "Hello World!");
}
