pub usingnamespace @import("scalar.zig");

usingnamespace @import("../assert.zig");

const vector = @import("../vector.zig");

pub fn isScalar(comptime scalar_type: type) bool {
    return comptime scalarInfo(scalar_type).isValid();
}

pub fn assertIsScalar(comptime scalar_type: type) void {
    _ = comptime scalarInfo(scalar_type).assert();
}

pub fn assertIsIntegerScalar(comptime Scalar: type) void {
    comptime scalarInfo(Scalar).assert().assertFormat(.integer);
}

pub fn assertIsFloatScalar(comptime Scalar: type) void {
    comptime scalarInfo(Scalar).assert().assertFormat(.float);
}

pub fn isVector(comptime Vector: type) bool {
    comptime {
        if (@typeInfo(Vector) == .Struct) {
            if (@hasDecl(Vector, "Scalar") and @TypeOf(Vector.Scalar) == type) {
                if (@hasDecl(Vector, "dimensions") and @TypeOf(Vector.dimensions) == usize) {
                    const Scalar = Vector.Scalar;
                    const dimensions = Vector.dimensions;
                    if (isScalar(Scalar) and isDimensionCountSupported(dimensions)) {
                        return Vector == vector.Vector(Scalar, dimensions);
                    }
                }
            }
        }
        return false;
    }
}

pub fn assertIsVector(comptime vector_type: type) void {
    if (!isVector(vector_type)) {
        errorUnexpectedType(vector_type, "vector", .{});
    }
}