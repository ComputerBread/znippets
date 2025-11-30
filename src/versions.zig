const std = @import("std");

pub fn areMasterVersionsTheSame(local_v: *const std.ArrayList([]const u8), remote_v: *const std.ArrayList([]const u8)) bool {
    return std.mem.eql(u8, local_v.items[local_v.items.len - 1], remote_v.items[remote_v.items.len - 1]);
}

/// Fetch list of existing zig version from https://ziglang.org/download/index.json,
/// parse the json file and returns an arraylist.
/// WARN: Assumption: versions are sorted from newest to oldest in the json file;
///
/// arena is used to store the arraylist and the strings!
pub fn fetchZigVersions(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io) !std.ArrayList([]const u8) {
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

const yup = [_][]const u8{ "0.16.0-dev.1484+d0ba6642b", "0.15.2", "0.15.1", "0.14.1", "0.14.0", "0.13.0", "0.12.1", "0.12.0", "0.11.0", "0.10.1", "0.10.0", "0.9.1", "0.9.0", "0.8.1", "0.8.0", "0.7.1", "0.7.0", "0.6.0", "0.5.0", "0.4.0", "0.3.0", "0.2.0", "0.1.1" };

pub fn fetchZigVersionsStub(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io) !std.ArrayList([]const u8) {
    _ = gpa;
    _ = io;
    return allVersionStub(arena);
}

pub fn allVersionStub(gpa: std.mem.Allocator) !std.ArrayList([]const u8) {
    var versions: std.ArrayList([]const u8) = .empty;
    for (yup) |ver| {
        const version = try gpa.dupe(u8, ver);
        try versions.append(gpa, version);
    }
    return versions;
}

/// WARN: Below is deadcode, that I keep to help me if I decide to make a CLI
/// tool. (not tested, don't use it)
///
/// At first I didn't think about dealing with the case in which the VERSIONS
/// file would contain only one line. Then I thought about it as a possible way
/// to initialize the "project" such that, that line would correspond to the
/// first (oldest) version we want to start testing the snippets.
/// Then I was like, but what if:
/// - the first version is a master!
/// - first version is an old master and cannot be found
/// then, well what if this is just some garbage?
///
/// then I was like, nah, fuch this shit, let's not worry about the weird edge
/// cases! If I want to initialize the VERSIONS, I can just type all the versions
/// I want in the VERSIONS file! And if I really want something decent: just
/// build a CLI tool to do that properly!!!
///
/// here what I wrote in the readme:
///    - if only one line, it is assumed that this line correspond to a version
///        - 🤔 I should probably delete this and panic instead
///        - this version will searched in the complete list of zig versions (fetched remotely)
///        - if found, this version and any newer version will be used to test the snippets
///            - this is the only case that make sense
///              would be a nice way to initialize it
///        - if not found, assume that it's an old master (or some garbage) and will be discarded,
///          newest master and newest "stable" release is added to avoid a never
///          ending cycle of replacing masters!
///        - ⚠️ this is mostly a weird edge case, avoid it!
///          MAKE SURE THE SNIPPETS FILE IS EMPTY, cause you're going to get garbage
///          (damn this is kinda annoying to make robust)
///          (I just want to publish ts really quick)
///        - ⚠️ just don't modify this file, and you should be good to go
pub fn deadCodeOnlyOneLineInVersionsFile(arena: std.mem.Allocator, all_versions: std.ArrayList([]const u8), zig_versions: std.ArrayList([]const u8), new_version_idx: *usize) void {
    std.debug.print("DEBUG zig_version 1 element\n", .{});

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
        new_version_idx.* -= 1;
        // let's add the last "stable" release and the master
        // if we only add the master, we will be stuck in a never ending
        // cycle of replacing the master branch!
        try zig_versions.append(arena, all_versions.items[all_versions.items.len - 2]);
        try zig_versions.append(arena, all_versions.items[all_versions.items.len - 1]);
    } else {
        if (starting_idx != all_versions.items.len) {
            new_version_idx.* -= 1;
        }
        // here starting_idx can be == to all_versions.items.len and it's fine!
        // it just means that the only element of zig_versions is the latest master!
        try zig_versions.appendSlice(arena, all_versions.items[starting_idx..]);
    }
}

test {
    var versions = try allVersionStub(std.testing.allocator);
    defer versions.deinit(std.testing.allocator);

    for (versions.items) |ver| {
        std.debug.print("ver: {s}\n", .{ver});
        std.testing.allocator.free(ver);
    }
}

test {
    std.debug.print("NOW THE REAL TEST ------------------------\n", .{});
    const gpa = std.testing.allocator;
    // all versions are sorted newest first
    var all_versions = try allVersionStub(std.testing.allocator); // could catch error and continue
    defer all_versions.deinit(gpa);
    // make your life easier for now:
    std.mem.reverse([]const u8, all_versions.items);

    std.debug.print("should be sorted now\n", .{});
    for (all_versions.items) |ver| {
        std.debug.print("ver: {s}\n", .{ver});
    }

    var zig_versions: std.ArrayList([]const u8) = .empty;
    defer zig_versions.deinit(gpa);
    try zig_versions.append(gpa, try std.mem.Allocator.dupe(gpa, u8, "0.13.0"));
    try zig_versions.append(gpa, try std.mem.Allocator.dupe(gpa, u8, "master"));

    // TODO: if (zig_versions is empty) then just copy everything cuh
    if (zig_versions.items.len == 0) {
        // so VERSIONS file was empty
        // need to fill it with all_versions
        // maybe can use something like insertSlice
        // otherwise we assume a previous normal run that filled VERSIONS
        // so last element should be the master branch!
    } else if (!std.mem.eql(u8, zig_versions.items[zig_versions.items.len - 1], all_versions.items[all_versions.items.len - 1])) {
        // ^^^ create a function like areMasterVersionsMatching
        // if master are different there is at least one new version to test
        // what if there's a new release but not a new master, would that be possible?
        gpa.free(zig_versions.pop().?); // pop old master
        var i: usize = 1;
        // search for the last corresponding
        while (!std.mem.eql(u8, zig_versions.items[zig_versions.items.len - 1], all_versions.items[all_versions.items.len - 1 - i])) {
            std.debug.print("checking (zv) {s} == {s} (av)\n", .{ zig_versions.items[zig_versions.items.len - 1], all_versions.items[all_versions.items.len - 1 - i] });
            i += 1;
        }
        i -= 1;
        std.debug.print("shoud work no? i: {d}\n", .{i});
        const starting_idx = all_versions.items.len - i;
        // after this all_version is empty, capacity is cleared, deinit is unnecessary!
        try zig_versions.appendSlice(gpa, all_versions.items[starting_idx..]);
        for (0..starting_idx) |idx| {
            gpa.free(all_versions.items[idx]);
        }
    }

    for (zig_versions.items) |ver| {
        std.debug.print("ver: {s}\n", .{ver});
        gpa.free(ver);
    }
}
