const std = @import("std");

test {
    var in_buffer: [10]u8 = undefined;
    var in_reader: std.Io.Reader = .fixed(&in_buffer);

    // you shouldn't be able to take a bigger number of bytes than the size of
    // the input buffer!
    while (in_reader.takeArray(20)) |str| {
        _ = str;
        try std.testing.expect(false);
    } else |err| {
        try std.testing.expectEqual(error.EndOfStream, err);
    }
}
