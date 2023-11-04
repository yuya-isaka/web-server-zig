const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const print = std.debug.print;

pub fn main() anyerror!void {
    // アロケータ生成
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // ストリームサーバ生成
    var stream_server = StreamServer.init(.{});
    defer stream_server.close();

    // アドレス生成
    const addr = try Address.resolveIp("127.0.0.1", 8080);
    // リッスン
    try stream_server.listen(addr);

    // 接続待ち
    while (true) {
        const connection = try stream_server.accept();
        try handler(allocator, connection.stream);
    }
}

const ParsingError = error{
    MethodNotValid,
    VersionNotValid,
};

const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    pub fn fromString(s: []const u8) !@This() {
        if (std.mem.eql(u8, s, "GET")) {
            return .GET;
        } else if (std.mem.eql(u8, s, "POST")) {
            return .POST;
        } else if (std.mem.eql(u8, s, "PUT")) {
            return .PUT;
        } else if (std.mem.eql(u8, s, "DELETE")) {
            return .DELETE;
        } else {
            return ParsingError.MethodNotValid;
        }
    }
    pub fn toString(self: @This()) []const u8 {
        switch (self) {
            .GET => return "GET",
            .POST => return "POST",
            .PUT => return "PUT",
            .DELETE => return "DELETE",
        }
    }
};

const Version = enum {
    @"1.1",
    @"2",
    pub fn fromString(version: []const u8) !@This() {
        if (std.mem.eql(u8, version, "HTTP/1.1")) {
            return .@"1.1";
        } else if (std.mem.eql(u8, version, "HTTP/2")) {
            return .@"2";
        } else {
            return ParsingError.VersionNotValid;
        }
    }
    pub fn toString(self: @This()) []const u8 {
        switch (self) {
            .@"1.1" => return "HTTP/1.1",
            .@"2" => return "HTTP/2",
        }
    }
};

const HTTPContext = struct {
    method: Method,
    uri: []const u8,
    version: Version,
    headers: std.StringHashMap([]const u8),
    stream: net.Stream,

    pub fn body(self: *@This()) net.Stream.Reader {
        return self.stream.reader();
    }

    pub fn response(self: *@This()) net.Stream.Writer {
        return self.stream.writer();
    }

    pub fn debugPrintRequest(self: *@This()) void {
        print("======================================\n", .{});

        print("method: {s}\nuri: {s}\nversion: {s}\n", .{ self.method.toString(), self.uri, self.version.toString() });

        var headers_iter = self.headers.iterator();
        while (headers_iter.next()) |entry| {
            print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        print("\n", .{});
    }

    pub fn init(allocator: std.mem.Allocator, stream: net.Stream) !@This() {
        // allocatorによって確保されたメモリを使い、streamから読み込む
        var first_line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        first_line = first_line[0 .. first_line.len - 1];
        print("\nfirst_line: {s}\n", .{first_line});

        var first_line_iter = std.mem.split(u8, first_line, " ");

        const method = first_line_iter.next() orelse return error.UnexpectedEof;
        const uri = first_line_iter.next() orelse return error.UnexpectedEof;
        const version = first_line_iter.next() orelse return error.UnexpectedEof;

        // アロケータから確保されたメモリを使い、文字列ハッシュマップを生成する
        var headers = std.StringHashMap([]const u8).init(allocator);

        while (true) {

            // allocatorによって確保されたメモリを使い、streamから読み込む
            var line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
            print("line: {s}\n", .{line});
            // 空行が来たら終了
            if (line.len == 1 and std.mem.eql(u8, line, "\r")) break;

            // :で分割
            var line_iter = std.mem.split(u8, line, ": ");

            const key = line_iter.next() orelse return error.UnexpectedEof;
            const value = line_iter.next() orelse return error.UnexpectedEof;
            // if (value[0] == ' ') value = value[1..];

            try headers.put(key, value);
        }

        return @This(){
            .method = try Method.fromString(method),
            .uri = uri,
            .version = try Version.fromString(version),
            .headers = headers,
            .stream = stream,
        };
    }
};

fn handler(allocator: std.mem.Allocator, stream: net.Stream) anyerror!void {
    defer stream.close();

    var http_request = try HTTPContext.init(allocator, stream);
    http_request.debugPrintRequest();
}
