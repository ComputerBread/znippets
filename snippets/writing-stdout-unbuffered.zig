const std = @import("std");

test {
    // you can pass an emtpy slice to a Reader or Writer, no buffer will be
    // used, the data will be directly written to the sink/read from the source.
    var stdout_writer = std.fs.File.stdout().writer(&.{});
    // we take a pointer, because, that's what the functions need
    const stdout = &stdout_writer.interface;

    for (1..1_001) |i| {
        try stdout.print("{d}. Hello \n", .{i});
    }

    // don't need to flush anymore
    // try stdout.flush();
}
