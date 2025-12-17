const std = @import("std");

test "basic enum" {
    const Status = enum {
        ok,
        bad_request,
        unauthorized,
        not_found,
        internal_server_error,
    };
    _ = Status.ok;
}

test "basic enum with tag type" {
    const Status = enum(u10) {
        ok,
        bad_request,
        unauthorized,
        not_found,
        internal_server_error,
    };
    try std.testing.expectEqual(0, @intFromEnum(Status.ok));
    try std.testing.expectEqual(1, @intFromEnum(Status.bad_request));
    try std.testing.expectEqual(2, @intFromEnum(Status.unauthorized));
    try std.testing.expectEqual(3, @intFromEnum(Status.not_found));
    try std.testing.expectEqual(4, @intFromEnum(Status.internal_server_error));
}

test "overriden ordinal values" {
    const Status = enum(u10) {
        ok = 200,
        bad_request = 400,
        unauthorized = 401,
        not_found = 404,
        internal_server_error = 500,
    };
    try std.testing.expectEqual(200, @intFromEnum(Status.ok));
    try std.testing.expectEqual(400, @intFromEnum(Status.bad_request));
    try std.testing.expectEqual(401, @intFromEnum(Status.unauthorized));
    try std.testing.expectEqual(404, @intFromEnum(Status.not_found));
    try std.testing.expectEqual(500, @intFromEnum(Status.internal_server_error));
}
