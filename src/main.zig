const std = @import("std");
const flv = @import("flv.zig");

pub fn main() void {
    var args = std.process.args();

    const program = args.next();

    const file_path = args.next();
    if (file_path == null) {
        std.debug.print("[USAGE]: {s} <file>\n", .{program.?});
        std.process.exit(1);
    }

    var ctx = flv.init(file_path.?);
    defer ctx.deinit();

    var packet_count: usize = 0;
    while (ctx.next()) |packet| {
        packet_count += 1;
        std.debug.print("Packet {d:^6}: {}\n", .{ packet_count, packet });
    }

    std.debug.print("\nTotal packets parsed: {d}\n", .{packet_count});
}
