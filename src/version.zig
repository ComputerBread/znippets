const std = @import("std");

const yup = [_][]const u8{ "0.16.0-dev.1458+755a3d957", "0.15.2", "0.15.1", "0.14.1", "0.14.0", "0.13.0", "0.12.1", "0.12.0", "0.11.0", "0.10.1", "0.10.0", "0.9.1", "0.9.0", "0.8.1", "0.8.0", "0.7.1", "0.7.0", "0.6.0", "0.5.0", "0.4.0", "0.3.0", "0.2.0", "0.1.1" };

pub fn fetchZigVersions(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io) !std.ArrayList([]const u8) {
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
