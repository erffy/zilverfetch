const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const Allocator = mem.Allocator;

const Module = @import("../core/module.zig").Module;

pub const module = Module{
    .name = "OS",
    .fetchFn = getPrettyName,
};

pub fn getPrettyName(allocator: Allocator) ![]u8 {
    const dir = fs.cwd();
    const file = try dir.openFile("/etc/os-release", .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;
    const content = try file.readToEndAlloc(allocator, file_size + 1);

    var content_view = content;
    if (content_view.len > 0 and content_view[content_view.len - 1] == 0) content_view = content_view[0 .. content_view.len - 1];

    var it = mem.splitScalar(u8, content_view, '\n');
    while (it.next()) |line| {
        const prefix = "PRETTY_NAME=";
        if (mem.startsWith(u8, line, prefix)) {
            var value = line[prefix.len..];
            if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') value = value[1 .. value.len - 1];
            return allocator.dupeZ(u8, value);
        }
    }

    return allocator.dupeZ(u8, "Unknown");
}
