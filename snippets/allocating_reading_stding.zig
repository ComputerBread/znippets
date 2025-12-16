const std = @import("std");

test {
    var reader: std.Io.Reader = .fixed("hello\nbonjour\n안녕하세요\n");

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    while (reader.streamDelimiter(&allocating_writer.writer, '\n')) |_| {
        const line = allocating_writer.written();
        _ = line;
        allocating_writer.clearRetainingCapacity(); // empty the line buffer
        reader.toss(1); // skip the newline
    } else |err| {
        try std.testing.expectEqual(error.EndOfStream, err);
    }
}
