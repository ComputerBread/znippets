const std = @import("std");
const is_cooking = @import("builtin").mode == .Debug;
const builtin = @import("builtin");
const DataStore = @import("DataStore.zig");

// written under 0.16.0-dev.1326+2e6f7d36b

const seperator = eolSeparator(80);

// we are not going to test all versions of zig, so let's define the oldest one
const OLDEST_ZIG_VERSION_INCL = "0.13.0";

const SNIPPETS_DIR_NAME = "snippets";

const TMP_OUT_DIR_NAME = "tmp-out";

fn eolSeparator(comptime size: comptime_int) [size]u8 {
    return @splat('-');
}

fn getAllSnippetsPaths(gpa: std.mem.Allocator) !std.ArrayList([]const u8) {
    var paths: std.ArrayList([]const u8) = .empty;
    errdefer paths.deinit(gpa);

    var dir = try std.fs.cwd().openDir(SNIPPETS_DIR_NAME, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(gpa);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        // making sure we're dealing with a zig file!
        if (entry.path.len < 5 or !std.mem.eql(u8, ".zig", entry.path[entry.path.len - 4 ..]))
            continue;

        const path = try gpa.dupe(u8, entry.path);
        errdefer gpa.free(path);
        try paths.append(gpa, path);

        // WARN: REMOVE THIS
        //if (is_cooking) break; // JUST GET THE FIRST PATH AND WE'RE OUT
    }

    return paths;
}

fn freeSnippetsPath(gpa: std.mem.Allocator, paths: *std.ArrayList([]const u8)) void {
    for (paths.items) |path| {
        gpa.free(path);
    }
    paths.deinit(gpa);
}

fn stringLessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.ascii.orderIgnoreCase(lhs, rhs).compare(.lt);
}

pub fn main() !void {

    // 2? allocators
    // put arena before debug allocator to avoid some false positive leak
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit(); // delete this? let OS clean it at the end?
    const arena = arena_allocator.allocator();

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const gpa, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var threaded: std.Io.Threaded = .init(gpa);
    defer threaded.deinit();
    const io = threaded.io();

    std.debug.print("ZNIPPETS\n{s}\n", .{seperator});

    // 0. Testing that zigup exists -------------------------------------------
    std.debug.print("0. Testing zigup {s}\n", .{eolSeparator(80 - 17)});
    var zigup_existence_proc = std.process.Child.init(
        &.{ "sh", "-c", "command -v zigup" },
        gpa,
    );
    zigup_existence_proc.stdout_behavior = .Ignore;
    const zigup_test_existence_res = zigup_existence_proc.spawnAndWait() catch |err| {
        std.debug.print("{}\n", .{err});
        @panic("Checking the existence of zigup failed");
    };
    if (zigup_test_existence_res.Exited == 0) {
        std.debug.print("0.1 zigup was found. Proceeding...\n", .{});
    } else {
        std.debug.print(
            \\1.1 zigup was NOT found. \n
            \\    Install it or make sure it exists
            \\    Exiting!
            \\
        , .{});
        std.process.exit(1);
    }

    // 1. Get the versions
    std.debug.print("1. Acquiring the Zig versions {s}\n", .{eolSeparator(80 - 30)});
    std.debug.print("1.1 Reading VERSIONS file (if it exists)\n", .{});
    const zig_versions = try DataStore.getVersions(arena, io);
    // all old snippets have already been tested with zig_versions[0..new_version_idx]
    // new_version_idx correspond to the idx of the first version that needs to test all snippets!
    const new_version_idx = zig_versions.items.len;
    // TODO: fetch new zig versions

    // 2. Get list of snippets ------------------------------------------------
    std.debug.print("2. Getting all snippets {s}\n", .{eolSeparator(80 - 24)});
    std.debug.print("2.1 Fetching OLD snippets and results from SNIPPETS file\n", .{});
    var snippets_paths, var tests_results = try DataStore.getSnippets(arena, io);
    std.debug.print("    {d} snippets found.\n", .{snippets_paths.items.len});

    std.debug.print("2.2.1 Searching for snippets inside {s} directory\n", .{SNIPPETS_DIR_NAME});
    var snippets_paths_local = try getAllSnippetsPaths(gpa);
    std.debug.print("      {d} snippets found.\n", .{snippets_paths_local.items.len});
    // 2.1 unstable sort
    std.debug.print("2.2.2 Sorting paths by alpha order\n", .{});
    std.sort.pdq([]const u8, snippets_paths_local.items, {}, stringLessThan);

    std.debug.print("2.3 Merging OLD and NEW snippets\n", .{});
    const old_len = snippets_paths.items.len;
    const new_len = snippets_paths_local.items.len;
    if (old_len > new_len) {
        // I don't want to think about deletion for now!
        // If you want to delete a snippet, just delete it and the corresponding line
        @panic(
            \\ SNIPPETS files contains more snippets than the number of actual snippets
            \\ If a snippet was deleted, please delete the corresponding line in SNIPPETS
            \\ If some other bug, delete the SNIPPETS info file and retest the whole thing
        );
    } else if (old_len < new_len) {
        // we have 2 sorted lists, we compare each list, if a new snippet is spotted,
        // we put it at the end of the "old" list
        var old_idx: usize = 0;
        var new_idx: usize = 0;
        while (old_idx < old_len) : (new_idx += 1) {
            if (!std.mem.eql(u8, snippets_paths.items[old_idx], snippets_paths_local.items[new_idx])) {
                const new_snip = try std.mem.Allocator.dupe(arena, u8, snippets_paths_local.items[new_idx]);
                try snippets_paths.append(arena, new_snip);
                std.debug.print("    New snippet: {s}\n", .{new_snip});
                continue;
            }
            old_idx += 1;
        }
        // let's not forget to add any remaining new snippet
        while (new_idx < new_len) : (new_idx += 1) {
            const new_snip = try std.mem.Allocator.dupe(arena, u8, snippets_paths_local.items[new_idx]);
            try snippets_paths.append(arena, new_snip);
            std.debug.print("    New snippet: {s}\n", .{new_snip});
        }
        try tests_results.appendNTimes(arena, 0, new_len - old_len);
    } else { // same number of snippet
        // what if I delete a snippet and add a new one?
        // [NO.](https://www.youtube.com/watch?v=qQrvoDzzLfk)
        // don't do that, the file should be updated, if you delete a file
        // you delete the line, otherwise this is going to be a disaster
        //
        // pfft, this is not very robust, you didn't think about that didn't you?!
        // well let's keep going and assume we don't delete files! why would we
        // in the first place!

        // no new version
        if (new_version_idx == zig_versions.items.len) {
            std.debug.print("[END] Nothing new, exiting early\n", .{});
            freeSnippetsPath(gpa, &snippets_paths_local);
            return;
        }
    }
    // we can list the (new) local list, we don't need it anymore!
    freeSnippetsPath(gpa, &snippets_paths_local);

    // 3. Let's test the tests ------------------------------------------------
    std.debug.print("3. Let's test our snippets {s}\n", .{eolSeparator(80 - 27)});
    // var tests_results: std.ArrayList(u64) = .empty;
    // try tests_results.appendNTimes(arena, 0, snippets_paths.items.len);

    std.debug.print("3.1 Running the tests\n", .{});
    for (zig_versions.items, 0..) |version_name, version_idx| {
        std.debug.print("3.1.{d} Testing version {s}\n", .{ version_idx + 1, version_name });

        var zigup_process = std.process.Child.init(&.{ "zigup", version_name }, gpa);
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

        // So, here we don't need to tests the OLD snippets (i.e. the "old_len"
        // first snippets of the snippets_paths array) for the `new_version_idx`
        // first versions!
        const starting_idx = if (version_idx < new_version_idx) old_len else 0;
        std.debug.print("old_len: {d}, starting_idx: {d}, version_idx: {d}, new_version_idx {d}\n", .{ old_len, starting_idx, version_idx, new_version_idx });
        var processes: std.ArrayList(std.process.Child) = .empty;
        defer processes.deinit(gpa);
        for (snippets_paths.items[starting_idx..], 0..) |path, proc_idx| {
            std.debug.print("{d} ", .{proc_idx});
            std.debug.print("{s}\n", .{path});
            const snip_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ SNIPPETS_DIR_NAME, path });
            defer gpa.free(snip_path);
            try processes.append(
                gpa,
                std.process.Child.init(&.{ "zig", "test", snip_path }, gpa),
            );
            processes.items[proc_idx].stdout_behavior = .Ignore;
            processes.items[proc_idx].stderr_behavior = .Ignore;
            try processes.items[proc_idx].spawn();
        }
        for (processes.items, 0..) |*process, proc_idx| {
            const term: std.process.Child.Term = try process.wait();
            var failed = true;
            switch (term) {
                .Exited => |exit_code| {
                    if (exit_code == 0) {
                        tests_results.items[proc_idx + starting_idx] |= @as(u64, 1) << @intCast(version_idx);
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

    std.debug.print("4. Reporting results {s}\n", .{eolSeparator(80 - 21)});
    for (snippets_paths.items, 0..) |path, snippet_idx| {
        std.debug.print("4.{d} {s}\n", .{ snippet_idx, path });
        const res = tests_results.items[snippet_idx];
        std.debug.print("    Success: ", .{});
        for (zig_versions.items, 0..) |version_name, version_idx| {
            if (res & @as(u64, 1) << @intCast(version_idx) != 0) {
                std.debug.print("{s} ", .{version_name});
            }
        }
        std.debug.print("\n    Failure: ", .{});
        for (zig_versions.items, 0..) |version_name, version_idx| {
            if (res & @as(u64, 1) << @intCast(version_idx) == 0) {
                std.debug.print("{s} ", .{version_name});
            }
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("5. Saving results and versions in files! {s}\n", .{eolSeparator(80 - 41)});
    // 5.1 unstable sort
    std.debug.print("5.1 Sorting paths by alpha order\n", .{});
    std.sort.pdq([]const u8, snippets_paths.items, {}, stringLessThan);
    std.debug.print("5.2 Saving snippets and results\n", .{});
    try DataStore.saveSnippetsAndResults(&snippets_paths, &tests_results);

    // TODO: save versions!

    // File generation --------------------------------------------------------
    std.debug.print("6. Jenna raiding html files for each snippets {s}\n", .{eolSeparator(80 - 46)});
    std.debug.print("6.1 Opening template.html\n", .{});

    // let's store the filenames to be able to reuse them
    var html_filenames = FilenameList.init;

    var template_buf: [4096]u8 = undefined;
    const template_file = try std.Io.Dir.cwd().openFile(io, "template.html", .{ .mode = .read_only });
    defer template_file.close(io);
    var template_reader = template_file.reader(io, &template_buf);

    // TODO: AWKWARD MIX of Io and old stuff
    // once https://github.com/ziglang/zig/issues/25738 is done, move to Io

    // create new folder for files creation
    std.debug.print("6.2 Creating temporary output directory\n", .{});
    // first deleting it if it exists, probable cause:
    // previous execution failed, need to clean up the mess
    try std.fs.cwd().deleteTree(TMP_OUT_DIR_NAME);
    const tmp_out_dir = try std.fs.cwd().makeOpenPath(TMP_OUT_DIR_NAME, .{});

    for (snippets_paths.items, 0..) |path, snippet_idx| {
        // TODO: alright maybe be a bit careful here about the path names!
        // especially about sperators in the path...
        const new_filename = try html_filenames.allocPrintAppend(arena, "{s}.html", .{path[0 .. path.len - 4]});
        const html_file = try tmp_out_dir.createFile(new_filename, .{});
        defer html_file.close();
        var out_buf: [4096]u8 = undefined;
        var out_writer = html_file.writer(&out_buf);

        const res = tests_results.items[snippet_idx];

        while (streamUntilTemplateStr(&template_reader.interface, &out_writer.interface)) |template_name| {
            if (std.mem.eql(u8, "TITLE", template_name)) {
                try out_writer.interface.print("{s}", .{path});
            } else if (std.mem.eql(u8, "WORKING_VERSIONS", template_name)) {
                for (zig_versions.items, 0..) |version_name, version_idx| {
                    if (res & @as(u64, 1) << @intCast(version_idx) != 0) {
                        try out_writer.interface.print("{s} ", .{version_name});
                    }
                }
            } else if (std.mem.eql(u8, "FAILING_VERSIONS", template_name)) {
                for (zig_versions.items, 0..) |version_name, version_idx| {
                    if (res & @as(u64, 1) << @intCast(version_idx) == 0) {
                        try out_writer.interface.print("{s} ", .{version_name});
                    }
                }
            } else if (std.mem.eql(u8, "CODE", template_name)) {
                const snip_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ SNIPPETS_DIR_NAME, path });
                defer gpa.free(snip_path);
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

    std.debug.print("7. Jenna raiding html files for each version {s}\n", .{eolSeparator(80 - 45)});
    std.debug.print("7.1 Opening version-template.html\n", .{});

    const v_template_file = try std.Io.Dir.cwd().openFile(io, "version-template.html", .{ .mode = .read_only });
    defer v_template_file.close(io);
    // let's reuse the same buffer!
    var v_template_reader = v_template_file.reader(io, &template_buf);
    const snippet_html_file_total_count = html_filenames.list.items.len;
    for (zig_versions.items, 0..) |version, version_idx| {
        const new_filename = try html_filenames.allocPrintAppend(arena, "v{s}.html", .{version});
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

    std.debug.print("8. Jenna raiding index.html {s}\n", .{eolSeparator(80 - 28)});

    const index_template_file = try std.Io.Dir.cwd().openFile(io, "index-template.html", .{ .mode = .read_only });
    defer index_template_file.close(io);
    // let's reuse the same buffer!
    var index_template_reader = index_template_file.reader(io, &template_buf);

    const index_html = try tmp_out_dir.createFile("index.html", .{});
    defer index_html.close();
    var out_buf: [4096]u8 = undefined;
    var out_writer = index_html.writer(&out_buf);
    while (streamUntilTemplateStr(&index_template_reader.interface, &out_writer.interface)) |template_str| {
        if (std.mem.eql(u8, "SNIPPETS", template_str)) {
            for (0..snippet_html_file_total_count) |snippet_idx| {
                const snippet_html_file = html_filenames.at(snippet_idx);
                const snippet_name = snippets_paths.items[snippet_idx];
                try out_writer.interface.print("<a href=\"{s}\">{s}</a><br>", .{ snippet_html_file, snippet_name });
            }
        } else if (std.mem.eql(u8, "VERSIONS", template_str)) {
            for (snippet_html_file_total_count.., zig_versions.items) |idx, version_name| {
                const version_html_filename = html_filenames.at(idx);
                try out_writer.interface.print("<a href=\"{s}\">{s}</a><br>", .{ version_html_filename, version_name });
            }
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => std.debug.print("\n An error occured, while creating the index.html file: {}\n", .{err}),
    }
    try out_writer.interface.flush();
    // {{VERSIONS}}
    // {{SNIPPETS}}
    return;
    //
    // var processes: [zig_versions.len]std.process.Child = undefined;
    // for (zig_versions, 0..) |version, idx| {
    //     var buf: [100]u8 = undefined;
    //     const msg = try std.fmt.bufPrint(&buf, "'Hello world, version: {s}'", .{version});
    //     processes[idx] = std.process.Child.init(&.{ "echo", msg }, gpa);
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

    pub fn allocPrintAppend(self: *Self, arena: std.mem.Allocator, comptime fmt: []const u8, args: anytype) ![]u8 {
        const formatted = try std.fmt.allocPrint(arena, fmt, args);
        try self.list.append(arena, formatted);
        return formatted;
    }

    pub fn at(self: Self, idx: usize) []const u8 {
        std.debug.assert(idx < self.list.items.len);
        return self.list.items[idx];
    }

    const init = Self{
        .list = .empty,
    };
};

const TemplatingError = std.Io.Reader.StreamError || std.Io.Reader.DelimiterError || std.Io.Writer.Error || std.Io.File.SeekError;

/// Function used to read a HTML template, with some template string like
/// `{{TITLE}}`. Takes the reader of a template, and writes all the content of
/// the template until it finds a `{{template_string}}`. Once it finds a `{{`,
/// it extracts the string and returns it, so that caller can replace it with
/// whatever...
/// Returns `error.EndOfStream` once it's done
/// Should this function actually flush the writer?
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
