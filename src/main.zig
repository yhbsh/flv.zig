const std = @import("std");

const FLV = struct {
    file: std.fs.File,
    reader: std.io.BufferedReader(4096, std.fs.File.Reader),
    buffer: [15]u8,

    const Header = struct {
        signature: [3]u8,
        version: u8,
        flags: u8,
        size: u32,

        pub fn format(self: Header, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try writer.print(
                "Signature: {s:3} | Version: {d:1} | Flags: 0x{X:0>2} | Header Size: {d} |",
                .{ self.signature, self.version, self.flags, self.size },
            );
        }
    };

    const Packet = struct {
        const Type = enum(u8) { Audio = 8, Video = 9, ScriptData = 18 };

        prev_size: u32,
        type: Type,
        payload_size: u24,
        timestamp: u32,
        stream_id: u24,

        pub fn format(self: Packet, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try writer.print(
                "Prev Size: {d:^8} | Type: {s:^10} | Payload Size: {d:^8} | Timestamp: {d:^12} | Stream ID: {d:^4} |",
                .{ self.prev_size, @tagName(self.type), self.payload_size, self.timestamp, self.stream_id },
            );
        }
    };

    pub fn init(filename: []const u8) FLV {
        const file = std.fs.cwd().openFile(filename, .{}) catch std.process.exit(1);
        var flv = FLV{
            .file = file,
            .reader = std.io.bufferedReader(file.reader()),
            .buffer = undefined,
        };

        // Read and validate header
        var header_buffer: [9]u8 = undefined;
        _ = flv.reader.read(&header_buffer) catch std.process.exit(1);
        const header = Header{
            .signature = header_buffer[0..3].*,
            .version = header_buffer[3],
            .flags = header_buffer[4],
            .size = std.mem.readInt(u32, header_buffer[5..9], .big),
        };

        if (!std.mem.eql(u8, &header.signature, "FLV")) std.process.exit(1);

        std.debug.print("FLV Header: {}\n\n", .{header});

        return flv;
    }

    pub fn deinit(self: *FLV) void {
        self.file.close();
    }

    pub fn next(self: *FLV) ?Packet {
        const read = self.reader.read(&self.buffer) catch std.process.exit(1);
        if (read == 0) return null;

        const packet = Packet{
            .prev_size = std.mem.readInt(u32, self.buffer[0..4], .big),
            .type = @enumFromInt(self.buffer[4]),
            .payload_size = std.mem.readInt(u24, self.buffer[5..8], .big),
            .timestamp = std.mem.readInt(u32, self.buffer[8..12], .big),
            .stream_id = std.mem.readInt(u24, self.buffer[12..15], .big),
        };

        self.reader.reader().skipBytes(packet.payload_size, .{}) catch {
            std.process.exit(1);
        };

        return packet;
    }
};

pub fn main() void {
    var flv = FLV.init("file.flv");
    defer flv.deinit();

    var packet_count: usize = 0;
    while (flv.next()) |packet| {
        packet_count += 1;
        std.debug.print("Packet {d:^6}: {}\n", .{ packet_count, packet });
    }

    std.debug.print("\nTotal packets parsed: {d}\n", .{packet_count});
}
