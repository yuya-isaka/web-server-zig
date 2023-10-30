const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
pub const io_mode = .evented;

// std.debug.print("{s}", .{"Hello, world!"});
// const stdout_file = std.io.getStdout().writer();
// var bw = std.io.bufferdWriter(stdout_file);
// const stdout = bw.writer();
// try stdout.print("Hello, world!\n", .{});
// try bw.flush()

pub fn main() anyerror!void {
    var stream_server = StreamServer.init(.{});
    defer stream_server.close();
    const addr = try Address.resolveIp("127.0.0.1", 8080);
    try stream_server.listen(addr);

    while (true) {
        const connection = try stream_server.accept();
        try handler(connection.stream);
    }
}

fn handler(stream: net.Stream) !void {
    defer stream.close();
    try stream.writer().print("Hello Zig World!\n", .{});
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
