const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const fs = std.fs;
const Allocator = mem.Allocator;
const Module = @import("../core/module.zig").Module;

const StaticStringMap = std.StaticStringMap;
const Thread = std.Thread;

pub const module = Module{
    .name = "Memory",
    .fetchFn = getMemoryInfo,
};

pub fn getMemoryInfo(allocator: Allocator) ![]u8 {
    var buf: [8 * 1024]u8 = undefined;

    var f = try fs.openFileAbsolute("/proc/meminfo", .{ .mode = .read_only });
    var f_reader = f.reader(&.{});
    const n = try f_reader.interface.readSliceShort(&buf);
    f.close();

    const mem_info = try parse(buf[0..n]);

    return fmt.allocPrint(allocator, "{Bi:.2} / {Bi:.2}", .{ mem_info.mem_used, mem_info.mem_total });
}

const MemoryInfo = struct {
    mem_total: u64 = 0,
    mem_used: u64 = 0,
    mem_free: u64 = 0,
    mem_shared: u64 = 0,
    mem_buff_cache: u64 = 0,
    mem_available: u64 = 0,

    swap_total: u64 = 0,
    swap_used: u64 = 0,
    swap_free: u64 = 0,
    swap_cached: u64 = 0,

    active: u64 = 0,
    inactive: u64 = 0,
    anon_pages: u64 = 0,
    mapped: u64 = 0,
    dirty: u64 = 0,
    writeback: u64 = 0,
    kernel_stack: u64 = 0,
    page_tables: u64 = 0,
    slab: u64 = 0,
};

const Key = enum {
    MemTotal,
    MemFree,
    MemAvailable,
    Buffers,
    Cached,
    Shmem,
    SwapTotal,
    SwapFree,
    SwapCached,
    Active,
    Inactive,
    AnonPages,
    Mapped,
    Dirty,
    Writeback,
    KernelStack,
    PageTables,
    Slab,
};

const key_map = StaticStringMap(Key).initComptime(.{
    .{ "MemTotal", .MemTotal },
    .{ "MemFree", .MemFree },
    .{ "MemAvailable", .MemAvailable },
    .{ "Buffers", .Buffers },
    .{ "Cached", .Cached },
    .{ "Shmem", .Shmem },
    .{ "SwapTotal", .SwapTotal },
    .{ "SwapFree", .SwapFree },
    .{ "SwapCached", .SwapCached },
    .{ "Active", .Active },
    .{ "Inactive", .Inactive },
    .{ "AnonPages", .AnonPages },
    .{ "Mapped", .Mapped },
    .{ "Dirty", .Dirty },
    .{ "Writeback", .Writeback },
    .{ "KernelStack", .KernelStack },
    .{ "PageTables", .PageTables },
    .{ "Slab", .Slab },
});

fn parseValueU64(s: []const u8) !u64 {
    var it = mem.tokenizeAny(u8, s, " \t");
    if (it.next()) |num| return fmt.parseUnsigned(u64, num, 10);
    return error.Invalid;
}

fn parse(buf: []const u8) !MemoryInfo {
    var info = MemoryInfo{};
    var buffers: u64 = 0;
    var cached: u64 = 0;
    var swap_cached: u64 = 0;

    var it = mem.splitScalar(u8, buf, '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;
        const colon = mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = line[0..colon];
        const rest = line[colon + 1 ..];

        if (key_map.get(key)) |which| {
            var v = parseValueU64(rest) catch continue;
            v *= 1024;

            switch (which) {
                .MemTotal => info.mem_total = v,
                .MemFree => info.mem_free = v,
                .MemAvailable => info.mem_available = v,
                .Buffers => buffers = v,
                .Cached => cached = v,
                .Shmem => info.mem_shared = v,
                .SwapTotal => info.swap_total = v,
                .SwapFree => info.swap_free = v,
                .SwapCached => swap_cached = v,
                .Active => info.active = v,
                .Inactive => info.inactive = v,
                .AnonPages => info.anon_pages = v,
                .Mapped => info.mapped = v,
                .Dirty => info.dirty = v,
                .Writeback => info.writeback = v,
                .KernelStack => info.kernel_stack = v,
                .PageTables => info.page_tables = v,
                .Slab => info.slab = v,
            }
        }
    }

    info.mem_buff_cache = buffers + cached + swap_cached;
    info.swap_cached = swap_cached;

    if (info.mem_available == 0 and info.mem_total != 0) {
        const freeish = info.mem_free + info.mem_buff_cache;
        info.mem_available = if (freeish > info.mem_total) 0 else info.mem_total - (info.mem_total - freeish);
    }

    if (info.mem_total >= info.mem_available) {
        info.mem_used = info.mem_total - info.mem_available;
    } else info.mem_used = 0;

    if (info.swap_total >= info.swap_free) {
        info.swap_used = info.swap_total - info.swap_free;
    } else info.swap_used = 0;

    return info;
}
