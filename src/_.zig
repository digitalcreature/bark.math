pub const meta = @import("meta/_.zig");

pub usingnamespace @import("cardinal.zig");

pub const scalar = @import("scalar.zig");
pub const vector = @import("vector.zig");
// pub const matrix = @import("matrix.zig");

pub const Vector = vector.Vector;
// pub const Matrix = matrix.Matrix;

pub const types = struct {
    pub usingnamespace vector.types;
    // pub usingnamespace matrix.types;
};

pub const glsl = struct {
    pub usingnamespace scalar.glsl;
    pub usingnamespace vector.glsl;
    // pub usingnamespace matrix.glsl;
};

pub const hlsl = struct {
    pub usingnamespace scalar.hlsl;
    pub usingnamespace vector.hlsl;
    // pub usingnamespace matrix.hlsl;
};
