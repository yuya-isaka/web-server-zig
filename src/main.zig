const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const print = std.debug.print;
pub const io_mode = .evented;

// std.debug.print("{s}", .{"Hello, world!"});
// const stdout_file = std.io.getStdout().writer();
// var bw = std.io.bufferdWriter(stdout_file);
// const stdout = bw.writer();
// try stdout.print("Hello, world!\n", .{});
// try bw.flush()

pub fn main() anyerror!void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var stream_server = StreamServer.init(.{});
    defer stream_server.close();
    const addr = try Address.resolveIp("127.0.0.1", 8080);
    try stream_server.listen(addr);

    while (true) {
        const connection = try stream_server.accept();
        try handler(allocator, connection.stream);
    }
}

fn handler(allocator: std.mem.Allocator, stream: net.Stream) !void {
    defer stream.close();
    var first_line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
    first_line = first_line[0..first_line.len];
    var first_line_iter = std.mem.split(u8, first_line, " ");

    const method = first_line_iter.next().?;
    const uri = first_line_iter.next().?;
    const version = first_line_iter.next().?;

    var headers = std.StringHashMap([]const u8).init(allocator);

    while (true) {
        // print("hello", .{});
        var line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        if (line.len == 1 and std.mem.eql(u8, line, "\r")) break;

        line = line[0..line.len];
        var line_iter = std.mem.split(u8, line, ":");
        const key = line_iter.next().?;
        var value = line_iter.next().?;
        if (value[0] == ' ') value = value[1..];
        try headers.put(key, value);
    }

    // try stream.writer().print("Hello Zig World!\n", .{});
    print("method:{s}\nuri: {s}\nversion:{s}\n", .{ method, uri, version });

    var headers_iter = headers.iterator();
    while (headers_iter.next()) |entry| {
        print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
    print("\n", .{});
    // try stream.writer().print("method:{s}\nuri: {s}\nversion:{s}\nheaders:{}\n", .{ method, uri, version, headers });
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
