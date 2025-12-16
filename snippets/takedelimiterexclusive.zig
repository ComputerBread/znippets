const std = @import("std");

test {

    // var stdin_buffer: [10]u8 = undefined;
    // var stdin: std.fs.File = std.fs.File.stdin();
    // var stdin_reader: std.fs.File.Reader = stdin.reader(&stdin_buffer);
    var reader: std.Io.Reader = .fixed("hello\nbonjour\n안녕하세요\n");

    // use `stdin_reader.interface` instead to read stdin!
    var i: u32 = 0;
    while (reader.takeDelimiterExclusive('\n')) |str| : (i += 1) {
        try switch (i) {
            0 => std.testing.expectEqualStrings("hello", str),
            1 => std.testing.expectEqualStrings("bonjour", str),
            2 => std.testing.expectEqualStrings("안녕하세요", str),
            else => unreachable,
        };
        // toss the `\n`
        reader.toss(1);
    } else |err| {
        // once reader has read everything, takeDelimiterExclusive returns error.EndOfStream
        try std.testing.expectEqual(error.EndOfStream, err);
    }
}
