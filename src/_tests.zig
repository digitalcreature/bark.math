const std = @import("std");
const math = @import("_.zig");

usingnamespace math.vector.types;

test {
    const v = i32_3.init(1, 2, 3);
    const vf = v.intToFloat(f32);
    try std.testing.expectEqual(@as(f32, 1), vf.x);
    try std.testing.expectEqual(@as(f32, 2), vf.y);
    try std.testing.expectEqual(@as(f32, 3), vf.z);
}