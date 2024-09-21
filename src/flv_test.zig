const std = @import("std");
const GenericFLV = @import("flv").GenericFLV;

test "FLV Header" {
    const header = [9]u8{
        'F', 'L', 'V', // Signature
        0x01, // Version
        0x05, // Flags (audio + video)
        0x00, 0x00, 0x00, 0x09, // Header size (always 9 for FLV version 1)
    };

    var fixed_buffer_stream = std.io.fixedBufferStream(&header);
    const reader = fixed_buffer_stream.reader();

    const FLV = GenericFLV(@TypeOf(reader));
    const flv = try FLV.init(reader);

    try std.testing.expectEqualSlices(u8, &flv.header.signature, "FLV");
    try std.testing.expectEqual(flv.header.version, 1);
    try std.testing.expectEqual(flv.header.flags, 0x05);
    try std.testing.expectEqual(flv.header.size, 9);
}

test "FLV Packet" {
    const data = [_]u8{
        // FLV Header (9 bytes)
        'F',  'L',  'V',  0x01, 0x05, 0x00, 0x00, 0x00, 0x09,

        // Previous tag size (always 0 for the first tag)
        0x00, 0x00, 0x00, 0x00,

        // Tag type (9 = video)
        0x09,

        // Data size (3 bytes) - let's say 10 bytes
        0x00, 0x00, 0x0A,

        // Timestamp (3 bytes + 1 byte extended) - let's say 5 seconds
        0x00,
        0x00, 0x05, 0x00,

        // Stream ID (3 bytes) - always 0
        0x00, 0x00, 0x00,

        // Dummy payload data (10 bytes as specified in Data size)
        0x00, 0x01, 0x02,
        0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,

        // Previous tag size for the next tag (4 bytes)
        0x00, 0x00,
        0x00, 0x17, // 23 bytes (10 + 11 + 2)
    };

    var fixed_buffer_stream = std.io.fixedBufferStream(&data);
    const reader = fixed_buffer_stream.reader();

    const FLV = GenericFLV(@TypeOf(reader));
    var flv = try FLV.init(reader);

    const packet = try flv.next();

    try std.testing.expectEqual(packet.prev_size, 0);
    try std.testing.expectEqual(packet.type, .Video);
    try std.testing.expectEqual(packet.payload_size, 10);
    try std.testing.expectEqual(packet.timestamp, 5);
    try std.testing.expectEqual(packet.stream_id, 0);
}

