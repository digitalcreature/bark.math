const std = @import("std");
const assert = @import("assert.zig");

const builtin = std.builtin;

pub const Signedness = std.builtin.Signedness;

fn compileErrorExpected(comptime Self: type, comptime fmt: []const u8, args: anytype) noreturn {
    assert.compileError("expected " ++ fmt ++ ", found " ++ @typeName(Self), args);
}

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

    pub fn init(comptime kind: Kind, comptime bits: usize) Self {
        comptime {
            var self = Self {
                .kind = kind,
                .bits = bits,
                .scalar_type = undefined,
            };
            self.scalar_type = self.toType();
            return self;
        }
    }

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
            compileErrorExpected(Scalar, "scalar", .{})
        );
    }

    fn toType(comptime self: Self) type {
        const info: builtin.TypeInfo = switch (self.kind) {
            .signed_int => .{
                .Int = .{
                    .signedness = .signed,
                    .bits = self.bits,
                },
            },
            .unsigned_int => .{
                .Int = .{
                    .signedness = .unsigned,
                    .bits = self.bits,
                },
            },
            .float => .{
                .Float = .{
                    .bits = self.bits,
                }
            }
        };
        return @Type(info);
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
            compileErrorExpected(self.scalar_type, "{s}", .{ kind.toString() });
        }
    }

    pub fn assertSignedness(comptime self: Self, comptime signedness: Signedness) void {
        if (comptime self.signedness() != signedness) {
            compileErrorExpected(self.scalar_type, "{s} scalar", .{ @tagName(signedness) });
        }
    }

    pub fn assertInteger(comptime self: Self) void {
        if (!comptime self.isInteger()) {
            compileErrorExpected(self.scalar_type, "integer", .{});
        }
    }

    pub fn assertFloat(comptime self: Self) void {
        if (!comptime self.isFloat()) {
            compileErrorExpected(self.scalar_type, "float", .{});
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
                        else {
                            field_names[i] = field.name;
                        }
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
            compileErrorExpected(Vector, "vector", .{})
        );
    }

    pub fn isSimilar(self: Self, other: Self) bool {
        return (
            (self.dimensions == other.dimensions)
            and (self.scalar_type == other.scalar_type)
        );
    }

    pub fn assertDimensions(comptime self: Self, comptime dimensions: usize) void {
        if (self.dimensions != dimensions) {
            compileErrorExpected(self.vector_type, "{d} dimensional vector", .{dimensions});
        }
    }

    pub fn assertScalarType(comptime self: Self, comptime Scalar: type) void {
        if (self.scalar_type != Scalar) {
            compileErrorExpected(self.vector_type, "{s} vector", .{ @typeName(Scalar)});
        }
    }

    pub fn assertSimilar(comptime self: Self, comptime other: Self) void {
        if (!self.isSimilar(other)) {
            compileErrorExpected(self.vector_type, "{d} dimensional {s} vector", .{ other.dimensions, @typeName(other.scalar_type) });
        }
    }

};

pub const TypeInfo = union(enum) {
    
    Scalar: ScalarInfo,
    Vector: VectorInfo,

    const Self = @This();

    pub fn fromType(comptime Type: type) ?Self {
        return if (ScalarInfo.fromType(Type)) |info| (
            Self {
                .Scalar = info,
            }
        )
        else if (VectorInfo.fromType(Type)) |info| (
            Self {
                .Vector = info,
            }
        )
        else null;
    }

    pub fn fromTypeAssert(comptime Type: type) Self {
        return fromType(Type) orelse (
            compileErrorExpected(Type, "math type", .{})
        );
    }

    pub fn typeType(comptime self: Self) type {
        return switch (self) {
            .Scalar => |info| info.scalar_type,
            .Vector => |info| info.vector_type,
        };
    }

    pub fn scalarType(comptime self: Self) type {
        return switch (self) {
            .Scalar => |info| info.scalar_type,
            .Vector => |info| info.scalar_type,
        };
    }

    pub fn dimensions(self: Self) usize {
        return switch (self) {
            .Scalar => 1,
            .Vector => |info| info.dimensions,
        };
    }

};