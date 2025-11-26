const std = @import("std");

/// Read the local "VERSIONS" file and return the list of versions that have
/// already been used to test old snippets!
/// One version per line
/// Must be sorted from OLDEST to NEWEST, master is on the last line!
pub fn getVersions(arena: std.mem.Allocator, io: std.Io) !std.ArrayList([]const u8) {

    // this will create and open the VERSIONS file if it doesn't exist!
    // otherwise it will just open it!
    const file = try std.Io.Dir.cwd().createFile(io, "VERSIONS", .{
        .read = true,
        .truncate = false,
    });
    defer file.close(io);
    var buf: [1024]u8 = undefined;
    var reader = file.reader(io, &buf);

    var versions: std.ArrayList([]const u8) = .empty;
    while (reader.interface.takeDelimiterExclusive('\n')) |version| {
        reader.interface.toss(1);
        const version_dupe = try arena.dupe(u8, version);
        try versions.append(arena, version_dupe);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    return versions;
}

const SNIPPETS_INFO_FILENAME = "SNIPPETS";

/// Return list of "OLD" snippets that have already been tested with their result.
/// {snippets, results}
pub fn getSnippets(arena: std.mem.Allocator, io: std.Io) !struct { std.ArrayList([]const u8), std.ArrayList(u64) } {
    const file = try std.Io.Dir.cwd().createFile(io, SNIPPETS_INFO_FILENAME, .{
        .read = true,
        .truncate = false,
    });
    defer file.close(io);
    var buf: [4096]u8 = undefined;
    var reader = file.reader(io, &buf);

    var snippets: std.ArrayList([]const u8) = .empty;
    var results: std.ArrayList(u64) = .empty;
    while (reader.interface.takeDelimiterExclusive('\n')) |line| {
        reader.interface.toss(1);
        var parts = std.mem.splitSequence(u8, line, ",");
        const snippet_path = parts.next() orelse return error.MalformedSnippetsFile;
        const res_str = parts.next() orelse return error.MalformedSnippetsFile;
        const res = try std.fmt.parseInt(u64, res_str, 10);

        // dupe?
        const snippet_path_dupe = try arena.dupe(u8, snippet_path);
        try snippets.append(arena, snippet_path_dupe);
        try results.append(arena, res);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    return .{ snippets, results };
}

/// Save snippets and corresponding results in SNIPPETS file.
/// snippets MUST be sorted! (maybe can do it here instead)
pub fn saveSnippetsAndResults(snippets: *std.ArrayList([]const u8), results: *std.ArrayList(u64)) !void {
    const file = try std.fs.cwd().createFile(SNIPPETS_INFO_FILENAME, .{
        .truncate = true,
    });
    defer file.close();
    var buf: [4096]u8 = undefined;
    var writer = file.writer(&buf);
    for (snippets.items, results.items) |snip, res| {
        try writer.interface.print("{s},{d}\n", .{ snip, res });
    }
    try writer.interface.flush();
}

// pub fn main() !void {
//     var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
//     const gpa = debug_allocator.allocator();
//
//     var threaded: std.Io.Threaded = .init(gpa);
//     defer threaded.deinit();
//     const io = threaded.io();
//
//     const snippets, const results = try getSnippets(gpa, io);
//     for (snippets.items, results.items) |snip, res| {
//         std.debug.print("{s} {d}", .{ snip, res });
//     }
// }
