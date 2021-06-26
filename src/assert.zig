
const std = @import("std");
const fmt = std.fmt;

pub fn compileError(comptime format: []const u8, args: anytype) noreturn {
    const msg = comptime fmt.comptimePrint(format, args);
    @compileError(msg);
}

pub fn errorUnsupportedDimensionCount(comptime dimensions: usize) noreturn {
    compileError("unsupported dimensions count {d} (only 2, 3, or 4 dimensions supported)", .{dimensions});
}