const win32 = @import("zigwin32");
const std = @import("std");
const hooking = @import("trampoline.zig");
const x = win32.ui.windows_and_messaging;

var o_messagebox: *const fn () c_int = undefined;
pub fn msgbox_hook() c_int {
    _ = x.MessageBoxA(null, "haha get hooked", "hooked", x.MB_OK);
    std.log.debug("omsgb from hook: {x}", .{o_messagebox});
    return o_messagebox();
}

pub fn messagebox() c_int {
    _ = x.MessageBoxA(null, "test", "test 2", x.MB_OK);
    return 1;
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();
    hooking.init(allocator);

    o_messagebox = @ptrCast(hooking.trampoline_hook(@constCast(&messagebox), &msgbox_hook, 6));
    std.log.debug("omsgb: {x}", .{o_messagebox});
    // test hook, should run hook then original
    std.log.debug("res: {d}", .{messagebox()});
    // test unhook, should run original alone
    hooking.deinit();
    std.log.debug("res: {d}", .{messagebox()});

    // setup hooks again
    hooking.init(allocator);
    // hook msgbox
    o_messagebox = @ptrCast(hooking.trampoline_hook(@constCast(&messagebox), &msgbox_hook, 6));
    // test hook, should run hook then original
    std.log.debug("res: {d}", .{messagebox()});
    hooking.deinit();
}
