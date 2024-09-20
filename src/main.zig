const std = @import("std");
const GenericFLV = @import("flv.zig").FLV;

pub fn main() void {
    var args = std.process.args();

    const program = args.next();
    const file_path = args.next();
    if (file_path == null) {
        std.debug.print("[USAGE]: {s} <file>\n", .{program.?});
        std.process.exit(1);
    }

    const file = std.fs.cwd().openFile(file_path.?, .{}) catch std.process.exit(1);
    defer file.close();

    const FLV = GenericFLV(std.fs.File.Reader);
    var flv = FLV.init(file.reader());

    var packet_count: usize = 0;
    while (flv.next()) |packet| {
        packet_count += 1;
        std.debug.print("Packet {d:^6}: {}\n", .{ packet_count, packet });
    }

    std.debug.print("\nTotal packets parsed: {d}\n", .{packet_count});
}
