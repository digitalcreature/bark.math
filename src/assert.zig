
const std = @import("std");
const fmt = std.fmt;

pub fn compileError(comptime format: []const u8, args: anytype) noreturn {
    const msg = comptime fmt.comptimePrint(format, args);
    @compileError(msg);
}

pub fn errorUnexpectedType(comptime Type: type, comptime fmt: []const u8, args: anytype) noreturn {
    compileError("expected " ++ fmt ++ ", found " ++ @typeName(Type), args);
}

pub fn errorDimensionCountUnsupported(comptime dimensions: usize) noreturn {
    compileError("unsupported dimensions count {d} (only 2, 3, or 4 dimensions supported)", .{dimensions});
}

pub fn isDimensionCountSupported(comptime dimensions: usize) bool {
    return switch (dimensions) {
        2, 3, 4 => true,
        else => false,
    };
}

pub fn assertDimensionCountSupported(comptime dimensions: usize) void {
    if (!isDimensionCountSupported(dimensions)) {
        errorDimensionCountUnsupported(dimensions);
    }
}
