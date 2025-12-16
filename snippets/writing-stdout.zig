const std = @import("std");

test {
    // Release note: Please use buffering! and don't forget to flush!!!
    var stdout_buffer: [1024]u8 = undefined;
    var stdout: std.fs.File.Writer = std.fs.File.stdout().writer(&stdout_buffer);

    // access the std.Io.Writer using the interface field
    // WARN: do not copy the interface field, because it is an intrusive interface,
    // and access the parent using @fieldParentPtr
    // BAD: var writer = stdout.interface;
    for (1..1_000) |i| {
        try stdout.interface.print("{d}. Hello \n", .{i});
    }

    // don't forget to flush
    try stdout.interface.flush();
}
