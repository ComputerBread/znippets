const std = @import("std");

test "non-exhaustive enum" {

    // Non-exhaustive enums must specify a tag type
    // and cannot consume every enumeration value (otherwise it becomes exhaustive)!
    const Status = enum(u10) {
        ok = 200,
        bad_request = 400,
        unauthorized = 401,
        not_found = 404,
        internal_server_error = 500,
        _, // <-- trailing underscore
    };

    std.debug.print("200: {}, other: {}\n", .{ @as(Status, @enumFromInt(200)), @as(Status, @enumFromInt(2)) });
    const util = struct {
        fn doSmth(status: Status) void {
            switch (status) {
                _ => std.debug.print("unknown {}\n", .{status}),
                else => std.debug.print("known status: {}\n", .{status}),
            }
        }
    };

    util.doSmth(.bad_request);
    util.doSmth(@enumFromInt(10));
}

test "toString" {
    const Status = enum(u10) {
        ok = 200,
        bad_request = 400,
        unauthorized = 401,
        not_found = 404,
        internal_server_error = 500,
        _, // <-- trailing underscore

        pub fn toString(self: @This()) []const u8 {
            return switch (self) {
                .ok => "OK",
                .bad_request => "Bad Request",
                .unauthorized => "Unauthorized",
                .not_found => "Not Found",
                .internal_server_error => "Oh Hell Nah",
                _ => "Unhandled",
            };
        }
    };

    try std.testing.expectEqual("OK", Status.ok.toString());
    try std.testing.expectEqual("Bad Request", Status.toString(.bad_request));
    try std.testing.expectEqual("Unhandled", Status.toString(@enumFromInt(418)));
}

// you can use both _ and else in a switch!
test "toString, _ and else" {
    const Status = enum(u10) {
        ok = 200,
        bad_request = 400,
        unauthorized = 401,
        not_found = 404,
        internal_server_error = 500,
        _, // <-- trailing underscore

        pub fn toString(self: @This()) []const u8 {
            return switch (self) {
                .ok => "OK",
                .bad_request => "Bad Request",
                .unauthorized => "Unauthorized",
                else => "not_found and internal_server_error",
                _ => "Unhandled",
            };
        }
    };

    try std.testing.expectEqual("OK", Status.ok.toString());
    try std.testing.expectEqual("not_found and internal_server_error", Status.toString(.not_found));
    try std.testing.expectEqual("Unhandled", Status.toString(@enumFromInt(418)));
}

test "toString, mixing _ and named tag" {
    const Status = enum(u10) {
        ok = 200,
        bad_request = 400,
        unauthorized = 401,
        not_found = 404,
        internal_server_error = 500,
        _, // <-- trailing underscore

        pub fn toString(self: @This()) []const u8 {
            return switch (self) {
                .ok => "OK",
                .bad_request => "Bad Request",
                .unauthorized => "Unauthorized",
                else => "internal_server_error",
                .not_found, _ => "Unhandled", // can mix _ and a named tag
                // you can NOT mix _ and else
            };
        }
    };

    try std.testing.expectEqual("OK", Status.ok.toString());
    try std.testing.expectEqual("internal_server_error", Status.toString(.internal_server_error));
    try std.testing.expectEqual("Unhandled", Status.not_found.toString());
    try std.testing.expectEqual("Unhandled", Status.toString(@enumFromInt(418)));
}
