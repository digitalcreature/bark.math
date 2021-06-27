usingnamespace @import("_imports.zig");

// universal

const scalarInfo = meta.scalarInfo;

pub fn negate(rhs: anytype) @TypeOf(rhs) {
    comptime scalarInfo(@TypeOf(rhs)).assert().assertSignedness(.signed);
    return - rhs;
}

pub fn add(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return lhs + rhs;
}

pub fn sub(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return lhs - rhs;
}

pub fn mul(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return lhs * rhs;
}

pub fn div(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return lhs / rhs;
}

pub fn rem(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return @rem(lhs, rhs);
}

pub fn mod(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return @mod(lhs, rhs);
}

// wrapping (integer only)

pub fn negateWrap(rhs: anytype) @TypeOf(rhs) {
    comptime meta.assertIsIntegerScalar(@TypeOf(lhs));
    return -% rhs;
}

pub fn addWrap(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsIntegerScalar(@TypeOf(lhs));
    return lhs +% rhs;
}


pub fn subWrap(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsIntegerScalar(@TypeOf(lhs));
    return lhs -% rhs;
}

pub fn mulWrap(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    comptime meta.assertIsIntegerScalar(@TypeOf(lhs));
    return lhs *% rhs;
}

// comparison

pub fn equals(lhs: anytype, rhs: @TypeOf(lhs)) bool {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return lhs == rhs;
}

pub fn lessThan(lhs: anytype, rhs: @TypeOf(lhs)) bool {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return lhs < rhs;
}

pub fn greaterThan(lhs: anytype, rhs: @TypeOf(lhs)) bool {
    comptime meta.assertIsScalar(@TypeOf(lhs));
    return lhs > rhs;
}

// casts

pub fn as(comptime Target: type, value: anytype) Target {
    comptime meta.assertIsScalar(@TypeOf(value));
    comptime meta.assertIsScalar(Target);
    return @as(Target, value);
}

pub fn bitCast(comptime Target: type, value: anytype) Target {
    comptime meta.assertIsScalar(@TypeOf(value));
    comptime meta.assertIsScalar(Target);
    return @bitCast(Target, value);
}

pub fn floatCast(comptime Target: type, value: anytype) Target {
    comptime meta.assertIsFloatScalar(@TypeOf(value));
    comptime meta.assertIsFloatScalar(Target);
    return @floatCast(Target, value);
}

pub fn floatToInt(comptime Target: type, value: anytype) Target {
    comptime meta.assertIsFloatScalar(@TypeOf(value));
    comptime meta.assertIsIntegerScalar(Target);
    return @floatToInt(Target, value);
}

pub fn intCast(comptime Target: type, value: anytype) Target {
    comptime meta.assertIsIntegerScalar(@TypeOf(value));
    comptime meta.assertIsIntegerScalar(Target);
    return @intCast(Target, value);
}

pub fn intToFloat(comptime Target: type, value: anytype) Target {
    comptime meta.assertIsIntegerScalar(@TypeOf(value));
    comptime meta.assertIsFloatScalar(Target);
    return @intToFloat(Target, value);
}

pub fn truncate(comptime Target: type, value: anytype) Target {
    comptime meta.assertIsIntegerScalar(@TypeOf(value));
    comptime meta.assertIsIntegerScalar(Target);
    return @truncate(Target, value);
}

pub fn hash(self: anytype) u64 {
    const Self = @TypeOf(self);
    const info = comptime scalarInfo(Self).assert();
    const SelfUint = Scalar(.unsigned_integer, info.bits());
    if (info.bits() > 64) {
        return @truncate(u64, @bitCast(SelfUint, self));
    }
    else {
        return @as(u64, @bitCast(SelfUint, self));
    }
}

pub fn Scalar(comptime kind: meta.ScalarKind, comptime bits: usize) type {
    const info: std.builtin.TypeInfo = switch(kind) {
        .unsigned_integer => .{
            .Int = .{
                .signedness = .unsigned,
                .bits = bits,
            },
        },
        .signed_integer => .{
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