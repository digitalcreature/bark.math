usingnamespace @import("_imports.zig");

const Vector = @import("vector.zig").Vector;
const cardinal = @import("cardinal.zig");

fn MatrixMixin(comptime Self: type) type {
    
    const self_info = comptime MatrixInfo.fromTypeAssert(Self);
    const scalar_info = self_info.scalar_info;
    const Scalar = scalar_info.scalar_type;

    const row_count = self_info.row_count;
    const col_count = self_info.col_count;

    const Fields = [row_count][col_count]Scalar;

    const RowVector = Vector(Scalar, row_count);
    const ColVector = Vector(Scalar, col_count);

    const RowAxis = cardinal.Axis(row_count);
    const ColAxis = cardinal.Axis(col_count);

    const Transpose = Matrix(Scalar, col_count, row_count);

    const utils = struct {

        pub fn Product(comptime Rhs: type) type {
            comptime {
                switch (Rhs) {
                    Scalar => return Self,
                    else => {
                        if (VectorInfo.fromType(Rhs)) |info| {
                            info.assertScalarType(Scalar);
                            info.assertDimensions(col_count);
                            return RowVector;
                        }
                        if (MatrixInfo.fromType(Rhs)) |info| {
                            info.assertScalarType(Scalar);
                            info.assertRowCount(col_count);
                            return Matrix(Scalar, row_count, info.col_count);
                        }
                        errorUnexpectedType(Rhs, "{s} scalar, {d} dimensional vector, or matrix with {d} rows", .{
                            @typeName(Scalar),
                            col_count,
                            col_count,
                        });
                    }
                }
            }
        }

    };
    
    const Product = utils.Product;

    const common = struct {

        pub const zero = std.mem.zeroes(Self);


        pub fn fill(value: Scalar) Self {
            var self: Self = undefined;
            for (self.fields) |*row| {
                for (row) |*element| {
                    element.* = value;
                }
            }
        }

        pub fn get(self: Self, comptime row: RowAxis, comptime col: ColAxis) Scalar {
            return self.fields[comptime row.toIndex()][comptime col.toIndex()];
        }

        pub fn ptr(self: *Self, comptime row: RowAxis, comptime col: ColAxis) *Scalar {
            return &self.fields[comptime row.toIndex()][comptime col.toIndex()];
        }

        pub fn set(self: *Self, comptime row: RowAxis, comptime col: ColAxis, value: Scalar) void {
            self.fields[comptime row.toIndex()][comptime col.toIndex()] = value;
        }


        pub fn transpose(self: Self) Transpose {
            var result: Transpose = undefined;
            for (self.fields) |row, r| {
                for (row) |element, c| {
                    result.fields[c][r] = element;
                }
            }
            return result;
        }

        pub fn mul(lhs: Self, rhs: anytype) Product(@TypeOf(rhs)) {
            const Result = Product(@TypeOf(rhs));
            return switch (TypeInfo.fromTypeAssert(Result)) {
                .Scalar => lhs.mulScalar(rhs),
                .Vector => lhs.mulVector(rhs),
                .Matrix => lhs.mulMatrix(rhs),
            };
        }

        fn mulScalar(lhs: Self, rhs: Scalar) Self {
            var result = self;
            for (result.fields) |*row| {
                for (row) |*element| {
                    element.* *= rhs;
                }
            }
            return result;
        }

        fn mulVector(lhs: Self, rhs: ColVector) RowVector {
            var result: RowVector = RowVector.zero;
            inline for (RowAxis.values) |row| {
                inline for (ColAxis.values) |col| {
                    result.ptr(row).* += rhs.get(col) * lhs.get(row, col);
                }
            }
            return result;
        }

        fn mulMatrix(lhs: Self, rhs: anytype) Product(@TypeOf(rhs)) {
            const Result = Product(@TypeOf(rhs));
            const ResultColAxis = cardinal.Axis(MatrixInfo.fromTypeAssert(Result).col_count);
            var result = Result.zero;
            inline for (RowAxis.values) |i| {
                inline for (ResultColAxis.values) |j| {
                    inline for (ColAxis.values) |r| {
                        result.ptr(i, j).* = lhs.get(i, r) * rhs.get(r, j);
                    }
                }
            }
            return result;
        }

    };

    const square_only = struct {

        const dimensions = row_count;
        const Axis = cardinal.Axis(dimensions);

        pub const identity = gen_identity: {
            var result = common.zero;
            var i = 0;
            while (i < dimensions) : (i += 1) {
                result.fields[i][i] = 1;
            }
            break :gen_identity result;
        };

        const axis_perm_count = count_perms: {
            var count = 1;
            var i = 1;
            while (i <= dimensions) : (i += 1) {
                count *= i;
            }
            break :count_perms count;
        };

        const axis_perms: [axis_perm_count][dimensions]Axis = switch (dimensions) {
            2 => .{
                .{ .x, .y },    // +
                .{ .y, .x },    // -
            },
            3 => .{
                .{ .x, .y, .z },    // +
                .{ .x, .z, .y },    // -
                .{ .z, .x, .y },    // +
                .{ .y, .x, .z },    // -
                .{ .y, .z, .x },    // +
                .{ .z, .y, .x },    // -
            },
            4 => .{
                .{ .x, .y, .z, .w },    // +
                .{ .x, .y, .w, .z },    // -
                .{ .x, .w, .y, .z },    // +
                .{ .w, .x, .y, .z },    // -
                .{ .x, .z, .w, .y },    // +
                .{ .x, .z, .y, .w },    // -
                .{ .w, .x, .z, .y },    // +
                .{ .x, .w, .z, .y },    // -
                .{ .z, .x, .y, .w },    // +
                .{ .z, .x, .w, .y },    // -
                .{ .z, .w, .x, .y },    // +
                .{ .w, .z, .x, .y },    // -
                .{ .y, .x, .w, .z },    // +
                .{ .y, .x, .z, .w },    // -
                .{ .w, .y, .x, .z },    // +
                .{ .y, .w, .x, .z },    // -
                .{ .y, .z, .x, .w },    // +
                .{ .y, .z, .w, .x },    // -
                .{ .y, .w, .z, .x },    // +
                .{ .w, .y, .z, .x },    // -
                .{ .z, .y, .w, .x },    // +
                .{ .z, .y, .x, .w },    // -
                .{ .w, .z, .y, .x },    // +
                .{ .z, .w, .y, .x },    // -
            },
            else => unreachable,
        };

        pub fn determinant(self: Self) Scalar {
            var det: Scalar = 0;
            inline for (axis_perms) |axis_perm, perm_i| {
                var product: Scalar = 1;
                inline for (Axis.values) |row, i| {
                    product *= self.get(row, axis_perm[i]);
                }
                // permutations are ordered in alternating even/odd parity
                switch (perm_i % 2) {
                    0 => det += product,
                    1 => det -= product,
                    else => unreachable,
                }
            }
            return det;
        }


        pub usingnamespace switch (dimensions) {
            2 => struct {

                pub fn invert(self: Self) ?Self {
                    const f = self.fields;
                    const det = self.determinant();
                    if (det > 0) {
                        return Self {
                            .fields = .{
                                .{ f[1][1] / det, -f[0][1] / det },
                                .{ -f[1][0] / det, f[0][0] / det },
                            },
                        };
                    }
                    else {
                        return null;
                    }
                }

            },
            3 => struct {

                pub fn invert(self: Self) ?Self {
                    const det = self.determinant();
                    if (det > 0) {
                        const a = self.fields[0][0];
                        const b = self.fields[0][1];
                        const c = self.fields[0][2];
                        const d = self.fields[1][0];
                        const e = self.fields[1][1];
                        const f = self.fields[1][2];
                        const g = self.fields[2][0];
                        const h = self.fields[2][1];
                        const i = self.fields[2][2];
                        return Self {
                            .fields = .{
                                .{ (e*i-f*h) / det, (c*h-b*i) / det, (b*f-c*e) / det },
                                .{ (f*g-d*i) / det, (a*i-c*g) / det, (c*d-a*f) / det },
                                .{ (d*h-e*g) / det, (b*g-a*h) / det, (a*e-b*d) / det },
                            },
                        };
                    }
                    else return null;
                }

            },
            4 => struct {

                pub fn invert(self: Self) ?Self {
                    const a = self.fields;
                    const b = [12]Scalar {
                        a[0][0] * a[1][1] - a[0][1] * a[1][0],
                        a[0][0] * a[1][2] - a[0][2] * a[1][0],
                        a[0][0] * a[1][3] - a[0][3] * a[1][0],

                        a[0][1] * a[1][2] - a[0][2] * a[1][1],
                        a[0][1] * a[1][3] - a[0][3] * a[1][1],
                        a[0][2] * a[1][3] - a[0][3] * a[1][2],

                        a[2][0] * a[3][1] - a[2][1] * a[3][0],
                        a[2][0] * a[3][2] - a[2][2] * a[3][0],
                        a[2][0] * a[3][3] - a[2][3] * a[3][0],

                        a[2][1] * a[3][2] - a[2][2] * a[3][1],
                        a[2][1] * a[3][3] - a[2][3] * a[3][1],
                        a[2][2] * a[3][3] - a[2][3] * a[3][2],
                    };
                    const det = (
                        b[00] * b[11] +
                        b[02] * b[09] + 
                        b[03] * b[08] +
                        b[05] * b[06] +
                        - b[01] * b[10]
                        - b[04] * b[07] 
                    );
                    if (det > 0) {
                        return Self {
                            .fields = .{
                                .{
                                    (a[1][1] * b[11] - a[1][2] * b[10] + a[1][3] * b[09]) / det, // 0
                                    (a[0][2] * b[10] - a[0][1] * b[11] - a[0][3] * b[09]) / det, // 1
                                    (a[3][1] * b[05] - a[3][2] * b[04] + a[3][3] * b[03]) / det, // 2
                                    (a[2][2] * b[04] - a[2][1] * b[05] - a[2][3] * b[03]) / det, // 3
                                },
                                .{
                                    (a[1][2] * b[08] - a[1][0] * b[11] - a[1][3] * b[07]) / det, // 4
                                    (a[0][0] * b[11] - a[0][2] * b[08] + a[0][3] * b[07]) / det, // 5
                                    (a[3][2] * b[02] - a[3][0] * b[05] - a[3][3] * b[01]) / det, // 6
                                    (a[2][0] * b[05] - a[2][2] * b[02] + a[2][3] * b[01]) / det, // 7
                                },
                                .{
                                    (a[1][0] * b[10] - a[1][1] * b[08] + a[1][3] * b[06]) / det, // 8
                                    (a[0][1] * b[08] - a[0][0] * b[10] - a[0][3] * b[06]) / det, // 9
                                    (a[3][0] * b[04] - a[3][1] * b[02] + a[3][3] * b[00]) / det, // 10
                                    (a[2][1] * b[02] - a[2][0] * b[04] - a[2][3] * b[00]) / det, // 11
                                },
                                .{
                                    (a[1][1] * b[07] - a[1][0] * b[09] - a[1][2] * b[06]) / det, // 12
                                    (a[0][0] * b[09] - a[0][1] * b[07] + a[0][2] * b[06]) / det, // 13
                                    (a[3][1] * b[01] - a[3][0] * b[03] - a[3][2] * b[00]) / det, // 14
                                    (a[2][0] * b[03] - a[2][1] * b[01] + a[2][2] * b[00]) / det, // 15
                                },
                            },
                        };
                    }
                    else {
                        return null;
                    }

                }

            },
            else => unreachable,
        };

    };

    return struct {

        pub usingnamespace common;

        pub usingnamespace (
            if (self_info.isSquare()) square_only
            else struct {}
        );

    };
}

pub fn Matrix(comptime Scalar: type, comptime row_count: usize, col_count: usize) type {

    comptime MatrixInfo.assertParametersValid(Scalar, row_count, col_count);

    return extern struct {

        fields: [row_count][col_count]Scalar,

        pub usingnamespace MatrixMixin(@This());

    };

}

pub const types = struct {

    pub const f16_2x2 = Matrix(f16, 2, 2);
    pub const f16_2x3 = Matrix(f16, 2, 3);
    pub const f16_2x4 = Matrix(f16, 2, 4);
    pub const f16_3x2 = Matrix(f16, 3, 2);
    pub const f16_3x3 = Matrix(f16, 3, 3);
    pub const f16_3x4 = Matrix(f16, 3, 4);
    pub const f16_4x2 = Matrix(f16, 4, 2);
    pub const f16_4x3 = Matrix(f16, 4, 3);
    pub const f16_4x4 = Matrix(f16, 4, 4);

    pub const f32_2x2 = Matrix(f32, 2, 2);
    pub const f32_2x3 = Matrix(f32, 2, 3);
    pub const f32_2x4 = Matrix(f32, 2, 4);
    pub const f32_3x2 = Matrix(f32, 3, 2);
    pub const f32_3x3 = Matrix(f32, 3, 3);
    pub const f32_3x4 = Matrix(f32, 3, 4);
    pub const f32_4x2 = Matrix(f32, 4, 2);
    pub const f32_4x3 = Matrix(f32, 4, 3);
    pub const f32_4x4 = Matrix(f32, 4, 4);

    pub const f64_2x2 = Matrix(f64, 2, 2);
    pub const f64_2x3 = Matrix(f64, 2, 3);
    pub const f64_2x4 = Matrix(f64, 2, 4);
    pub const f64_3x2 = Matrix(f64, 3, 2);
    pub const f64_3x3 = Matrix(f64, 3, 3);
    pub const f64_3x4 = Matrix(f64, 3, 4);
    pub const f64_4x2 = Matrix(f64, 4, 2);
    pub const f64_4x3 = Matrix(f64, 4, 3);
    pub const f64_4x4 = Matrix(f64, 4, 4);

};

pub const glsl = struct {

    pub const mat2x2 = Matrix(f32, 2, 2);
    pub const mat2x3 = Matrix(f32, 2, 3);
    pub const mat2x4 = Matrix(f32, 2, 4);
    pub const mat3x2 = Matrix(f32, 3, 2);
    pub const mat3x3 = Matrix(f32, 3, 3);
    pub const mat3x4 = Matrix(f32, 3, 4);
    pub const mat4x2 = Matrix(f32, 4, 2);
    pub const mat4x3 = Matrix(f32, 4, 3);
    pub const mat4x4 = Matrix(f32, 4, 4);
    
    pub const mat2 = mat2x2;
    pub const mat3 = mat3x3;
    pub const mat4 = mat4x4;

    pub const dmat2x2 = Matrix(f64, 2, 2);
    pub const dmat2x3 = Matrix(f64, 2, 3);
    pub const dmat2x4 = Matrix(f64, 2, 4);
    pub const dmat3x2 = Matrix(f64, 3, 2);
    pub const dmat3x3 = Matrix(f64, 3, 3);
    pub const dmat3x4 = Matrix(f64, 3, 4);
    pub const dmat4x2 = Matrix(f64, 4, 2);
    pub const dmat4x3 = Matrix(f64, 4, 3);
    pub const dmat4x4 = Matrix(f64, 4, 4);

    pub const dmat2 = dmat2x2;
    pub const dmat3 = dmat3x3;
    pub const dmat4 = dmat4x4;

};

pub const hlsl = struct {

    pub const half2x2 = Matrix(f16, 2, 2);
    pub const half2x3 = Matrix(f16, 2, 3);
    pub const half2x4 = Matrix(f16, 2, 4);
    pub const half3x2 = Matrix(f16, 3, 2);
    pub const half3x3 = Matrix(f16, 3, 3);
    pub const half3x4 = Matrix(f16, 3, 4);
    pub const half4x2 = Matrix(f16, 4, 2);
    pub const half4x3 = Matrix(f16, 4, 3);
    pub const half4x4 = Matrix(f16, 4, 4);

    pub const float2x2 = Matrix(f32, 2, 2);
    pub const float2x3 = Matrix(f32, 2, 3);
    pub const float2x4 = Matrix(f32, 2, 4);
    pub const float3x2 = Matrix(f32, 3, 2);
    pub const float3x3 = Matrix(f32, 3, 3);
    pub const float3x4 = Matrix(f32, 3, 4);
    pub const float4x2 = Matrix(f32, 4, 2);
    pub const float4x3 = Matrix(f32, 4, 3);
    pub const float4x4 = Matrix(f32, 4, 4);

    pub const double2x2 = Matrix(f64, 2, 2);
    pub const double2x3 = Matrix(f64, 2, 3);
    pub const double2x4 = Matrix(f64, 2, 4);
    pub const double3x2 = Matrix(f64, 3, 2);
    pub const double3x3 = Matrix(f64, 3, 3);
    pub const double3x4 = Matrix(f64, 3, 4);
    pub const double4x2 = Matrix(f64, 4, 2);
    pub const double4x3 = Matrix(f64, 4, 3);
    pub const double4x4 = Matrix(f64, 4, 4);

};