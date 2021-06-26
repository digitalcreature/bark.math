usingnamespace @import("_imports.zig");

// universa;

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