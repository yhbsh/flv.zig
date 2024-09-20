const std = @import("std");

const FLV = struct {
    file: std.fs.File,
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

            // Convert timestamp to milliseconds (assuming it's in units of 1/1000 seconds)
            const timestamp_ms = self.timestamp;
            const hours = timestamp_ms / (60 * 60 * 1000);
            const minutes = (timestamp_ms % (60 * 60 * 1000)) / (60 * 1000);
            const seconds = (timestamp_ms % (60 * 1000)) / 1000;
            const milliseconds = timestamp_ms % 1000;

            try writer.print(
                "Prev Size: {d:^8} | Type: {s:^10} | Payload Size: {d:<8} | Timestamp: {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3} | Stream ID: {d:^4} |",
                .{ self.prev_size, @tagName(self.type), self.payload_size, hours, minutes, seconds, milliseconds, self.stream_id },
            );
        }
    };

    pub fn init(filename: []const u8) FLV {
        const file = std.fs.cwd().openFile(filename, .{}) catch std.process.exit(1);
        var flv = FLV{ .file = file, .buffer = undefined };

        var buffer: [9]u8 = undefined;

        const read = flv.file.reader().read(&buffer) catch |err| {
            std.debug.print("[ERROR]: cannot read header: {}\n", .{err});
            std.process.exit(1);
        };

        if (read != 9) {
            std.debug.print("[ERROR]: invalid read size\n", .{});
            std.process.exit(1);
        }

        const header = Header{
            .signature = buffer[0..3].*,
            .version = buffer[3],
            .flags = buffer[4],
            .size = std.mem.readInt(u32, buffer[5..9], .big),
        };

        if (!std.mem.eql(u8, &header.signature, "FLV")) {
            std.debug.print("[ERROR]: invalid flv file\n", .{});
            std.process.exit(1);
        }

        std.debug.print("FLV Header: {}\n\n", .{header});

        return flv;
    }

    pub fn deinit(self: *FLV) void {
        self.file.close();
    }

    pub fn next(self: *FLV) ?Packet {
        const read = self.file.reader().read(&self.buffer) catch |err| {
            std.debug.print("[ERROR]: cannot read packet header: {}\n", .{err});
            std.process.exit(1);
        };
        if (read == 0) return null;

        // Correctly parse the timestamp
        const timestamp_lower = std.mem.readInt(u24, self.buffer[8..11], .big);
        const timestamp_upper = self.buffer[11];
        const timestamp = @as(u32, timestamp_upper) << 24 | timestamp_lower;

        const packet = Packet{
            .prev_size = std.mem.readInt(u32, self.buffer[0..4], .big),
            .type = @enumFromInt(self.buffer[4]),
            .payload_size = std.mem.readInt(u24, self.buffer[5..8], .big),
            .timestamp = timestamp,
            .stream_id = std.mem.readInt(u24, self.buffer[12..15], .big),
        };

        self.file.reader().skipBytes(packet.payload_size, .{}) catch |err| {
            if (err == error.EndOfStream) {
                return null;
            }
            std.debug.print("[ERROR]: cannot skip payload: {}\n", .{err});
            std.process.exit(1);
        };
        return packet;
    }
};

pub fn main() void {
    var args = std.process.args();

    const program = args.next();

    const file_path = args.next();
    if (file_path == null) {
        std.debug.print("[USAGE]: {s} <file>\n", .{program.?});
        std.process.exit(1);
    }

    var flv = FLV.init(file_path.?);
    defer flv.deinit();

    var packet_count: usize = 0;
    while (flv.next()) |packet| {
        packet_count += 1;
        std.debug.print("Packet {d:^6}: {}\n", .{ packet_count, packet });
    }

    std.debug.print("\nTotal packets parsed: {d}\n", .{packet_count});
}
