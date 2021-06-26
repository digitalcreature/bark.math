pub const meta = @import("meta.zig");

pub const scalar = @import("scalar.zig");
pub const vector = @import("vector.zig");
pub const matrix = @import("vector.zig");

pub const glsl = struct {
    pub usingnamespace scalar.glsl;
    pub usingnamespace vector.glsl;
    pub usingnamespace matrix.glsl;
};

pub const hlsl = struct {
    pub usingnamespace scalar.hlsl;
    pub usingnamespace vector.hlsl;
    pub usingnamespace matrix.hlsl;
};

pub usingnamespace @import("cardinal.zig");