const std = @import("std");
const mem = std.mem;

pub const Module = struct {
    /// Human-readable name (e.g. "OS", "CPU", "Memory")
    name: []const u8,

    /// Fetch function pointer
    fetchFn: *const fn (allocator: mem.Allocator) anyerror![]const u8,

    /// Run fetch and print formatted output
    pub fn run(self: Module, allocator: mem.Allocator, writer: anytype) !void {
        const value = try self.fetchFn(allocator);
        try writer.print("{s}: {s}\n", .{ self.name, value });
    }
};