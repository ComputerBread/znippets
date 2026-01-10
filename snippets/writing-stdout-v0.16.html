const std = @import("std");

test {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    // const io = std.testing.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    for (1..1_000) |i| {
        try stdout.print("{d}. Hello \n", .{i});
    }

    try stdout.flush();
}
