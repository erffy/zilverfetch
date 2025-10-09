const std = @import("std");
const heap = std.heap;
const fs = std.fs;

// Import modules
const osmod = @import("modules/os.zig");
const memmod = @import("modules/memory.zig");

pub fn main() !void {
    var arena: heap.ArenaAllocator = .init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const modules = [_]@import("core/module.zig").Module{
        osmod.module,
        memmod.module,
            // add more here, e.g. cpumod.module, memmod.module
    };

    for (modules) |m| {
        try m.run(allocator, stdout);
    }

    try stdout.flush();
}
