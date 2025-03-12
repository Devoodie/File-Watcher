const std = @import("std");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var args = std.process.args();
    var ostream = std.io.getStdOut().writer();
    var errstream = std.io.getStdErr().writer();

    var path: ?[]u8 = undefined;
    while (args.next()) |argument| {
        if (std.mem.eql(u8, argument, "-p")) {
            path = @constCast(args.next().?);
        }
    }
    if (path != null) {
        std.debug.debug("{s}", .{path.?});
    } else {
        errstream.write("No Path variable found ");
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
