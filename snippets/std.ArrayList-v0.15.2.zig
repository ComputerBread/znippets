const std = @import("std");
const gpa = std.testing.allocator;

test {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);

    try list.append(gpa, 'H');
    try list.append(gpa, 'e');
    try list.append(gpa, 'l');
    try list.append(gpa, 'l');
    try list.append(gpa, 'o');
    try list.appendSlice(gpa, " World!");

    try std.testing.expectEqualStrings(list.items, "Hello World!");
}
