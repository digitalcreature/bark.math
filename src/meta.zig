const std = @import("std");
usingnamespace @import("assert.zig");

const builtin = std.builtin;

pub const Signedness = std.builtin.Signedness;

pub const ScalarInfo = struct {

    kind: Kind,
    bits: usize,
    scalar_type: type,

    pub const Kind = enum {
        signed_int,
        unsigned_int,
        float,

        pub fn toString(self: Kind) []const u8 {
            return switch (self) {
                .signed_int => "signed integer",
                .unsigned_int => "unsigned integer",
                .float => "float",
            };
        }

    };
    const Self = @This();

    pub fn fromType(comptime Scalar: type) ?Self {
        return switch (@typeInfo(Scalar)) {
            .Int => |info| (
                Self {
                    .kind = switch (info.signedness) {
                        .signed => .signed_int,
                        .unsigned => .unsigned_int,
                    },
                    .bits = info.bits,
                    .scalar_type = Scalar,
                }
            ),
            .Float => |info| (
                Self {
                    .kind = .float,
                    .bits = info.bits,
                    .scalar_type = Scalar,
                }
            ),
            else => null,
        };
    }

    pub fn fromTypeAssert(comptime Scalar: type) Self {
        return fromType(Scalar) orelse (
            errorUnexpectedType(Scalar, "scalar", .{})
        );
    }

    pub fn isInteger(comptime self: Self) bool {
        return switch(self.kind) {
            .signed_int, .unsigned_int => true,
            else => false,
        };
    }

    pub fn isFloat(comptime self: Self) bool {
        return switch(self.kind) {
            .float => true,
            else => false,
        };
    }

    pub fn signedness(comptime self: Self) Signedness {
        return switch(self.kind) {
            .signed_int, .float => .signed,
            else => .unsigned,
        };
    }

    pub fn assertKind(comptime self: Self, comptime kind: Kind) void {
        if (self.kind != kind) {
            errorUnexpectedType(self.scalar_type, "{s}", .{ kind.toString() });
        }
    }

    pub fn assertSignedness(comptime self: Self, comptime signedness: Signedness) void {
        if (comptime self.signedness() != signedness) {
            errorUnexpectedType(self.scalar_type, "{s} scalar", .{ @tagName(signedness) });
        }
    }

    pub fn assertInteger(comptime self: Self) void {
        if (!comptime self.isInteger()) {
            errorUnexpectedType(self.scalar_type, "integer", .{});
        }
    }

    pub fn assertFloat(comptime self: Self) void {
        if (!comptime self.isFloat()) {
            errorUnexpectedType(self.scalar_type, "float", .{});
        }
    }

};


pub const VectorInfo = struct {
    scalar_info: ScalarInfo,
    dimensions: usize,
    field_names: []const []const u8,

    vector_type: type,
    scalar_type: type,

    const Self = @This();

    pub fn fromType(comptime Vector: type) ?Self {
        comptime {
            switch (@typeInfo(Vector)) {
                .Struct => |info| {
                    if (info.layout != .Extern) {
                        return null;
                    }
                    const fields = info.fields;
                    const dimensions = fields.len;
                    switch (dimensions) {
                        1, 2, 3, 4 => {},
                        else => return null,
                    }

                    const Scalar = fields[0].field_type;
                    var field_names: [dimensions][]const u8 = undefined;
                    for (fields) |field, i| {
                        if (field.field_type != Scalar) {
                            return null;
                        }
                        if (field.is_comptime) {
                            return null;
                        }
                        field_names[i] = field.name;
                    }
                    return Self {
                        .scalar_info = ScalarInfo.fromType(Scalar) orelse return null,
                        .dimensions = dimensions,
                        .field_names = &field_names,
                        .vector_type = Vector,
                        .scalar_type = Scalar,
                    };
                },
                else => return null,
            }
        }
    }

    pub fn fromTypeAssert(comptime Vector: type) Self {
        return fromType(Vector) orelse (
            errorUnexpectedType(Vector, "vector", .{})
        );
    }

    pub fn isSimilar(comptime self: Self, other: Self) bool {
        return (
            (self.dimensions == other.dimensions)
            and (self.scalar_type == other.scalar_type)
        );
    }

    pub fn assertDimensions(comptime self: Self, comptime dimensions: usize) void {
        if (self.dimensions != dimensions) {
            errorUnexpectedType(self.vector_type, "{d} dimensional vector", .{dimensions});
        }
    }

    pub fn assertScalarType(comptime self: Self, comptime Scalar: type) void {
        if (self.scalar_type != Scalar) {
            errorUnexpectedType(self.vector_type, "{s} vector", .{ @typeName(Scalar)});
        }
    }

    pub fn assertSimilar(comptime self: Self, comptime other: Self) void {
        if (!self.isSimilar(other)) {
            errorUnexpectedType(self.vector_type, "{d} dimensional {s} vector", .{ other.dimensions, @typeName(other.scalar_type) });
        }
    }

};

pub const MatrixInfo = struct {
    
    scalar_info: ScalarInfo,

    row_count: usize,
    col_count: usize,

    matrix_type: type,
    scalar_type: type,

    const Self = @This();

    fn fromType(comptime Matrix: type) ?Self {
        comptime {
            const Entries = switch (@typeInfo(Matrix)) {
                .Struct => |info| get_fields: {
                    if (info.layout != .Extern) return null;
                    const fields = info.fields;
                    if (fields.len != 1) return null;
                    const field = fields[0];
                    if (!std.mem.eql(u8, field.name, "entries")) return null;
                    if (field.is_comptime) return null;
                    break :get_fields field.field_type;
                },
                else => return null,
            };
            var row_count: usize = undefined;
            var col_count: usize = undefined;
            const Row = switch (@typeInfo(Entries)) {
                .Array => |info| get_row: {
                    row_count = info.len;
                    if (info.sentinel) |_| return null;
                    break :get_row info.child;
                },
                else => return null,
            };
            const Entry = switch (@typeInfo(Row)) {
                .Array => |info| get_scalar: {
                    col_count = info.len;
                    if (info.sentinel) |_| return null;
                    break :get_scalar info.child;
                },
                else => return null,
            };
            if (!isDimensionCountSupported(row_count)) return null;
            if (!isDimensionCountSupported(col_count)) return null;
            if (ScalarInfo.fromType(Entry)) |scalar_info| {
                if (!scalar_info.isFloat()) {
                    return null;
                }
                return Self {
                    .scalar_info = scalar_info,
                    .row_count = row_count,
                    .col_count = col_count,
                    .matrix_type = Matrix,
                    .scalar_type = Entry,
                };
            }
            else {
                return null;
            }
        }
    }


    pub fn fromTypeAssert(comptime Matrix: type) Self {
        return fromType(Matrix) orelse (
            errorUnexpectedType(Matrix, "matrix", .{})
        );
    }

    pub fn isSquare(comptime self: Self) bool {
        return self.row_count == self.col_count;
    }


    pub fn assertSquare(comptime self: Self) void {
        if (self.row_count != row_count) {
            errorUnexpectedType(self.matrix_type, "square matrix", .{row_count});
        }
    }

    pub fn assertRowCount(comptime self: Self, comptime row_count: usize) void {
        if (self.row_count != row_count) {
            errorUnexpectedType(self.matrix_type, "matrix with {d} rows", .{row_count});
        }
    }

    pub fn assertColCount(comptime self: Self, comptime col_count: usize) void {
        if (self.col_count != col_count) {
            errorUnexpectedType(self.matrix_type, "matrix with {d} columns", .{col_count});
        }
    }

    pub fn assertDimensions(comptime self: Self, comptime row_count: usize, comptime col_count: usize) void {
        if (self.row_count != row_count and self.col_count != col_count) {
            errorUnexpectedType(self.matrix_type, "{d}x{d} matrix", .{row_count, col_count});
        }
    }

    pub fn assertParametersValid(comptime Scalar: type, comptime row_count: usize, comptime col_count: usize) void {
        comptime {
            ScalarInfo.fromTypeAssert(Scalar).assertFloat();
            assertDimensionCountSupported(row_count);
            assertDimensionCountSupported(col_count);
        }
    }

};