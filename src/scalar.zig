usingnamespace @import("_imports.zig");

// universal

pub fn negate(rhs: anytype) @TypeOf(rhs) {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(rhs));
    return - rhs;
}

pub fn add(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return lhs + rhs;
}

pub fn sub(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return lhs - rhs;
}

pub fn mul(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return lhs * rhs;
}

pub fn div(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return lhs / rhs;
}

pub fn rem(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return @rem(lhs, rhs);
}

pub fn mod(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return @mod(lhs, rhs);
}

// wrapping (integer only)

pub fn negateWrap(rhs: anytype) @TypeOf(rhs) {
    ScalarInfo.fromTypeAssert(@TypeOf(rhs)).assertInteger();
    return -% rhs;
}

pub fn addWrap(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    ScalarInfo.fromTypeAssert(@TypeOf(lhs)).assertInteger();
    return lhs +% rhs;
}


pub fn subWrap(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    ScalarInfo.fromTypeAssert(@TypeOf(lhs)).assertInteger();
    return lhs -% rhs;
}

pub fn mulWrap(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    ScalarInfo.fromTypeAssert(@TypeOf(lhs)).assertInteger();
    return lhs *% rhs;
}

// comparison

pub fn equals(lhs: anytype, rhs: @TypeOf(lhs)) bool {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return lhs == rhs;
}

pub fn lessThan(lhs: anytype, rhs: @TypeOf(lhs)) bool {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return lhs < rhs;
}

pub fn greaterThan(lhs: anytype, rhs: @TypeOf(lhs)) bool {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(lhs));
    return lhs > rhs;
}

// casts

pub fn as(comptime Target: type, value: anytype) Target {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(value));
    _ = ScalarInfo.fromTypeAssert(Target);
    return @as(Target, value);
}

pub fn bitCast(comptime Target: type, value: anytype) Target {
    _ = ScalarInfo.fromTypeAssert(@TypeOf(value));
    _ = ScalarInfo.fromTypeAssert(Target);
    return @bitCast(Target, value);
}

pub fn floatCast(comptime Target: type, value: anytype) Target {
    ScalarInfo.fromTypeAssert(@TypeOf(value)).assertFloat();
    ScalarInfo.fromTypeAssert(Target).assertFloat();
    return @floatCast(Target, value);
}

pub fn floatToInt(comptime Target: type, value: anytype) Target {
    ScalarInfo.fromTypeAssert(@TypeOf(value)).assertFloat();
    ScalarInfo.fromTypeAssert(Target).assertInteger();
    return @floatToInt(Target, value);
}

pub fn intCast(comptime Target: type, value: anytype) Target {
    ScalarInfo.fromTypeAssert(@TypeOf(value)).assertInteger();
    ScalarInfo.fromTypeAssert(Target).assertInteger();
    return @intCast(Target, value);
}

pub fn intToFloat(comptime Target: type, value: anytype) Target {
    ScalarInfo.fromTypeAssert(@TypeOf(value)).assertInteger();
    ScalarInfo.fromTypeAssert(Target).assertFloat();
    return @intToFloat(Target, value);
}

pub fn truncate(comptime Target: type, value: anytype) Target {
    ScalarInfo.fromTypeAssert(@TypeOf(value)).assertInteger();
    ScalarInfo.fromTypeAssert(Target).assertInteger();
    return @truncate(Target, value);
}


pub fn Scalar(comptime kind, ScalarInfo.Kind, comptime bits: usize) type {
    const info: std.builtin.TypeInfo = switch(kind) {
        .unsigned_int => .{
            .Int = .{
                .signedness = .unsigned,
                .bits = bits,
            },
        },
        .signed_int => .{
            .Int = .{
                .signedness = .signed,
                .bits = bits,
            },
        },
        .float => .{
            .Float = .{
                .bits = bits,
            },
        },
    };
    return @Type(info);

}

pub const glsl = struct {

    pub const int = i32;
    pub const uint = u32;

    pub const float = f32;
    pub const double = f64;

};

pub const hlsl = struct {

    pub const int = i32;
    pub const uint = u32;
    pub const dword = u32;

    pub const half = f16;
    pub const float = f32;
    pub const double = f64;

};