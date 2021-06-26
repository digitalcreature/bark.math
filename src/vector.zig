usingnamespace @import("_imports.zig");

const cardinal = @import("cardinal.zig");
const scalar_ops = @import("scalar.zig");

fn VectorMixin(comptime Self: type) type  {

    const self_info = VectorInfo.fromTypeAssert(Self);
    const scalar_info = self_info.scalar_info;

    const Scalar = self_info.scalar_type;
    const dimensions = self_info.dimensions;

    const Cardinal = cardinal.Cardinal(dimensions);
    const Axis = cardinal.Axis(dimensions);

    const utils = struct {
        
        pub fn doBinaryOp(lhs: Self, rhs: Self, comptime op: fn(Scalar, Scalar) Scalar) Self {
            var result: Self = undefined;
            inline for (Axis.values) |axis| {
                result.set(axis, op(lhs.get(axis), rhs.get(axis)));
            }
            return result;
        }

        pub fn doUnaryOp(rhs: Self, comptime op: fn(Scalar) Scalar) Self {
            var result: Self = undefined;
            inline for (Axis.values) |axis| {
                result.set(axis, op(rhs.get(axis)));
            }
            return result;
        }

        pub fn doComparisonOp(lhs: Self, rhs: Self, comptime op: fn(Scalar, Scalar) bool) Self {
            var result: Self = undefined;
            inline for (Axis.values) |axis| {
                result.set(axis, op(lhs.get(axis), rhs.get(axis)));
            }
            return result;
        }

        pub fn doFold(self: Self, initial: Scalar, comptime op: fn(Scalar, Scalar) Scalar) Scalar {
            var result = initial;
            inline for (Axis.values) |axis| {
                result = op(result, self.get(axis));
            }
            return result;
        }

        pub fn doCast(self: Self, comptime Target: type, comptime op: ScalarCastFn(Target)) TargetVector(Target) {
            const Result = TargetVector(Target);
            const ResultScalar = TargetScalar(Target);
            const ResultMixin = VectorMixin(Result);
            var result: TargetVector(Target) = undefined;
            inline for (Axis.values) |axis| {
                ResultMixin.set(&result, axis, op(ResultScalar, self.get(axis)));
            }
            return result;
        }

        fn ScalarCastFn(comptime Target: type) type {
            return fn (type, anytype) TargetScalar(Target);
        }

        pub fn TargetVector(comptime Target: type) type {
            switch (TypeInfo.fromTypeAssert(Target)) {
                .Scalar => return Vector(Target, dimensions),
                .Vector => |info| {
                    info.assertDimensions(dimensions);
                    return Target;
                },
                .Matrix => |info| {
                    compileError("cannot derive target vector type from matrix type {s}", .{@typeName(info.matrix_type)});
                },
            }
        }

        pub fn TargetScalar(comptime Target: type) type {
            switch (TypeInfo.fromTypeAssert(Target)) {
                .Scalar => return Target,
                .Vector => |info| {
                    info.assertDimensions(dimensions);
                    return info.scalar_type;
                },
                .Matrix => |info| {
                    compileError("cannot derive target vector type from matrix type {s}", .{@typeName(info.matrix_type)});
                },
            }
        }

    };

    const common = struct {

        pub const zero = fill(0);
        pub const one = fill(1);

        // constructors

        pub fn fill(value: Scalar) Self {
            var self: Self = undefined;
            inline for (Axis.values) |axis| {
                self.set(axis, value);
            }
            return self;
        }

        pub fn unit(comptime axis: Axis) Self {
            var result = zero;
            result.set(axis, 1);
            return result;
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

        pub fn fromStruct(values: anytype) Self {
            const Values = @TypeOf(values);
            VectorInfo.fromTypeAssert(Values).assertSimilar(self_info);
            const ValuesMixin = VectorMixin(Values);
            var self: Self = undefined;
            inline for (Axis.values) |axis| {
                self.set(axis, ValuesMixin.get(values, axis));
            }
            return self;
        }

        /// return value of component for `axis`
        pub fn get(self: Self, comptime axis: Axis) Scalar {
            return @field(self, self_info.field_names[comptime axis.toIndex()]);
        }

        /// return pointer to component for `axis`
        pub fn ptr(self: Self, comptime axis: Axis) *Scalar {
            return &@field(self, self_info.field_names[comptime axis.toIndex()]);
        }

        /// set value of component for `axis` to `value`
        pub fn set(self: *Self, comptime axis: Axis, value: Scalar) void {
            @field(self, self_info.field_names[comptime axis.toIndex()]) = value;
        }

        pub fn Swizzle(comptime fmt: []const u8) type {
            return switch (fmt.len) {
                2, 3, 4 => Vector(Scalar, fmt.len),
                else => errorDimensionCountUnsupported(fmt.len),
            };
        }

        pub fn swizzle(self: Self, comptime fmt: []const u8) Swizzle(fmt) {
            var result: [fmt.len]Scalar = undefined;
            inline for (fmt) |specifier, i| {
                result[i] = switch (specifier) {
                    '0' => 0,
                    '1' => 1,
                    else => getval: {
                        const name: []const u8 = &.{specifier};
                        if (@hasField(Axis, name)) {
                            break :getval self.get(@field(Axis, name));
                        }
                        else {
                            compileError("invalid swizzle specifier '{s}'", .{name});
                        }
                    },
                };
            }
            return Swizzle(fmt).fromArray(result);
        }

        // univerasal ops
        pub fn add(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.add); }
        pub fn sub(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.sub); }
        pub fn mul(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.mul); }
        pub fn div(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.div); }
        pub fn rem(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.rem); }
        pub fn mod(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.mod); }

        pub fn sum(self: Self) Scalar { return utils.doFold(0, scalar_ops.add); }
        pub fn product(self: Self) Scalar { return utils.doFold(1, scalar_ops.mul); }

        pub fn scale(lhs: Self, rhs: Scalar) Self {
            return self.mul(common.fill(rhs));
        }

        pub fn dot(lhs: Self, rhs: Self) Scalar {
            return self.mul(rhs).sum();
        }

        pub fn len2(self: Self) Scalar {
            return self.dot(self);
        }

        // casts
        pub fn as(self: Self, comptime Target: type) utils.TargetVector(Target)
            { return utils.doCast(self, Target, scalar_ops.as); }
        pub fn bitCast(self: Self, comptime Target: type) utils.TargetVector(Target)
            { return utils.doCast(self, Target, scalar_ops.bitCast); }

        pub fn equals(lhs: Self, rhs: Self) bool {
            inline for(Axis.values) |axis| {
                if (lhs.get(axis) != rhs.get(axis)) {
                    return false;
                }
            }
            return true;
        }

        pub fn hash(self: Self) u64 {

            comptime var rng = std.rand.Isaac64.init(0xDEAD1025DEAD0413);

            const ScalarBits = ScalarInfo.init(.unsigned_int, scalar_info.bits).scalar_type;

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

        pub const Context = struct {

            pub fn eql(self: Context, lhs: Self, rhs: Self) bool {
                return lhs.equals(rhs);
            }

            pub fn hash(self: Context, value: Self) u64 {
                return value.hash();
            }
        };

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

    };

    const dimension_specific = switch (self_info.dimensions) {
        2 => struct {

            pub fn init(x: Scalar, y: Scalar) Self {
                return common.fromArray(.{x, y});
            }

        },
        3 => struct {

            pub fn init(x: Scalar, y: Scalar, z: Scalar) Self {
                return common.fromArray(.{x, y, z});
            }

        },
        4 => struct {

            pub fn init(x: Scalar, y: Scalar, z: Scalar, w: Scalar) Self {
                return common.fromArray(.{x, y, z, w});
            }

        },
        else => unreachable,
    };

    const integer_only = struct {

        pub fn addWrap(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.addWrap); }
        pub fn subWrap(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.subWrap); }
        pub fn mulWrap(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.mulWrap); }
        pub fn divWrap(lhs: Self, rhs: Self) Self { return utils.doBinaryOp(lhs, rhs, scalar_ops.divWrap); }

        pub fn sumWrap(self: Self) Scalar { return utils.doFold(0, scalar_ops.addWrap); }
        pub fn productWrap(self: Self) Scalar { return utils.doFold(1, scalar_ops.mulWrap); }

        // casts
        pub fn intCast(self: Self, comptime Target: type) utils.TargetVector(Target)
            { return utils.doCast(self, Target, scalar_ops.intCast); }
        pub fn intToFloat(self: Self, comptime Target: type) utils.TargetVector(Target)
            { return utils.doCast(self, Target, scalar_ops.intToFloat); }
        pub fn truncate(self: Self, comptime Target: type) utils.TargetVector(Target)
            { return utils.doCast(self, Target, scalar_ops.truncate); }

    };

    const float3_only = struct {

        pub fn cross(lhs: Self, rhs: Self) Self {
            const a = lhs.toArray();
            const b = rhs.toArray();
            var result: Self = undefined;
            result.set(.x, a[1] * b[2] - a[2] * b[1]);
            result.set(.y, a[2] * b[0] - a[0] * b[2]);
            result.set(.z, a[0] * b[1] - a[1] * b[0]);
            return result;
        }

    };

    const kind_specific = switch (self_info.scalar_info.kind) {
        .signed_int => struct {

            pub fn negateWrap(rhs: Self) Self { return utils.doUnaryOp(rhs, scalar_ops.negateWrap); }

            pub usingnamespace integer_only;

        },
        .unsigned_int => struct {

            pub usingnamespace integer_only;
            
        },
        .float => struct {
            
            pub usingnamespace (
                if(dimensions == 3) float3_only
                else struct {}
            );

            // casts
            pub fn floatCast(self: Self, comptime Target: type) utils.TargetVector(Target)
                { return utils.doCast(self, Target, scalar_ops.floatCast); }
            pub fn floatToInt(self: Self, comptime Target: type) utils.TargetVector(Target)
                { return utils.doCast(self, Target, scalar_ops.floatToInt); }

            pub fn len(self: Self) Scalar {
                return @sqrt(self.len2());
            }

            pub fn normalize(self: Self) ?Self {
                const l = self.len();
                if (len != 0.0) {
                    return self.scale(1.0 / l);
                }
                else {
                    return null;
                }
            }

            pub fn normalizeAssumeNonZero(self: Self) Self {
                const l = self.len();
                if (std.debug.runtime_safety and l == 0) {
                    std.debug.panic("attempt to normalize zero vector {d}", .{self});
                }
                return self.scale(1.0 / l);
            }

            pub fn project(lhs: Self, rhs: Self) Self {
                const ratio = lhs.dot(rhs) / rhs.dot(rhs);
                return rhs.scale(ratio);
            }

            pub fn reject(lhs: Self, rhs: Self) Self {
                return lhs.sub(lhs.project(rhs));
            }

        },
    };

    const signedness_specific = switch (self_info.scalar_info.signedness()) {
        .signed => struct {
            
            pub fn negate(rhs: Self) Self { return utils.doUnaryOp(rhs, scalar_ops.negate); }

            pub fn fromCardinal(comptime direction: Cardinal) Self {
                var result = common.zero;
                const axis = comptime direction.axis();
                result.set(axis, comptime direction.sign().toScalar(Scalar));
                return result;
            }

        },
        .unsigned => struct {
            
        },
    };

    return struct {

        pub usingnamespace common;
        pub usingnamespace dimension_specific;
        pub usingnamespace kind_specific;
        pub usingnamespace signedness_specific;

    };

}

pub fn Vector(comptime Scalar: type, comptime dimensions: usize) type {
    _ = ScalarInfo.fromTypeAssert(Scalar);

    return switch (dimensions) {
        2 => extern struct {

            x: Scalar,
            y: Scalar,

            pub usingnamespace VectorMixin(@This());
        },
        3 => extern struct {

            x: Scalar,
            y: Scalar,
            z: Scalar,

            pub usingnamespace VectorMixin(@This());
        },
        4 => extern struct {

            x: Scalar,
            y: Scalar,
            z: Scalar,
            w: Scalar,

            pub usingnamespace VectorMixin(@This());
        },
        else => errorDimensionCountUnsupported(dimensions),
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

test "vector casts" {
    const vec_i32 = i32_3.init(0, 1, 2);
    const vec_f32_by_scalar = vec_i32.intToFloat(f32);
    try std.testing.expectEqual(@as(f32, 0), vec_f32_by_scalar.x);
    try std.testing.expectEqual(@as(f32, 1), vec_f32_by_scalar.y);
    try std.testing.expectEqual(@as(f32, 2), vec_f32_by_scalar.z);
    const vec_f32_by_vector = vec_i32.intToFloat(f32_3);
    try std.testing.expectEqual(@as(f32, 0), vec_f32_by_vector.x);
    try std.testing.expectEqual(@as(f32, 1), vec_f32_by_vector.y);
    try std.testing.expectEqual(@as(f32, 2), vec_f32_by_vector.z);
}