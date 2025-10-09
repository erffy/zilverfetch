const std = @import("std");
const heap = std.heap;
const osmod = @import("modules/os.zig");

pub fn main() !void {
    var arena: heap.ArenaAllocator = .init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const name = try osmod.getPrettyName(allocator);
    std.debug.print("OS: {s}\n", .{name});
}
