const std = @import("std");
const red = "\x1B[31m";
const reset = "\x1B[0m";

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)

    var args = std.process.args();

    const ostream = std.io.getStdOut().writer();
    const errstream = std.io.getStdErr().writer();
    const help = "info: file_watcher [options]\n -d         Destination: Absolute path of destination location.\n -s         Source: Absolute path of source location. \n";

    var source: ?[]u8 = null;
    var dest: ?[]u8 = null;

    while (args.next()) |argument| {
        if (std.mem.eql(u8, argument, "-d") or std.mem.eql(u8, argument, "--destination")) {
            dest = @constCast(args.next().?);
        } else if (std.mem.eql(u8, argument, "-s") or std.mem.eql(u8, argument, "--source")) {
            source = @constCast(args.next().?);
        }
    }

    if (source != null) {
        try std.fmt.format(ostream, "Source Path: {s}\n", .{source.?});
    } else {
        try std.fmt.format(errstream, "{s} No Source path argument found!{s}\n {s}", .{ red, reset, help });
        std.process.exit(1);
    }
    if (dest != null) {
        try std.fmt.format(ostream, "Destination Path: {s}\n", .{dest.?});
    } else {
        try std.fmt.format(errstream, "{s} No Destination path argument found!{s}\n", .{ red, reset });
        std.process.exit(1);
    }

    var source_dir = try std.fs.openDirAbsolute(source.?, .{ .iterate = true });
    defer source_dir.close();

    var dest_dir = try std.fs.openDirAbsolute(dest.?, .{ .iterate = true });
    defer dest_dir.close();

    //    var src_meta: std.fs.File.Metadata = undefined;
    //   var dest_meta: std.fs.File.Metadata = undefined;

    //while (true) {
    // src_meta = try source_dir.metadata();
    //    dest_meta = try dest_dir.metadata();

    //   if (src_meta.modified() < dest_meta.modified()) {}
    // }
    try copyFiles(&source_dir, &dest_dir, ostream, errstream);
}

pub fn copyFiles(source: *std.fs.Dir, dest: *std.fs.Dir, ostream: std.fs.File.Writer, errstream: std.fs.File.Writer) !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    _ = ostream;

    var iteators = source.iterate();

    while (try iteators.next()) |file| {
        const file_name = file.name;

        if (file.kind == .directory) {
            const dest_dir: std.fs.Dir = blk: {
                //open the first level of files in destination and see if it exists
                //if not create it
                if (dest.openDir(file_name, .{ .iterate = true })) |dir| {
                    break :blk dir;
                } else |err| switch (err) {
                    std.fs.Dir.OpenError.FileNotFound => {
                        try std.fmt.format(errstream, "{s}No file Found in Destination Directory: {s}\nCreating New File {s}{s}\n", .{ red, file_name, file_name, reset });
                        std.log.err("{s}No file Found in Destination Directory: {s}\nCreating New File {s}{s}\n", .{ red, file_name, file_name, reset });
                        break :blk try dest.makeOpenPath(file_name, .{});
                    },
                    else => {
                        return err;
                    },
                }
            };
            const sub_dir = try source.openDir(file_name, .{ .iterate = true });

            var walker = try sub_dir.walk(allocator);
            while (try walker.next()) |sub_file| {
                if (sub_file.kind == .directory) {
                    _ = void;
                } else {
                    try sub_dir.copyFile(sub_file.basename, dest_dir, "./", .{});
                }
            }
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
