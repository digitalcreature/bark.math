usingnamespace @import("_imports.zig");

const cardinal = @import("cardinal.zig");
const scalar = @import("scalar.zig");

fn mixin(comptime Self: type) type {

    const self_info = VectorInfo.fromTypeAssert(Self);
    const scalar_info = self_info.scalar_info;

    return struct {

        pub const dimensions = self_info.dimensions;
        pub const scalar_kind = scalar_info.kind;
        pub const Scalar = self_info.scalar_type;
        pub const Axis = cardinal.Axis(dimensions);

        /// all vectors
        const common_mixin = struct {

            pub const zero = fill(0);
            pub const one = fill(1);

            /// init functions
            pub usingnamespace switch (dimensions) {
                2 => struct {
                    pub fn init(x: Scalar, y: Scalar) Self
                        { return fromArray(.{ x, y }); }
                },
                3 => struct {
                    pub fn init(x: Scalar, y: Scalar, z: Scalar) Self
                        { return fromArray(.{ x, y, z }); }
                },
                4 => struct {
                    pub fn init(x: Scalar, y: Scalar, z: Scalar, w: Scalar) Self
                        { return fromArray(.{ x, y, z, w }); }
                },
                else => unreachable,
            };

            pub fn from(src: anytype) Self {
                const Src = @TypeOf(src);
                if (Src == Scalar) {
                    return fill(src);
                }
                if (Src == [dimensions]Scalar) {
                    return fromArray(src);
                }
                if (VectorInfo.fromType(Src)) |info| {
                    if (info.isSimilar(self_info)) {
                        const src_get = mixin(Src).get;
                        var self: Self = undefined;
                        inline for (Axis.values) |axis| {
                            self.set(axis, src_get(src, axis));
                        }
                        return self;
                    }
                }
                comptime errorUnexpectedType(
                    Src, "{0s}, [{1d}]{0s}, {1d} dimensional {0s} vector",
                    .{ @typeName(Scalar), dimensions }
                );
            }

            pub fn fromArray(values: [dimensions]Scalar) Self {
                var self: Self = undefined;
                inline for (Axis.values) |axis, i| {
                    self.set(axis, values[i]);
                }
                return self;
            }

            pub fn toArray(self: Self) [dimensions]Scalar {
                var values: [dimensions]Scalar = undefined;
                inline for (Axis.values) |axis, i| {
                    values[i] = self.get(axis);
                }
                return values;
            }

            pub fn get(self: Self, comptime axis: Axis) Scalar
                { return @field(self, self_info.field_names[comptime axis.toIndex()]); }
            pub fn ptr(self: Self, comptime axis: Axis) *Scalar
                { return &@field(self, self_info.field_names[comptime axis.toIndex()]); }
            pub fn set(self: *Self, comptime axis: Axis, value: Scalar) void
                { @field(self, self_info.field_names[comptime axis.toIndex()]) = value; }

            fn Swizzle(comptime swizzle_string: []const u8) type {
                comptime {
                    if (isDimensionCountSupported(swizzle_string.len)) {
                        return Vector(Scalar, swizzle_string.len);
                    }
                    else {
                        compileError("invalid swizzle string \"{s}\" length must be 2, 3, or 4", .{swizzle_string});
                    }
                }
            }

            pub fn swizzle(self: Self, comptime swizzle_string: []const u8) Swizzle(swizzle_string) {
                var result: [swizzle_string.len]Scalar = undefined;
                inline for (swizzle_string) |specifier, i| {
                    switch (specifier) {
                        '0' => result[i] = 0,
                        '1' => result[i] = 1,
                        else => {
                            const name: []const u8 = &.{specifier};
                            if (@hasField(Axis, name)) {
                                result[i] = self.get(@field(Axis, name));
                            }
                            else {
                                compileError("invalid swizzle specifier '{s}'", .{name});
                            }
                        },
                    }
                }
                return Swizzle(swizzle_string).fromArray(result);
            }

            pub fn fill(value: Scalar) Self {
                var self: Self = undefined;
                inline for (Axis.values) |axis| {
                    self.set(axis, value);
                }
                return self;
            }

            pub fn unit(comptime axis: Axis) Self {
                comptime {
                    var result = zero;
                    result.set(axis, 1);
                    return result;
                }
            }

            pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
                try writer.writeAll("(");
                inline for (Axis.values) |axis, i| {
                    if (i > 0) {
                        try writer.writeAll(", ");
                    }
                    try std.fmt.formatType(self.get(axis), fmt, options, writer, 0);
                }
                try writer.writeAll(")");
            }

            pub fn eql(lhs: Self, rhs: Self) bool {
                inline for (Axis.values) |axis| {
                    if (lhs.get(axis) != rhs.get(axis)) {
                        return false;
                    }
                }
                return true;
            }

            pub fn hash(self: Self) u64 {

                comptime var rng = std.rand.Isaac64.init(0xDEAD1025DEAD0413);

                // unsigned int version of Scalar for bitcasting to
                const ScalarBits = scalar.Scalar(.unsigned_int, scalar_info.bits);

                var result: u64;
                inline for (Axis.values) |axis| {
                    const element_bits = @bitCast(ScalarBits, self.get(axis));
                    const element_hash = (
                        if (scalar_info.bits <= 64) (
                            @as(u64, element_bits)
                        )
                        else (
                            @truncate(u64, element_bits)
                        )
                    );
                    result ^= element_hash ^ comptime rng.random.int(u64);
                }
                return result;
            }

            pub const HashContext = struct {

                pub fn eql(self: Context, lhs: Self, rhs: Self) bool {
                    return lhs.eql(rhs);
                }

                pub fn hash(self: Context, value: Self) u64 {
                    return value.hash();
                }

            };

            pub fn binaryOpFields(lhs: Self, rhs: anytype, comptime op: fn(Scalar, Scalar) Scalar) Self {
                var result: Self = undefined;
                inline for (Axis.values) |axis| {
                    result.set(axis, op(lhs.get(axis), from(rhs).get(axis)));
                }
                return result;
            }

            pub fn unaryOpFields(rhs: Self, comptime op: fn(Scalar) Scalar) Self {
                var result: Self = undefined;
                inline for (Axis.values) |axis| {
                    result.set(axis, op(rhs.get(axis)));
                }
                return result;
            }

            pub fn foldFields(self: Self, initial: Scalar, comptime op: fn(Scalar, Scalar) Scalar) Scalar {
                var result = initial;
                inline for (Axis.values) |axis| {
                    result = op(result, self.get(axis));
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
                { return self.foldFields(0, scalar.add); }
            pub fn product(self: Self) Scalar
                { return self.foldFields(1, scalar.mul); }

            pub fn dot(lhs: Self, rhs: Self) Scalar
                { return lhs.mul(rhs).sum(); }

            pub fn len2(self: Self) Scalar
                { return self.dot(self); }

            pub fn castFields(self: Self, comptime Target: type, comptime op: ScalarCastFn(Target)) CastVector(Target) {
                const Result = CastVector(Target);
                const ResultScalar = CastScalar(Target);
                const result_set = mixin(Result).set;
                var result: CastVector(Target) = undefined;
                inline for (Axis.values) |axis| {
                    result_set(&result, axis, op(ResultScalar, self.get(axis)));
                }
                return result;
            }

            fn ScalarCastFn(comptime Target: type) type {
                return fn (type, anytype) CastScalar(Target);
            }

            pub fn CastVector(comptime Target: type) type {
                if (ScalarInfo.fromType(Target)) |info| {
                    return Vector(Target, dimensions);
                }
                if (VectorInfo.fromType(Target)) |info| {
                    if (info.dimensions == dimensions) {
                        return Target;
                    }
                }
                comptime errorUnexpectedType(Target, "scalar or {d} dimensional vector", .{dimensions});
            }

            fn CastScalar(comptime Target: type) type {
                const Tv = CastVector(Target);
                const info = VectorInfo.fromTypeAssert(Tv);
                return info.scalar_type;
            }

            pub fn as(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.as); }
            pub fn bitCast(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.bitCast); }

        };

        /// signed integer, unsigned integer
        const integer_mixin = struct {

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

        /// signed integer, float
        const signed_mixin = struct {

            pub fn negate(self: Self) Self { return self.unaryOpFields(scalar.negate); }

        };

        /// signed integer
        const signed_int_mixin = struct {
            pub usingnamespace integer_mixin;
            pub usingnamespace signed_mixin;

            pub fn negateWrap(self: Self) Self { return self.unaryOpFields(scalar.negateWrap); }

        };

        /// unsigned integer
        const unsigned_int_mixin = struct {
            pub usingnamespace integer_mixin;
        };

        /// float
        const float_mixin = struct {

            pub usingnamespace signed_mixin;

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

            pub usingnamespace switch (dimensions) {
                2 => struct {},
                3 => struct {

                    pub fn cross(lhs: Self, rhs: anytype) Self {
                        const a = lhs;
                        const b = from(rhs).toArray();
                        var result: Self = undefined;
                        result.set(.x, a.get(.y) * b.get(.z) - a.get(.z) * b.get(.y));
                        result.set(.y, a.get(.z) * b.get(.x) - a.get(.x) * b.get(.z));
                        result.set(.z, a.get(.x) * b.get(.y) - a.get(.y) * b.get(.x));
                        return result;
                    }

                    const Float4 = Vector(Scalar, 4);

                    pub fn asAffinePosition(self: Self) Float4 {
                        return Float4.init(
                            self.get(.x),
                            self.get(.y),
                            self.get(.z),
                            1,
                        );
                    }

                    pub fn asAffineDirection(self: Self) Float4 {
                        return Float4.init(
                            self.get(.x),
                            self.get(.y),
                            self.get(.z),
                            0,
                        );
                    }

                    pub const fromAffinePosition = Float4.asAffinePosition;
                    pub const fromAffineDirection = Float4.asAffineDirection;

                },
                4 => struct {

                    const Float3 = Vector(Scalar, 3);

                    pub fn asAffinePosition(self: Self) ?Float3 {
                        const w = self.get(.w);
                        if (w == 0) return null;
                        return Float3.init(
                            self.get(.x) / w,
                            self.get(.y) / w,
                            self.get(.z) / w,
                        );
                    }

                    pub fn asAffineDirection(self: Self) Float3 {
                        return Float3.init(
                            self.get(.x),
                            self.get(.y),
                            self.get(.z),
                        );
                    }

                    pub const fromAffinePosition = Float3.asAffinePosition;
                    pub const fromAffineDirection = Float3.asAffineDirection;

                },
                else => unreachable,
            };

            pub fn floatCast(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.floatCast); }
            pub fn floatToInt(self: Self, comptime Target: type) CastVector(Target)
                { return self.castFields(Target, scalar.floatToInt); }

        };

        pub usingnamespace common_mixin;
        pub usingnamespace switch (scalar_kind) {
            .signed_int => signed_int_mixin,
            .unsigned_int => unsigned_int_mixin,
            .float => float_mixin,
        };

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
        else => errorDimensionCountUnsupported(dimensions),
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