const win32 = @import("zigwin32");
const std = @import("std");
const win = std.os.windows;
const mem = win32.system.memory;

pub const hook_state = struct {
    original_ptr: *anyopaque,
    original_instr: *anyopaque,
    len: usize,
};

pub const global_hooks_states = struct {
    var list: std.ArrayList(hook_state) = undefined;
    var allocator: std.mem.Allocator = undefined;
};

pub fn init(alloc: std.mem.Allocator) void {
    global_hooks_states.list = std.ArrayList(hook_state).init(alloc);
    global_hooks_states.allocator = alloc;
}

// i would not recommend putting this inside of a defer block
pub fn deinit() void {
    for (global_hooks_states.list.items) |hook_data| {
        var old_protection: mem.PAGE_PROTECTION_FLAGS = .{};
        _ = mem.VirtualProtect(hook_data.original_ptr, hook_data.len, .{ .PAGE_EXECUTE_READWRITE = 1 }, &old_protection);
        @memcpy(@as([*]u8, @ptrCast(hook_data.original_ptr))[0..hook_data.len], @as([*]u8, @ptrCast(hook_data.original_instr))[0..hook_data.len]);
        _ = mem.VirtualProtect(hook_data.original_ptr, hook_data.len, old_protection, &old_protection);

        _ = mem.VirtualFree(hook_data.original_instr, hook_data.len, .DECOMMIT);
    }
}

pub fn get_relative_address(source: *const anyopaque, destination: *const anyopaque) isize {
    return @as(isize, @intCast(@as(usize, @intFromPtr(source)))) - @as(isize, @intCast(@as(usize, @intFromPtr(destination)))) - 5;
}

// https://stackoverflow.com/a/60905849
pub fn detour(source: *anyopaque, destination: *const anyopaque, len: comptime_int) void {
    if (len < 5) return;

    const relative_addr = get_relative_address(destination, source); // : isize = @as(isize, @intCast(@as(usize, @intFromPtr(destination)))) - @as(isize, @intCast(@as(usize, @intFromPtr(source)))) - 5;
    const source_u8: [*]u8 = @ptrCast(source);

    var old_protection: mem.PAGE_PROTECTION_FLAGS = .{};
    _ = mem.VirtualProtect(source, len, .{ .PAGE_EXECUTE_READWRITE = 1 }, &old_protection);

    source_u8[0] = 0xE9;
    std.mem.writeInt(isize, source_u8[1..5], relative_addr, .little);

    _ = mem.VirtualProtect(source, len, old_protection, &old_protection);
}

pub fn trampoline_hook(source: *anyopaque, destination: *const anyopaque, len: comptime_int) *anyopaque {
    if (len < 5) return null;

    const gateway: [*]u8 = @as([*]u8, @ptrCast(mem.VirtualAlloc(null, len + 5, mem.VIRTUAL_ALLOCATION_TYPE{ .COMMIT = 1, .RESERVE = 1 }, mem.PAGE_EXECUTE_READWRITE) orelse @panic("error: could not allocate memory for trampoline")));
    global_hooks_states.list.append(.{ .original_ptr = source, .original_instr = gateway, .len = len }) catch @panic("error: either you forgot to initialize global_hooks_states, or some other error with the allocator occured");

    @memcpy(gateway[0..len], @as([*]const u8, @ptrCast(source))[0..len]);

    const gateway_relative_addr = get_relative_address(source, gateway); //isize = @as(isize, @intCast(@as(usize, @intFromPtr(source))) - @as(isize, @intCast(@as(usize, @intFromPtr(gateway)))) - 5;

    // @as(*u8, @ptrFromInt( + len)).* = 0xE9;
    gateway[len] = 0xE9;
    std.mem.writeInt(isize, gateway[len + 1 .. len + 5], gateway_relative_addr, .little);

    detour(source, destination, len);
    return gateway;
}
