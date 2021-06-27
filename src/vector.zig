usingnamespace @import("_imports.zig");

const cardinal = @import("cardinal.zig");
const scalar = @import("scalar.zig");

pub fn Vector(comptime scalar_type: type, comptime dimension_count: usize) type {

    const scalar_info = comptime meta.scalarInfo(scalar_type).assert();
    comptime assertDimensionCountSupported(dimension_count);

    return extern struct {

        v: Values,

        pub const Scalar = scalar_type;
        pub const dimensions = dimension_count;

        pub const Axis = cardinal.Axis(dimensions);
        pub const Values = [dimensions]Scalar;

        const indices = ([_]usize{ 0, 1, 2, 3, })[0..dimensions];

        const Self = @This();

        pub const zero = fill(0);
        pub const one = fill(1);

        pub usingnamespace init_mixin;
        const init_mixin = switch (dimensions) {
            2 => struct {
                pub fn init(x: Scalar, y: Scalar) Self
                    { return Self { .v = .{ x, y, } }; }
            },
            3 => struct {
                pub fn init(x: Scalar, y: Scalar, z: Scalar) Self
                    { return Self { .v = .{ x, y, z, } }; }
            },
            4 => struct {
                pub fn init(x: Scalar, y: Scalar, z: Scalar, w: Scalar) Self
                    { return Self { .v = .{ x, y, z, w, } }; }
            },
            else => unreachable,
        };

        pub fn from(src: anytype) Self {
            const Src = @TypeOf(src);
            return switch (Src) {
                Scalar => fill(src),
                Values => Self { .v = src },
                Self => src,
                else => errorUnexpectedType(Src, "{s}, {s}, or {s}",
                    .{ @typeName(Scalar), @typeName(Values), @typeName(Self) }
                ),
            };
        }

        fn fill(value: Scalar) Self {
            var self: Self = undefined;
            std.mem.set(Scalar, &self.v, value);
            return self;
        }

        pub fn unit(comptime axis: Axis) Self {
            comptime var result = zero;
            result.set(axis, 1);
            return result;
        }

        pub fn get(self: Self, comptime axis: Axis) Scalar
            { return self.v[axis.toIndex()]; }
        pub fn ptr(self: *Self, comptime axis: Axis) *Scalar
            { return &self.v[axis.toIndex()]; }
        pub fn set(self: *Self, comptime axis: Axis, value: Scalar) void
            { self.v[axis.toIndex()] = value; }


        const swizzle_letters = ("xyzw")[0..dimensions];

        fn Swizzle(comptime pattern: []const u8) type {
            comptime {
                if (pattern.len != 1 and !isDimensionCountSupported(pattern.len)) {
                    compileError("invalid length swizzle pattern '{s}', must be 1, 2, 3, or 4 components", .{ pattern });
                }
                for (pattern) |letter| {
                    switch (letter) {
                        '0', '1' => {},
                        else => {
                            for (swizzle_letters) |valid_letter| {
                                if (valid_letter == letter) {
                                    break;
                                }
                            }
                            else {
                                compileError("invalid swizzle pattern '{s}' for {s}", .{ pattern, @typeName(Self) });
                            }
                        }
                    }
                }
                if (pattern.len == 1) {
                    return Scalar;
                }
                else {
                    return Vector(Scalar, pattern.len);
                }
            }
        }

        pub fn swizzle(self: Self, comptime pattern: []const u8) Swizzle(pattern) {
            const Result = Swizzle(pattern);
            var result: Result = undefined;
            inline for (pattern) |letter, i| {
                const r = if (Result == Scalar) (
                    &result
                )
                else (
                    &result.v[i]
                );
                switch (letter) {
                    '0' => r.* = 0,
                    '1' => r.* = 1,
                    else => {
                        r.* = for (swizzle_letters) |valid_letter, j| {
                            if (letter == valid_letter) {
                                break self.v[j];
                            }
                        }
                        else unreachable;   // we already checked validity in Swizzle()
                    },
                }
            }
            return result;
        }

        pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.writeAll("(");
            inline for (indices) |i| {
                if (i > 0) {
                    try writer.writeAll(", ");
                }
                try std.fmt.formatType(self.v[i], fmt, options, writer, 0);
            }
            try writer.writeAll(")");
        }

        fn binaryOpFields(lhs: Self, rhs: anytype, comptime op: fn(Scalar, Scalar) Scalar) Self {
            var result: Self = undefined;
            inline for (indices) |i| {
                result.v[i] = op(lhs.v[i], from(rhs).v[i]);
            }
            return result;
        }

        fn unaryOpFields(rhs: Self, comptime op: fn(Scalar) Scalar) Self {
            var result: Self = undefined;
            inline for (indices) |i| {
                result.v[i] = op(rhs.v[i]);
            }
            return result;
        }

        pub fn fold(self: Self, initial: Scalar, comptime op: fn(Scalar, Scalar) Scalar) Scalar {
            var result = initial;
            inline for (indices) |i| {
                result = op(result, self.v[i]);
            }
            return result;
        }

        pub fn add(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.add); }
        pub fn sub(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.sub); }
        pub fn mul(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.mul); }
        pub fn div(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.div); }
        pub fn rem(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.rem); }
        pub fn mod(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.mod); }

        pub fn sum(self: Self) Scalar
            { return self.fold(0, scalar.add); }
        pub fn product(self: Self) Scalar
            { return self.fold(1, scalar.mul); }

        pub fn dot(lhs: Self, rhs: Self) Scalar
            { return lhs.mul(rhs).sum(); }

        pub fn len2(self: Self) Scalar
            { return self.dot(self); }

        fn castFields(self: Self, comptime Target: type, comptime op: ScalarCastFn(Target)) CastVector(Target) {
            const Result = CastVector(Target);
            var result: Result = undefined;
            inline for (indices) |i| {
                result.v[i] = op(Result.Scalar, self.v[i]);
            }
            return result;
        }

        fn ScalarCastFn(comptime Target: type) type {
            return fn (type, anytype) CastVector(Target).Scalar;
        }

        fn CastVector(comptime Target: type) type {
            if (meta.isScalar(Target))  {
                return Vector(Target, dimensions);
            }
            if (meta.isVector(Target)) {
                if (Target.dimensions == dimensions) {
                    return Target;
                }
            }
            comptime errorUnexpectedType(Target, "scalar or {d} dimensional vector", .{dimensions});
        }

        pub fn as(self: Self, comptime Target: type) CastVector(Target)
            { return self.castFields(Target, scalar.as); }
        pub fn bitCast(self: Self, comptime Target: type) CastVector(Target)
            { return self.castFields(Target, scalar.bitCast); }

        pub fn eql(lhs: Self, rhs: anytype) bool {
            const rhs_v = from(rhs);
            return std.mem.eql(Scalar, &lhs.v, &rhs_v);
        }

        // chosen by fair random.org roll. garunteed to be random
        const hash_masks = [4]u64 {
            0x010ea372e7625ad9,
            0x2039d47ef81627f0,
            0x83d2b2e4507bf9e2,
            0xfdd6bb7322df356f,
        };

        pub fn hash(self: Self) u64 {
            var result: u64 = 0x66705ee142213141;
            inline for (indices) |i| {
                result ^= scalar.hash(self.v[i]) ^ hash_masks[i];
            }
            return result;
        }

        pub const HashContext = struct {

            pub fn eql(_: @This(), lhs: Self, rhs: Self) bool {
                return lhs.eql(rhs);
            }

            pub fn hash(_: @This(), value: Self) u64 {
                return value.hash();
            }

        };

        pub usingnamespace integer_mixin;
        const integer_mixin = if (scalar_info.format() != .integer) struct {} else struct {

            pub fn addWrap(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.addWrap); }
            pub fn subWrap(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.subWrap); }
            pub fn mulWrap(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.mulWrap); }
            pub fn divWrap(lhs: Self, rhs: anytype) Self { return lhs.binaryOpFields(rhs, scalar.divWrap); }
            
            pub fn sumWrap(self: Self) Scalar { return self.foldFields(0, scalar.addWrap); }
            pub fn productWrap(self: Self) Scalar { return self.foldFields(1, scalar.mulWrap); }

            pub fn intCast(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.intCast); }
            pub fn intToFloat(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.intToFloat); }
            pub fn truncate(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.truncate); }

        };

        pub usingnamespace signed_mixin;
        const signed_mixin = if (scalar_info.signedness() != .signed) struct {} else struct {
            pub fn negate(self: Self) Self { return self.unaryOpFields(scalar.negate); }
        };

        pub usingnamespace signed_int_mixin;
        const signed_int_mixin = if (scalar_info.kind_info != .signed_integer) struct {} else struct {
            pub fn negateWrap(self: Self) Self { return self.unaryOpFields(scalar.negateWrap); }
        };

        pub usingnamespace float_mixin;
        const float_mixin = if (scalar_info.kind_info != .float) struct {} else struct {

            pub fn len(self: Self) Scalar {
                return @sqrt(self.len2());
            }

            pub fn normalize(self: Self) Self {
                const l = self.len();
                if (len != 0.0) {
                    return self.div(l);
                }
                else {
                    return zero;
                }
            }

            pub fn project(lhs: Self, rhs: Self) Self {
                const ratio = lhs.dot(rhs) / rhs.dot(rhs);
                return rhs.scale(ratio);
            }

            pub fn reject(lhs: Self, rhs: Self) Self {
                return lhs.sub(lhs.project(rhs));
            }

            pub fn floatCast(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.floatCast); }
            pub fn floatToInt(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.floatToInt); }

            pub usingnamespace float3_mixin;
            const float3_mixin = if (dimensions != 3) struct {} else struct {
                

                pub fn cross(lhs: Self, rhs: anytype) Self {
                    const a = &lhs.v;
                    const b = &from(rhs).v;
                    const X = 0;
                    const Y = 1;
                    const Z = 2;
                    return Self {
                        .v = .{
                            a[Y] * b[Z] - a[Z] * b[Y],
                            a[Z] * b[X] - a[X] * b[Z],
                            a[X] * b[Y] - a[Y] * b[X],
                        },
                    };
                }

                const float4 = Vector(Scalar, 4);

                pub fn asAffinePosition(self: Self) float4 {
                    return float4 {
                        .v = .{
                            self.v[0], self.v[1], self.v[2], 1,
                        },
                    };
                }

                pub fn asAffineDirection(self: Self) float4 {
                    return float4 {
                        .v = .{
                            self.v[0], self.v[1], self.v[2], 0,
                        },
                    };
                }

                pub const fromAffinePosition = float4.asAffinePosition;
                pub const fromAffineDirection = float4.asAffineDirection;

            };

            pub usingnamespace float4_mixin;
            const float4_mixin = if (dimensions != 4) struct {} else struct {

                const float3 = Vector(Scalar, 3);

                pub fn asAffinePosition(self: Self) ?float3 {
                    const w = self.v[3];
                    if (w == 0) return null;
                    return float3 {
                        .v = .{
                            self.v[0] / w,
                            self.v[1] / w,
                            self.v[2] / w,
                        },
                    };
                }

                pub fn asAffineDirection(self: Self) float3 {
                    return float3 {
                        .v = .{
                            self.v[0], self.v[1], self.v[2],
                        },
                    };
                }

                pub const fromAffinePosition = float3.asAffinePosition;
                pub const fromAffineDirection = float3.asAffineDirection;

            };

        };


    };

}

pub const types = struct {

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

};

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