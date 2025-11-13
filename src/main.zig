const std = @import("std");

// written under 0.16.0-dev.1301+cbfa87cbe

const seperator = eolSeparator(80);

const zig_versions: [3][]const u8 = .{ "0.13.0", "0.14.1", "0.15.2" };

const SNIPPETS_DIR_NAME = "snippets";

fn eolSeparator(comptime size: comptime_int) [size]u8 {
    return @splat('-');
}

fn getAllSnippetsPaths(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var paths: std.ArrayList([]const u8) = .empty;
    errdefer paths.deinit(allocator);

    var dir = try std.fs.cwd().openDir(SNIPPETS_DIR_NAME, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        const path = try allocator.dupe(u8, entry.path);
        errdefer allocator.free(path);
        try paths.append(allocator, path);
    }

    return paths;
}

fn freeSnippetsPath(allocator: std.mem.Allocator, paths: *std.ArrayList([]const u8)) void {
    for (paths.items) |path| {
        allocator.free(path);
    }
    paths.deinit(allocator);
}

fn stringLessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.ascii.orderIgnoreCase(lhs, rhs).compare(.lt);
}

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    std.debug.print("ZNIPPETS\n{s}\n", .{seperator});

    // 1. Testing that zigup exists -------------------------------------------
    std.debug.print("1. Testing zigup {s}\n", .{eolSeparator(80 - 17)});
    var zigup_existence_proc = std.process.Child.init(
        &.{ "sh", "-c", "command -v zigup" },
        allocator,
    );
    zigup_existence_proc.stdout_behavior = .Ignore;
    const zigup_test_existence_res = zigup_existence_proc.spawnAndWait() catch |err| {
        std.debug.print("{}\n", .{err});
        @panic("Checking the existence of zigup failed");
    };
    if (zigup_test_existence_res.Exited == 0) {
        std.debug.print("1.1 zigup was found. Proceeding...\n", .{});
    } else {
        std.debug.print(
            \\1.1 zigup was NOT found. \n
            \\    Install it or make sure it exists
            \\    Exiting!
            \\
        , .{});
        std.process.exit(1);
    }

    // 2. Get list of snippets ------------------------------------------------
    std.debug.print("2. Listing all snippets {s}\n", .{eolSeparator(80 - 24)});
    std.debug.print("2.1 Searching for snippets inside {s} directory\n", .{SNIPPETS_DIR_NAME});
    var snippets_paths = try getAllSnippetsPaths(allocator);
    defer freeSnippetsPath(allocator, &snippets_paths);
    std.debug.print("    {d} snippets found.\n", .{snippets_paths.items.len});

    // 2.1 unstable sort
    std.debug.print("2.2 Sorting paths by alpha order\n", .{});
    std.sort.pdq([]const u8, snippets_paths.items, {}, stringLessThan);

    return;
    //
    // var processes: [zig_versions.len]std.process.Child = undefined;
    // for (zig_versions, 0..) |version, idx| {
    //     var buf: [100]u8 = undefined;
    //     const msg = try std.fmt.bufPrint(&buf, "'Hello world, version: {s}'", .{version});
    //     processes[idx] = std.process.Child.init(&.{ "echo", msg }, allocator);
    //     try processes[idx].spawn();
    // }
    //
    // for (&processes) |*process| {
    //     _ = try process.wait();
    // }
}
