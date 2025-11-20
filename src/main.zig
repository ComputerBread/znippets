const std = @import("std");

// written under 0.16.0-dev.1301+cbfa87cbe

const seperator = eolSeparator(80);

const zig_versions: [4][]const u8 = .{ "0.13.0", "0.14.1", "0.15.2", "0.16.0-dev.1326+2e6f7d36b" };

const SNIPPETS_DIR_NAME = "snippets";

const TMP_OUT_DIR_NAME = "tmp-out";

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

        // making sure we're dealing with a zig file!
        if (entry.path < 5 or !std.mem.eql(u8, ".zig", entry.path[entry.path.len-4..]))
            continue;

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

    // 3. Let's test the tests ------------------------------------------------
    std.debug.print("3. Let's test our snippets\n", .{});
    var tests_results: std.ArrayList(u64) = .empty;
    defer tests_results.deinit(allocator);
    try tests_results.appendNTimes(allocator, 0, snippets_paths.items.len);

    std.debug.print("3.1 Running the tests\n", .{});
    for (zig_versions, 0..) |version_name, version_idx| {
        //
        std.debug.print("3.1.{d} Testing version {s}\n", .{ version_idx + 1, version_name });

        var zigup_process = std.process.Child.init(&.{ "zigup", version_name }, allocator);
        zigup_process.stderr_behavior = .Ignore;
        const zigup_term = try zigup_process.spawnAndWait();
        switch (zigup_term) {
            .Exited => |exit_code| {
                if (exit_code != 0) {
                    std.debug.print("Something went wrong with zigup\n", .{});
                    continue;
                }
            },
            else => std.debug.print("Something went wrong with zigup\n", .{}),
        }

        var processes: std.ArrayList(std.process.Child) = .empty;
        defer processes.deinit(allocator);
        for (snippets_paths.items, 0..) |path, snippet_idx| {
            const snip_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ SNIPPETS_DIR_NAME, path });
            defer allocator.free(snip_path);
            try processes.append(
                allocator,
                std.process.Child.init(&.{ "zig", "test", snip_path }, allocator),
            );
            processes.items[snippet_idx].stdout_behavior = .Ignore;
            processes.items[snippet_idx].stderr_behavior = .Ignore;
            try processes.items[snippet_idx].spawn();
        }
        for (processes.items, 0..) |*process, snip_idx| {
            const term: std.process.Child.Term = try process.wait();
            var failed = true;
            switch (term) {
                .Exited => |exit_code| {
                    if (exit_code == 0) {
                        tests_results.items[snip_idx] |= @as(u64, 1) << @intCast(version_idx);
                        failed = false;
                    }
                },
                else => {
                    // idk what happens here
                    std.debug.print("Unexpected behavior: Term was not .Exited \n", .{});
                },
            }
        }
    }

    std.debug.print("4. Reporting results\n", .{});
    for (snippets_paths.items, 0..) |path, snippet_idx| {
        std.debug.print("4.{d} {s}\n", .{ snippet_idx, path });
        const res = tests_results.items[snippet_idx];
        std.debug.print("    Success: ", .{});
        for (zig_versions, 0..) |version_name, version_idx| {
            if (res & @as(u64, 1) << @intCast(version_idx) != 0) {
                std.debug.print("{s} ", .{version_name});
            }
        }
        std.debug.print("\n    Failure: ", .{});
        for (zig_versions, 0..) |version_name, version_idx| {
            if (res & @as(u64, 1) << @intCast(version_idx) == 0) {
                std.debug.print("{s} ", .{version_name});
            }
        }
        std.debug.print("\n", .{});
    }

    // File generation --------------------------------------------------------
    std.debug.print("5. Jenna raiding html files for each snippets\n", .{});
    std.debug.print("5.1 Opening template.html\n", .{});

    var threaded: std.Io.Threaded = .init(allocator);
    defer threaded.deinit();
    const io = threaded.io();

    var template_buf: [4096]u8 = undefined;
    const template_file = try std.Io.Dir.cwd().openFile(io, "template.html", .{ .mode = .read_only });
    defer template_file.close(io);
    const template_reader = template_file.reader(io, &template_buf);

    // TODO: AWKWARD MIX of Io and old stuff
    // once https://github.com/ziglang/zig/issues/25738 is done, move to Io

    // create new folder for files creation
    std.debug.print("5.2 Creating temporary output directory\n", .{});
    // first deleting it if it exists, probable cause:
    // previous execution failed, need to clean up the mess
    try std.fs.cwd().deleteTree(TMP_OUT_DIR_NAME);
    const tmp_out_dir = try std.fs.cwd().makeOpenPath(io, TMP_OUT_DIR_NAME, .{});

    for (snippets_paths) |path| {
        // TODO: alright maybe be a bit careful here about the path names!
        // especially about sperators in the path...
        const new_filename = try std.fmt.allocPrint(allocator, "{s}.html", .{path[0 .. path.len - 4]});
        const html_file = try tmp_out_dir.createFile(io, new_filename, .{});
        defer html_file.close();
        var out_buf: [4096]u8 = undefined;
        const out_writer = html_file.writer(&out_buf);

        while (template_reader.interface.streamDelimiter(&out_writer.interface, '{')) {

            const next_char = template_reader.interface.peekByte();
            if (try ) |
        }


    }
    template_reader.interface.

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
