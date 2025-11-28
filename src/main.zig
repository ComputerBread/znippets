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

inline fn assert(ok: bool, message: []const u8) void {
    if (!ok) {
        @panic(message);
    }
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
    var zig_versions = try DataStore.getVersions(arena, io);
    // versions are sorted from oldest to newest, last line = master
    // all old snippets have already been tested with zig_versions[0..new_version_idx]
    // new_version_idx correspond to the idx of the first version that needs to test all snippets!
    var new_version_idx = zig_versions.items.len;

    std.debug.print("1.2 Looking for new available versions\n", .{});
    // let's fetch all existing versions and add the newest one!
    // If there's a new master (dev) version, then it replaces the existing one
    // If there's a new release it's added to the list too
    // all versions are sorted newest first
    const all_versions = ver_blk: {
        if (is_debug) {
            std.debug.print("USING STUB\n", .{});
            break :ver_blk try @import("./version.zig").fetchZigVersions(gpa, arena, io);
        } else {
            break :ver_blk try fetchZigVersions(gpa, arena, io); // could catch error and continue
        }
    };
    assert(all_versions.items.len != 0, "No version was fetched remotely, that's not normally!");
    // make your life easier by having oldest first, like zig_versions
    // it's easier to store the tests' results that way
    // (it's not that it's hard, but I don't really want to change anything right meow)
    std.mem.reverse([]const u8, all_versions.items);

    // TODO:
    // - clean things up
    //  - organize thoughts/summarize in "readme"
    //    (look at the comments & code)
    // - do a bunch of tests:
    //  - emtpy versions file, only 1 version in file ...

    if (zig_versions.items.len == 0) {
        std.debug.print("DEBUG zig_versions empty\n", .{});
        // so VERSIONS file is empty
        // need to fill it with all_versions starting with OLDEST_ZIG_VERSION_INCL
        // INFO: OLDEST_ZIG_VERSION_INCL could become a (CLI) argument!

        var starting_idx: usize = 0;
        for (all_versions.items) |ver| {
            if (std.mem.eql(u8, OLDEST_ZIG_VERSION_INCL, ver)) {
                break;
            }
            starting_idx += 1;
        }
        // empty file + no matching version? really?
        assert(starting_idx < all_versions.items.len, "VERSIONS file empty and couldn't find OLDEST_ZIG_VERSION_INCL");

        try zig_versions.appendSlice(arena, all_versions.items[starting_idx..]);

        // otherwise, if not empty, we assume a previous normal run that filled VERSIONS
        // so last element should be the master branch!
    } else if (zig_versions.items.len == 1) {
        // this is fishy, I don't like it
        // 🤔 I should probably delete this and panic instead

        std.debug.print("DEBUG zig_version 1 element\n", .{});
        // only one version in this file
        // two cases:
        // - it's a master/dev version which means we may have no match
        // - it's a release and we can find it
        // - offbyoneerror: some garbage in the file => assume it's a master version
        var starting_idx: usize = 0;
        for (all_versions.items) |ver| {
            starting_idx += 1;
            if (std.mem.eql(u8, zig_versions.items[0], ver)) {
                break;
            }
        }
        if (starting_idx > all_versions.items.len) {
            std.debug.print(
                \\No matching version was found!
                \\Assuming that you are looking for an old master (dev) version!
                \\We do not do that here! Only the freshest master is at the menu!
                \\So, that's what you will get
            , .{});
            arena.free(zig_versions.pop().?);
            new_version_idx -= 1;
            // let's add the last "stable" release and the master
            // if we only add the master, we will be stuck in a never ending
            // cycle of replacing the master branch!
            try zig_versions.append(arena, all_versions.items[all_versions.items.len - 2]);
            try zig_versions.append(arena, all_versions.items[all_versions.items.len - 1]);
        } else {
            if (starting_idx != all_versions.items.len) {
                new_version_idx -= 1;
            }
            // here starting_idx can be == to all_versions.items.len and it's fine!
            // it just means that the only element of zig_versions is the latest master!
            try zig_versions.appendSlice(arena, all_versions.items[starting_idx..]);
        }
    } else if (!std.mem.eql(u8, zig_versions.items[zig_versions.items.len - 1], all_versions.items[all_versions.items.len - 1])) {
        // TODO: ^^^ create a function like areMasterVersionsMatching (easier to read + give intent)
        //
        // if masters are different there is at least one new version to test
        // what if there's a new release but not a new master, would that be possible?
        std.debug.print("DEBUG zig_versions master not matching local master\n", .{});
        arena.free(zig_versions.pop().?); // pop old master, freeing probably does nothing here
        new_version_idx -= 1;
        var i: usize = 1;
        // search for the last (newest) corresponding version
        while (!std.mem.eql(u8, zig_versions.items[zig_versions.items.len - 1], all_versions.items[all_versions.items.len - 1 - i])) {
            i += 1;
        }
        const starting_idx = all_versions.items.len - i;
        try zig_versions.appendSlice(arena, all_versions.items[starting_idx..]);
    }
    // else: masters are matching
    // WARN: assume there cannot be a new release if no new master,
    // should be a pretty safe assumption!

    std.debug.print("1.3 Printing the versions to test\n", .{});
    for (zig_versions.items) |ver| {
        std.debug.print("{s}\n", .{ver});
    }

    // TODO: free all_versions

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
    std.debug.print("5.1 Sorting paths by alpha order and results\n", .{});
    // 5.1 unstable sort
    // std.sort.pdq([]const u8, snippets_paths.items, {}, stringLessThan);
    // ^^^^^ pfft I forgot I need to sort the results as well
    // how did I not think about that? [am I stupid?](https://tenor.com/Xjyl.gif)
    sortPathAndResBecauseImStupidAndMultiArraylistWouldProbablyBeBetterButIjustWantToGetSmthWorkingNow(&snippets_paths, &tests_results);
    std.debug.print("5.2 Saving snippets and results\n", .{});
    for (tests_results.items) |res| {
        std.debug.print("res: {d}\n", .{res});
    }
    try DataStore.saveSnippetsAndResults(&snippets_paths, &tests_results);

    try DataStore.saveVersions(&zig_versions);

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

    std.debug.print("9. Minify html files {s}\n", .{eolSeparator(80 - 21)});
    minifyGeneratedFiles(gpa);

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

/// Fetch list of existing zig version from https://ziglang.org/download/index.json,
/// parse the json file and returns an arraylist.
/// WARN: Assumption: versions are sorted from newest to oldest in the json file;
///
/// arena is used to store the arraylist and the strings!
fn fetchZigVersions(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io) !std.ArrayList([]const u8) {
    var http_client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer http_client.deinit();

    var res_body = std.Io.Writer.Allocating.init(gpa);
    defer res_body.deinit();

    var response = try http_client.fetch(.{
        .method = .GET,
        .location = .{ .url = "https://ziglang.org/download/index.json" },
        .response_writer = &res_body.writer,
    });
    if (response.status != .ok) {
        return error.FetchingError;
    }
    std.debug.print("{s}\n", .{res_body.written()});

    const parsed = try std.json.parseFromSlice(std.json.Value, gpa, res_body.written(), .{});
    defer parsed.deinit();

    var versions: std.ArrayList([]const u8) = .empty;

    if (parsed.value == .object) {
        var it = parsed.value.object.iterator();
        while (it.next()) |entry| {
            // Each entry is a release (e.g., "master", "0.15.2", etc.)
            if (entry.value_ptr.* == .object) {
                if (entry.value_ptr.object.get("version")) |version_value| {
                    if (version_value == .string) {
                        const version = try arena.dupe(u8, version_value.string);
                        try versions.append(arena, version);
                    }
                } else {
                    const version = try arena.dupe(u8, entry.key_ptr.*);
                    try versions.append(arena, version);
                }
            }
        }
    }

    // std.debug.print("Found {} versions:\n", .{versions.items.len});
    // for (versions.items) |version| {
    //     std.debug.print("  - {s}\n", .{version});
    // }

    return versions;
}

fn sortPathAndResBecauseImStupidAndMultiArraylistWouldProbablyBeBetterButIjustWantToGetSmthWorkingNow(snip: *std.ArrayList([]const u8), res: *std.ArrayList(u64)) void {
    const Context = struct {
        snip: [][]const u8,
        res: []u64,
        pub fn lessThan(ctx: @This(), lhs: usize, rhs: usize) bool {
            return std.ascii.orderIgnoreCase(ctx.snip[lhs], ctx.snip[rhs]).compare(.lt);
        }

        pub fn swap(ctx: @This(), lhs: usize, rhs: usize) void {
            std.mem.swap([]const u8, &ctx.snip[lhs], &ctx.snip[rhs]);
            std.mem.swap(u64, &ctx.res[lhs], &ctx.res[rhs]);
        }
    };

    const ctx: Context = .{ .snip = snip.items, .res = res.items };
    std.sort.pdqContext(0, res.items.len, ctx);
}

fn minifyGeneratedFiles(gpa: std.mem.Allocator) void {
    const command = std.fmt.allocPrint(gpa, "minhtml {s}/* --minify-css --minify-js --keep-closing-tags", .{TMP_OUT_DIR_NAME}) catch |err| {
        std.debug.print("Minifying failed: couldn't generate the command, {}\n", .{err});
        return;
    };
    defer gpa.free(command);

    var minify_proc = std.process.Child.init(
        &.{ "sh", "-c", command },
        gpa,
    );
    minify_proc.stdout_behavior = .Ignore;
    const minify_res = minify_proc.spawnAndWait() catch |err| {
        std.debug.print("Minizing attempt failed: {}\n", .{err});
        return;
    };
    if (minify_res.Exited == 0) {
        std.debug.print("Minimization done!\n", .{});
    } else {
        std.debug.print("Something went wrong with minimization!\n", .{});
    }
}
