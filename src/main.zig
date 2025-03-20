const std = @import("std");
const red = "\x1B[31m";
const yellow = "\x1B[33m";
const reset = "\x1B[0m";

var log_writer: std.fs.File.Writer = undefined;

const ostream = std.io.getStdOut().writer();
const errstream = std.io.getStdErr().writer();

pub const std_options: std.Options = .{ .logFn = log, .log_level = .info };

var source: ?[]u8 = null;
var dest: ?[]u8 = null;

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;

    switch (message_level) {
        std.log.Level.warn => {
            const stream_prefix = yellow ++ "[" ++ comptime message_level.asText() ++ "]" ++ ": ";
            nosuspend errstream.print(stream_prefix ++ format ++ reset, args) catch return;
        },
        std.log.Level.err => {
            const stream_prefix = red ++ "[" ++ comptime message_level.asText() ++ "]" ++ ": ";
            nosuspend errstream.print(stream_prefix ++ format ++ reset, args) catch return;
        },
        std.log.Level.info => {
            const stream_prefix = "[" ++ comptime message_level.asText() ++ "]" ++ ": ";
            nosuspend ostream.print(stream_prefix ++ format, args) catch return;
        },
        else => {
            const stream_prefix = yellow ++ "[" ++ comptime message_level.asText() ++ "]" ++ ": ";
            nosuspend errstream.print(stream_prefix ++ format ++ reset, args) catch return;
        },
    }
    const prefix = "[" ++ comptime message_level.asText() ++ "]" ++ ": ";

    nosuspend log_writer.print(prefix ++ format, args) catch return;
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)

    var args = std.process.args();

    const cwd = std.fs.cwd();
    const log_file = try cwd.createFile("./log_file", .{});
    log_writer = log_file.writer();

    const help = "file_watcher [options]\n -d         Destination: Absolute path of destination location.\n -s         Source: Absolute path of source location. \n";

    while (args.next()) |argument| {
        if (std.mem.eql(u8, argument, "-d") or std.mem.eql(u8, argument, "--destination")) {
            dest = @constCast(args.next().?);
        } else if (std.mem.eql(u8, argument, "-s") or std.mem.eql(u8, argument, "--source")) {
            source = @constCast(args.next().?);
        }
    }

    if (source != null) {
        std.log.info("Source Path: {s}\n", .{source.?});
    } else {
        std.log.info("{s}", .{help});
        std.log.err("No Source path argument found!\n", .{});
        std.process.exit(1);
    }
    if (dest != null) {
        std.log.info("Destination Path: {s}\n", .{dest.?});
    } else {
        std.log.info("{s}", .{help});
        std.log.err("No Destination path argument found!\n", .{});
        std.process.exit(1);
    }

    var source_dir = std.fs.openDirAbsolute(source.?, .{ .iterate = true }) catch |err| switch (err) {
        std.posix.OpenError.BadPathName => {
            std.log.err("Invalid characters in source path!\n", .{});
            std.process.exit(1);
        },
        std.posix.OpenError.FileNotFound => {
            std.log.err("Source Path cannot be found!\n", .{});
            std.process.exit(1);
        },
        else => {
            std.log.err("Unexpected error occured when opening Source Path!\n", .{});
            std.process.exit(1);
        },
    };

    defer source_dir.close();

    var dest_dir = std.fs.openDirAbsolute(dest.?, .{ .iterate = true }) catch |err| switch (err) {
        std.posix.OpenError.BadPathName => {
            std.log.err("Invalid characters in source path!\n", .{});
            std.process.exit(1);
        },
        std.posix.OpenError.FileNotFound => {
            std.log.err("Source Path cannot be found!\n", .{});
            std.process.exit(1);
        },
        else => {
            std.log.err("Unexpected error occured when opening Source Path!\n", .{});
            std.process.exit(1);
        },
    };

    defer dest_dir.close();

    //    var src_meta: std.fs.File.Metadata = undefined;
    //   var dest_meta: std.fs.File.Metadata = undefined;

    //while (true) {
    // src_meta = try source_dir.metadata();
    //    dest_meta = try dest_dir.metadata();

    //   if (src_meta.modified() < dest_meta.modified()) {}
    // }
    try copyFiles(&source_dir, &dest_dir);
}

pub fn copyFiles(source_dir: *std.fs.Dir, dest_dir: *std.fs.Dir) !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    var iteator = source_dir.iterate();

    while (try iteator.next()) |file| {
        const file_name = file.name;

        var sub_dir = try source_dir.openDir(file_name, .{ .iterate = true });
        defer sub_dir.close();

        const stat = try std.posix.fstat(sub_dir.fd);

        if (file.kind == .directory) {
            //    const mirror_dir: std.fs.Dir = blk: {
            //open the first level of files in destination and see if it exists
            //if not create it

            var mirror = blk: {
                if (dest_dir.makeOpenPath(file_name, .{ .iterate = true })) |path| {
                    std.log.warn("Path doesn't exist in mirror! Creating Folder: {s}\n", .{file_name});
                    try path.chown(stat.uid, stat.gid);
                    break :blk path;
                } else |err| switch (err) {
                    std.posix.MakeDirError.PathAlreadyExists => {
                        break :blk try dest_dir.openDir(file_name, .{ .iterate = true });
                    },
                    else => {
                        return err;
                    },
                }
            };

            defer mirror.close();

            try recurse(sub_dir, mirror, allocator);
        }
    }
}

pub fn recurse(dir: std.fs.Dir, mirror: std.fs.Dir, allocator: std.mem.Allocator) !void {
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    const starting_index = source.?.len;

    while (try walker.next()) |sub_file| {
        const realpath = try dir.realpathAlloc(allocator, sub_file.path);
        const mirror_path = try std.fs.path.join(allocator, &[_][]const u8{ dest.?, realpath[starting_index..] });
        try ostream.print("{s}\n", .{sub_file.path});
        if (sub_file.kind == .directory) {
            const stat = try std.posix.fstat(mirror.fd);
            if (mirror.makeOpenPath(mirror_path, .{ .iterate = true })) |path| {
                std.log.warn("Path doesn't exist in mirror! Creating path: {s}\n", .{mirror_path});
                try path.chown(stat.uid, stat.gid);
            } else |err| switch (err) {
                std.posix.MakeDirError.PathAlreadyExists => {},
                else => {
                    return err;
                },
            }
        } else {
            std.log.info("  Copying File into Mirror: {s}\n", .{realpath});
            try std.fs.copyFileAbsolute(realpath, mirror_path, .{});
            try std.fs.deleteFileAbsolute(realpath);
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
