const std = @import("std");
const is_debug = @import("builtin").mode == .Debug;

// written under 0.16.0-dev.1326+2e6f7d36b

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
        if (entry.path.len < 5 or !std.mem.eql(u8, ".zig", entry.path[entry.path.len - 4 ..]))
            continue;

        const path = try allocator.dupe(u8, entry.path);
        errdefer allocator.free(path);
        try paths.append(allocator, path);

        // WARN: REMOVE THIS
        if (is_debug) break; // JUST GET THE FIRST PATH AND WE'RE OUT
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

    // let's store the filenames to be able to reuse them
    var html_filenames = FilenameList.init;
    defer html_filenames.deinit(allocator);

    var threaded: std.Io.Threaded = .init(allocator);
    defer threaded.deinit();
    const io = threaded.io();

    var template_buf: [4096]u8 = undefined;
    const template_file = try std.Io.Dir.cwd().openFile(io, "template.html", .{ .mode = .read_only });
    defer template_file.close(io);
    var template_reader = template_file.reader(io, &template_buf);

    // TODO: AWKWARD MIX of Io and old stuff
    // once https://github.com/ziglang/zig/issues/25738 is done, move to Io

    // create new folder for files creation
    std.debug.print("5.2 Creating temporary output directory\n", .{});
    // first deleting it if it exists, probable cause:
    // previous execution failed, need to clean up the mess
    try std.fs.cwd().deleteTree(TMP_OUT_DIR_NAME);
    const tmp_out_dir = try std.fs.cwd().makeOpenPath(TMP_OUT_DIR_NAME, .{});

    for (snippets_paths.items, 0..) |path, snippet_idx| {
        // TODO: alright maybe be a bit careful here about the path names!
        // especially about sperators in the path...
        const new_filename = try html_filenames.allocPrintAppend(allocator, "{s}.html", .{path[0 .. path.len - 4]});
        const html_file = try tmp_out_dir.createFile(new_filename, .{});
        defer html_file.close();
        var out_buf: [4096]u8 = undefined;
        var out_writer = html_file.writer(&out_buf);

        const res = tests_results.items[snippet_idx];

        while (streamUntilTemplateStr(&template_reader.interface, &out_writer.interface)) |template_name| {
            if (std.mem.eql(u8, "TITLE", template_name)) {
                try out_writer.interface.print("{s}", .{new_filename});
            } else if (std.mem.eql(u8, "WORKING_VERSIONS", template_name)) {
                for (zig_versions, 0..) |version_name, version_idx| {
                    if (res & @as(u64, 1) << @intCast(version_idx) != 0) {
                        try out_writer.interface.print("{s} ", .{version_name});
                    }
                }
            } else if (std.mem.eql(u8, "FAILING_VERSIONS", template_name)) {
                for (zig_versions, 0..) |version_name, version_idx| {
                    if (res & @as(u64, 1) << @intCast(version_idx) == 0) {
                        try out_writer.interface.print("{s} ", .{version_name});
                    }
                }
            } else if (std.mem.eql(u8, "CODE", template_name)) {
                const snip_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ SNIPPETS_DIR_NAME, path });
                defer allocator.free(snip_path);
                var code_buf: [4096]u8 = undefined;
                const code_file = try std.Io.Dir.cwd().openFile(io, snip_path, .{ .mode = .read_only });
                defer code_file.close(io);
                var code_reader = code_file.reader(io, &code_buf);
                _ = try out_writer.interface.sendFileAll(&code_reader, .unlimited);
            }
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => std.debug.print("\n An error occured, while creating the {s} file: {}\n", .{ new_filename, err }),
        }
        try template_reader.seekTo(0);
    }

    std.debug.print("6. Jenna raiding html files for each version\n", .{});
    std.debug.print("6.1 Opening version-template.html\n", .{});

    const v_template_file = try std.Io.Dir.cwd().openFile(io, "version-template.html", .{ .mode = .read_only });
    defer v_template_file.close(io);
    // let's reuse the same buffer!
    var v_template_reader = v_template_file.reader(io, &template_buf);
    const snippet_html_file_total_count = html_filenames.list.items.len;
    _ = snippet_html_file_total_count;
    for (zig_versions, 0..) |version, version_idx| {
        const new_filename = try html_filenames.allocPrintAppend(allocator, "v{s}.html", .{version});
        const html_file = try tmp_out_dir.createFile(new_filename, .{});
        defer html_file.close();
        var out_buf: [4096]u8 = undefined;
        var out_writer = html_file.writer(&out_buf);

        while (streamUntilTemplateStr(&v_template_reader.interface, &out_writer.interface)) |template_str| {
            if (std.mem.eql(u8, "VERSION", template_str)) {
                try out_writer.interface.print("{s}", .{version});
            } else if (std.mem.eql(u8, "WORKING_SNIPPETS", template_str)) {
                for (tests_results.items, 0..) |res, snippet_idx| {
                    if (res & @as(u64, 1) << @intCast(version_idx) != 0) {
                        const snippet_html_file = html_filenames.at(snippet_idx);
                        const snippet_name = snippets_paths.items[snippet_idx];
                        try out_writer.interface.print("<a href=\"{s}\">{s}</a><br>", .{ snippet_html_file, snippet_name });
                    }
                }
            } else if (std.mem.eql(u8, "FAILING_SNIPPETS", template_str)) {
                for (tests_results.items, 0..) |res, snippet_idx| {
                    if (res & @as(u64, 1) << @intCast(version_idx) == 0) {
                        const snippet_html_file = html_filenames.at(snippet_idx);
                        const snippet_name = snippets_paths.items[snippet_idx];
                        try out_writer.interface.print("<a href=\"{s}\">{s}</a><br>", .{ snippet_html_file, snippet_name });
                    }
                }
            }
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => std.debug.print("\n An error occured, while creating the {s} file: {}\n", .{ new_filename, err }),
        }
        try out_writer.interface.flush();
        try v_template_reader.seekTo(0);
    }

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

const FilenameList = struct {
    list: std.ArrayList([]const u8),

    const Self = @This();

    pub fn allocPrintAppend(self: *Self, gpa: std.mem.Allocator, comptime fmt: []const u8, args: anytype) ![]u8 {
        const formatted = try std.fmt.allocPrint(gpa, fmt, args);
        try self.list.append(gpa, formatted);
        return formatted;
    }

    pub fn at(self: Self, idx: usize) []const u8 {
        std.debug.assert(idx < self.list.items.len);
        return self.list.items[idx];
    }

    const init = Self{
        .list = .empty,
    };

    pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
        for (self.list.items) |filename| {
            gpa.free(filename);
        }
        self.list.deinit(gpa);
    }
};

const TemplatingError = std.Io.Reader.StreamError || std.Io.Reader.DelimiterError || std.Io.Writer.Error || std.Io.File.SeekError;

/// reader is the template reader
fn streamUntilTemplateStr(reader: *std.Io.Reader, writer: *std.Io.Writer) TemplatingError![]const u8 {
    // looking for "template string" looking like "{{NAME}}"
    while (reader.streamDelimiter(writer, '{')) |_| {
        reader.toss(1);
        const next_char = reader.peekByte() catch |err| switch (err) {
            error.EndOfStream => {
                try writer.writeByte('{');
                break;
            },
            else => return err,
        };
        if (next_char != '{') {
            try writer.writeByte('{');
            continue;
        }
        // we've seen "{{"
        reader.toss(1);
        const template_str = try reader.takeDelimiterExclusive('}');
        reader.toss(2);
        try writer.flush();
        return template_str;
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    // should this be outside the function?
    // should this be called by caller?
    try writer.flush();
    return error.EndOfStream;
}
