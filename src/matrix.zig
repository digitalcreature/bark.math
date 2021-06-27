usingnamespace @import("_imports.zig");

const vector = @import("vector.zig");
const cardinal = @import("cardinal.zig");

pub fn Matrix(comptime scalarType: type, comptime rowCount: usize, comptime colCount: usize) type {

    MatrixInfo.assertParametersValid(scalarType, rowCount, colCount);

    return struct {

        entries: Entries,

        pub const row_count = rowCount;
        pub const col_count = colCount;
        
        pub const Scalar = scalarType;
        pub const Entries = [row_count][col_count]Scalar;
        
        pub const ColVector = vector.Vector(Scalar, row_count);
        pub const RowVector = vector.Vector(Scalar, col_count);

        pub const RowAxis = cardinal.Axis(row_count);
        pub const ColAxis = cardinal.Axis(col_count);

        const Self = @This();

        pub const zero = std.mem.zeroes(Self);

        const FlatEntries = [row_count * col_count]Scalar;

        pub fn fromFlatArray(flat: FlatEntries) Self {
            return Self {
                .entries = @bitCast(Entries, flat),
            };
        }

        pub fn toFlatArray(self: Self) FlatEntries {
            return @bitCast(FlatEntries, self.entries);
        }

        pub fn fromRows(rows: [row_count]RowVector) Self {
            var self: Self = undefined;
            inline for (RowAxis.values) |row, r| {
                inline for (ColAxis.values) |col| {
                    self.ptr(row, col).* = rows[r].get(col) ;
                }
            }
            return self;
        }

        pub fn fromColumns(cols: [col_count]ColVector) Self {
            var self: Self = undefined;
            inline for (RowAxis.values) |row| {
                inline for (ColAxis.values) |col, c| {
                    self.ptr(row, col).* = cols[c].get(row) ;
                }
            }
            return self;
        }

        pub fn get(self: Self, comptime row: RowAxis, comptime col: ColAxis) Scalar
            { return self.entries[comptime row.toIndex()][comptime col.toIndex()]; }
        pub fn ptr(self: *Self, comptime row: RowAxis, comptime col: ColAxis) *Scalar
            { return &self.entries[comptime row.toIndex()][comptime col.toIndex()]; }
        pub fn set(self: *Self, comptime row: RowAxis, comptime col: ColAxis, entry: Scalar) void
            { self.entries[comptime row.toIndex()][comptime col.toIndex()] = entry; }

        pub fn getRow(self: Self, comptime row: RowAxis) RowVector {
            var result: RowVector = undefined;
            inline for (ColAxis.values) |col| {
                result.set(col, self.get(row, col));
            }
            return result;
        }

        pub fn getColumn(self: Self, comptime col: ColAxis) ColVector {
            var result: ColVector = undefined;
            inline for (RowAxis.values) |row| {
                result.set(row, self.get(row, col));
            }
            return result;
        }

        pub fn setRow(self: *Self, comptime row: RowAxis, value: RowVector) void {
            inline for (ColAxis.values) |col| {
                self.set(row, col, value.get(col));
            }
        }

        pub fn setColumn(self: *Self, comptime col: ColAxis, value: ColVector) void {
            inline for (RowAxis.values) |row| {
                self.set(row, col, value.get(row));
            }
        }

        pub fn transpose(self: Self) Transpose {
            var result: Transpose = undefined;
            inline for (RowAxis.values) |row| {
                inline for (ColAxis.values) |col| {
                    result.set(col, row, self.get(row, col));
                }
            }
            return result;
        }

        const Transpose = Matrix(Scalar, col_count, row_count);

        pub fn add(lhs: Self, rhs: anytype) Self {
            const Rhs = @TypeOf(rhs);
            return switch (Rhs) {
                Scalar => lhs.addScalar(rhs),
                Self => lhs.addMatrix(rhs),
                else => errorUnexpectedType(
                    Rhs, "{0s} scalar or {1d}x{2d} {0s} matrix", 
                    .{ @typeName(Scalar), row_count, col_count }
                ),
            };
        }

        fn addScalar(lhs: Self, rhs: Scalar) Self {
            var result: Self = undefined;
            inline for (RowAxis.values) |row| {
                inline for (ColAxis.values) |col| {
                    result.ptr(row, col).* = lhs.get(row, col) + rhs;
                }
            }
            return result;
        }

        fn addMatrix(lhs: Self, rhs: Self) Self {
            var result: Self = undefined;
            inline for (RowAxis.values) |row| {
                inline for (ColAxis.values) |col| {
                    result.ptr(row, col).* = lhs.get(row, col) + rhs.get(row, col);
                }
            }
            return result;
        }

        pub fn mul(lhs: Self, rhs: anytype) Product(@TypeOf(rhs)) {
            const Result = Product(@TypeOf(rhs));
            if (ScalarInfo.fromType(Result)) {
                return lhs.mulScalar(rhs);
            }
            if (VectorInfo.fromType(Result)) {
                return lhs.mulVector(rhs);
            }
            if (MatrixInfo.fromType(Result)) {
                return lhs.mulMatrix(rhs);
            }
            // one of the above checks will pass, Product() would
            // emit a compile error if rhs was not a valid operand
            unreachable;
        }

        fn mulScalar(lhs: Self, rhs: Scalar) Self {
            var result: Self = undefined;
            inline for (RowAxis.values) |row| {
                inline for (ColAxis.values) |col| {
                    result.set(row, col, rhs * lhs.get(row, col));
                }
            }
            return result;
        }

        fn mulVector(lhs: Self, rhs: RowVector) ColVector {
            var result: ColVector = ColVector.zero;
            inline for (RowAxis.values) |row| {
                inline for (ColAxis.values) |col| {
                    result.ptr(row).* += rhs.get(col) * lhs.get(row, col);
                }
            }
            return result;
        }

        fn mulMatrix(lhs: Self, rhs: anytype) ProductMatrix(@TypeOf(rhs)) {
            const Rhs = @TypeOf(rhs);
            const Result = ProductMatrix(Rhs);
            if (Result == void) {
                errorUnexpectedType(Rhs, "{s} matrix with {d} rows", .{@typeName(Scalar), col_count});    
            }
            const rhs_get = Matrix(Scalar, col_count, Result.col_count).get;
            var result = Result.zero;
            inline for (RowAxis.values) |i| {
                inline for (Result.ColAxis.values) |j| {
                    inline for (ColAxis.values) |r| {
                        result.ptr(i, j).* += lhs.get(i, r) * rhs_get(rhs, r, j);
                    }
                }
            }
            return result;
        }

        fn ProductMatrix(comptime Rhs: type) type {
            if (MatrixInfo.fromType(Rhs)) |info| {
                if (info.scalar_type != Scalar) return void;
                if (info.row_count != col_count) return void;
                return Matrix(Scalar, row_count, info.col_count);
            }
            return void;
        }

        fn Product(comptime Rhs: type) type {
            comptime {
                switch (Rhs) {
                    Scalar => return Self,
                    else => {
                        if (VectorInfo.fromType(Rhs)) |info| {
                            info.assertScalarType(Scalar);
                            info.assertDimensions(col_count);
                            return ColVector;
                        }
                        const Pm = ProductMatrix(Rhs);
                        if (Pm != void) {
                            return Pm;
                        }
                        errorUnexpectedType(Rhs, "{0s} scalar, {1d} dimensional {0s} vector, or {0s} matrix with {1d} rows", .{
                            @typeName(Scalar),
                            col_count,
                        });
                    }
                }
            }
        }

        pub usingnamespace (
            if (row_count == col_count) square_mixin
            else struct {}
        );

        const square_mixin = struct {

            pub const dimensions = row_count;
            pub const Axis = RowAxis;
            pub const Vector = ColVector;

            pub const identity = blk: {
                var id = zero;
                id.setDiagonal(1.0);
                break :blk id;
            };

            pub fn setDiagonal(self: *Self, diagonal_values: anytype) void {
                const diagonal = Vector.from(diagonal_values);
                inline for (Axis.values) |axis| {
                    self.set(axis, axis, diagonal.get(axis));
                }
            }

            pub fn determinant(self: Self) Scalar {
                var det: Scalar = 0;
                inline for (comptime axisPermutations(dimensions)) |axis_perm, perm_i| {
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
                2 => square2_mixin,
                3 => square3_mixin,
                4 => square4_mixin,
                else => unreachable,
            };

            const square2_mixin = struct {

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

            };

            const square3_mixin = struct {

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

            };

            const square4_mixin = struct {

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

            };

        };

    };

}

fn AxisPermutations(comptime dimensions: usize) type {
    const count = switch (dimensions) {
        2 => 2,
        3 => 2 * 3, 
        4 => 2 * 3 * 4, 
        else => unreachable,
    };

    return [count][dimensions]cardinal.Axis(dimensions);
}

fn axisPermutations(comptime dimensions: usize) AxisPermutations(dimensions) {
    const Ap = AxisPermutations(dimensions);
    switch (dimensions) {
        2 => return Ap {
            .{ .x, .y },    // +
            .{ .y, .x },    // -
        },
        3 => return Ap {
            .{ .x, .y, .z },    // +
            .{ .x, .z, .y },    // -
            .{ .z, .x, .y },    // +
            .{ .y, .x, .z },    // -
            .{ .y, .z, .x },    // +
            .{ .z, .y, .x },    // -
        },
        4 => return Ap {
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
    }
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