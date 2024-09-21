const std = @import("std");

const FLVError = error{
    Read,
    InvalidSignature,
    InvalidPacket,
    EOF,
};

pub fn GenericFLV(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        reader: ReaderType,
        header: Header,

        const Header = struct {
            var buffer: [9]u8 = undefined;

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

            fn parse(reader: ReaderType) FLVError!Header {
                const read = reader.read(&buffer) catch {
                    return FLVError.Read;
                };

                if (read != 9) {
                    return FLVError.Read;
                }

                const header = Header{
                    .signature = buffer[0..3].*,
                    .version = buffer[3],
                    .flags = buffer[4],
                    .size = std.mem.readInt(u32, buffer[5..9], .big),
                };

                if (!std.mem.eql(u8, &header.signature, "FLV")) {
                    return FLVError.InvalidSignature;
                }

                return header;
            }
        };

        const Packet = struct {
            var buffer: [15]u8 = undefined;

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

            fn parse(reader: ReaderType) FLVError!Packet {
                const read = reader.read(&buffer) catch {
                    return FLVError.Read;
                };
                if (read == 0) return FLVError.EOF;

                const timestamp_lower = std.mem.readInt(u24, buffer[8..11], .big);
                const timestamp_upper = buffer[11];
                const timestamp = @as(u32, timestamp_upper) << 24 | timestamp_lower;

                const packet = Packet{
                    .prev_size = std.mem.readInt(u32, buffer[0..4], .big),
                    .type = @enumFromInt(buffer[4]),
                    .payload_size = std.mem.readInt(u24, buffer[5..8], .big),
                    .timestamp = timestamp,
                    .stream_id = std.mem.readInt(u24, buffer[12..15], .big),
                };

                reader.skipBytes(packet.payload_size, .{}) catch |err| {
                    if (err == error.EndOfStream) {
                        return FLVError.EOF;
                    }

                    return FLVError.Read;
                };
                return packet;
            }
        };

        pub fn init(reader: ReaderType) FLVError!Self {
            const header = try Header.parse(reader);
            return .{ .reader = reader, .header = header };
        }

        pub fn next(self: *Self) FLVError!Packet {
            return try Packet.parse(self.reader);
        }
    };
}
