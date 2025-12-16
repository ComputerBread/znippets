// from https://zig.guide/standard-library/hashmaps
// license: https://github.com/sobeston/zig.guide?tab=MIT-1-ov-file#readme
const std = @import("std");

test "string hashmap" {
    var map = std.StringHashMap(enum { cool, uncool }).init(std.testing.allocator);
    defer map.deinit();

    try map.put("loris", .uncool);
    try map.put("me", .cool);

    try std.testing.expect(map.get("me").? == .cool);
    try std.testing.expect(map.get("loris").? == .uncool);
}
