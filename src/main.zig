const std = @import("std");
const GenericFLV = @import("flv.zig").FLV;

var packet_count: usize = 0;

pub fn main() !void {
    const file = std.fs.cwd().openFile("file.flv", .{}) catch std.process.exit(1);
    defer file.close();

    const FileFLV = GenericFLV(std.fs.File.Reader);
    var file_flv = FileFLV.init(file.reader());

    packet_count = 0;
    while (file_flv.next()) |packet| {
        packet_count += 1;
        std.debug.print("{}\n", .{packet});
    }

    std.debug.print("File FLV: Packets: {d}\n", .{packet_count});
}

test "TcpFLV" {
    // TCP
    const address = try std.net.Address.parseIp4("127.0.0.1", 8080);
    var stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();

    const TcpFLV = GenericFLV(std.net.Stream.Reader);
    var tcp_flv = TcpFLV.init(stream.reader());

    packet_count = 0;
    while (tcp_flv.next()) |packet| {
        packet_count += 1;
        std.debug.print("Packet {d:^6}: {}\n", .{ packet_count, packet });
    }

    std.debug.print("TCP FLV: Packets: {d}\n", .{packet_count});
}
