const std = @import("std");

const TemplatingError = std.Io.Reader.StreamError || std.Io.Reader.DelimiterError || std.Io.Writer.Error || std.Io.File.SeekError;

/// Function used to read a HTML template, with some template string like
/// `{{TITLE}}`. Takes the reader of a template, and writes all the content of
/// the template until it finds a `{{template_string}}`. Once it finds a `{{`,
/// it extracts the string and returns it, so that caller can replace it with
/// whatever...
/// Returns `error.EndOfStream` once it's done
/// Should this function actually flush the writer?
pub fn streamUntilTemplateStr(reader: *std.Io.Reader, writer: *std.Io.Writer) TemplatingError![]const u8 {
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

pub fn minifyGeneratedFiles(gpa: std.mem.Allocator, dir_path: []const u8) void {
    const command = std.fmt.allocPrint(gpa, "minhtml {s}/* --minify-css --minify-js --keep-closing-tags", .{dir_path}) catch |err| {
        std.log.err("Minifying failed: couldn't generate the command, {}", .{err});
        return;
    };
    defer gpa.free(command);

    var minify_proc = std.process.Child.init(
        &.{ "sh", "-c", command },
        gpa,
    );
    minify_proc.stdout_behavior = .Ignore;
    const minify_res = minify_proc.spawnAndWait() catch |err| {
        std.log.err("Minizing attempt failed: {}", .{err});
        return;
    };
    if (minify_res.Exited == 0) {
        std.log.debug("Minimization done!", .{});
    } else {
        std.log.err("Something went wrong with minimization!", .{});
    }
}

pub fn writeDateTime(io: std.Io, writer: *std.Io.Writer) void {
    const clock = std.Io.Clock.real;
    const timestamp = std.Io.Clock.now(clock, io) catch {
        std.log.debug("Couldn't acquire the current timestamp", .{});
        return;
    };

    const secs: u64 = @intCast(timestamp.toSeconds());
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = secs };
    const day_seconds = epoch_seconds.getDaySeconds();
    const epoch_day = epoch_seconds.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const year = year_day.year;
    const month = month_day.month.numeric();
    const day = month_day.day_index + 1;
    const hour = day_seconds.getHoursIntoDay();
    const minutes = day_seconds.getMinutesIntoHour();
    const seconds = day_seconds.getSecondsIntoMinute();

    writer.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z\n", .{ year, month, day, hour, minutes, seconds }) catch {
        std.log.err("couldn't write DateTime inside writer\n", .{});
    };
}
