const std = @import("std");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)

    var args = std.process.args();

    const ostream = std.io.getStdOut().writer();
    const errstream = std.io.getStdErr().writer();
    const help = "info: file_watcher [options]\n -d         Destination: Absolute path of destination location.\n -s         Source: Absolute path of source location. \n";
    const red = "\x1B[31m";
    const reset = "\x1B[0m";

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
        try std.fmt.format(ostream, "Path: {s}\n", .{dest.?});
    } else {
        try std.fmt.format(errstream, "{s} No Destination path argument found!{s}\n", .{ red, reset });
        std.process.exit(1);
    }

    //    try std.fs.copyFileAbsolute(source_path: []const u8, dest_path: []const u8, .{});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
