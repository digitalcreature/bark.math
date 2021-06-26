usingnamespace @import("../_imports.zig");

usingnamespace @import("common.zig");
usingnamespace @import("operators.zig");
usingnamespace @import("casts.zig");

fn mixin(comptime Self: type) type {
    return struct {
        pub usingnamespace common(Self);
        pub usingnamespace operators(Self);
        pub usingnamespace casts(Self);
    };
}

pub fn Vector(comptime Scalar: type, comptime dimensions: usize) type {
    return switch (dimensions) {
        2 => extern struct {
            x: Scalar,
            y: Scalar,
            pub usingnamespace mixin(@This());
        },
        3 => extern struct {
            x: Scalar,
            y: Scalar,
            z: Scalar,
            pub usingnamespace mixin(@This());
        },
        4 => extern struct {
            x: Scalar,
            y: Scalar,
            z: Scalar,
            w: Scalar,
            pub usingnamespace mixin(@This());
        },
        else => comptime errorDimensionCountUnsupported(dimensions),
    };
}

pub const i8_2 = Vector(i8, 2);
pub const i8_3 = Vector(i8, 3);
pub const i8_4 = Vector(i8, 4);

pub const i16_2 = Vector(i16, 2);
pub const i16_3 = Vector(i16, 3);
pub const i16_4 = Vector(i16, 4);

pub const i32_2 = Vector(i32, 2);
pub const i32_3 = Vector(i32, 3);
pub const i32_4 = Vector(i32, 4);

pub const i64_2 = Vector(i64, 2);
pub const i64_3 = Vector(i64, 3);
pub const i64_4 = Vector(i64, 4);

pub const isize_2 = Vector(isize, 2);
pub const isize_3 = Vector(isize, 3);
pub const isize_4 = Vector(isize, 4);

pub const u8_2 = Vector(u8, 2);
pub const u8_3 = Vector(u8, 3);
pub const u8_4 = Vector(u8, 4);

pub const u16_2 = Vector(u16, 2);
pub const u16_3 = Vector(u16, 3);
pub const u16_4 = Vector(u16, 4);

pub const u32_2 = Vector(u32, 2);
pub const u32_3 = Vector(u32, 3);
pub const u32_4 = Vector(u32, 4);

pub const u64_2 = Vector(u64, 2);
pub const u64_3 = Vector(u64, 3);
pub const u64_4 = Vector(u64, 4);

pub const usize_2 = Vector(usize, 2);
pub const usize_3 = Vector(usize, 3);
pub const usize_4 = Vector(usize, 4);

pub const f16_2 = Vector(f16, 2);
pub const f16_3 = Vector(f16, 3);
pub const f16_4 = Vector(f16, 4);

pub const f32_2 = Vector(f32, 2);
pub const f32_3 = Vector(f32, 3);
pub const f32_4 = Vector(f32, 4);

pub const f64_2 = Vector(f64, 2);
pub const f64_3 = Vector(f64, 3);
pub const f64_4 = Vector(f64, 4);

pub const glsl = struct {

    pub const vec2 = Vector(f32, 2);
    pub const vec3 = Vector(f32, 3);
    pub const vec4 = Vector(f32, 4);

    pub const dvec2 = Vector(f64, 2);
    pub const dvec3 = Vector(f64, 3);
    pub const dvec4 = Vector(f64, 4);

    pub const ivec2 = Vector(i32, 2);
    pub const ivec3 = Vector(i32, 3);
    pub const ivec4 = Vector(i32, 4);
    
    pub const uvec2 = Vector(u32, 2);
    pub const uvec3 = Vector(u32, 3);
    pub const uvec4 = Vector(u32, 4);

};

pub const hlsl = struct {

    pub const int2 = Vector(i32, 2);
    pub const int3 = Vector(i32, 3);
    pub const int4 = Vector(i32, 4);
    
    pub const uint2 = Vector(u32, 2);
    pub const uint3 = Vector(u32, 3);
    pub const uint4 = Vector(u32, 4);

    pub const half2 = Vector(f16, 2);
    pub const half3 = Vector(f16, 3);
    pub const half4 = Vector(f16, 4);

    pub const float2 = Vector(f32, 2);
    pub const float3 = Vector(f32, 3);
    pub const float4 = Vector(f32, 4);

    pub const double2 = Vector(f64, 2);
    pub const double3 = Vector(f64, 3);
    pub const double4 = Vector(f64, 4);

};