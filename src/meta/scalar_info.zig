const std = @import("std");
usingnamespace @import("../assert.zig");
usingnamespace @import("info_result.zig");

pub const scalarInfo = ScalarInfo.init;

pub const ScalarInfo = struct {
    
    found_type: type,
    kind_info: KindInfo,

    pub const KindInfo = union (Kind) {
        signed_integer: SignedIntegerInfo,
        unsigned_integer: UnsignedIntegerInfo,
        float: FloatInfo,
    };

    pub const Result = InfoResult(Self, "scalar");

    const Self = @This();

    pub fn init(comptime Scalar: type) Result {
        const kind_info = switch (@typeInfo(Scalar)) {
            .Int => |info| (
                switch (info.signedness) {
                    .signed => KindInfo {
                        .signed_integer = .{ .bits = info.bits }
                    },
                    .unsigned => KindInfo {
                        .unsigned_integer = .{ .bits = info.bits }
                    },
                }
            ),
            .Float => |info| (
                KindInfo {
                    .float = .{ .bits = FloatBits.fromUsize(info.bits), }
                }
            ),
            else => return Result.initInvalid(Scalar),
        };
        const self = Self {
            .found_type = Scalar,
            .kind_info = kind_info,
        };
        return Result.initValid(self);
    }

    pub fn bits(comptime self: Self) usize {
        return switch (self.kind_info) {
            .signed_integer => |info| info.bits,
            .unsigned_integer => |info| info.bits,
            .float => |info| info.bits.toUsize(),
        };
    }

    pub fn signedness(comptime self: Self) Signedness {
        return switch (self.kind_info) {
            .signed_integer, .float => .signed,
            .unsigned_integer => .unsigned,
        };
    }

    pub fn format(comptime self: Self) Format {
        return switch (self.kind_info) {
            .signed_integer, .unsigned_integer => .integer,
            .float => .float,
        };
    }

    pub fn assertBits(comptime self: Self, comptime expected_bits: usize) void {
        if (self.bits() != expected_bits) {
            errorUnexpectedType(self.found_type, "{d} bit scalar", .{ expected_bits });
        }
    }

    pub fn assertSignedness(comptime self: Self, comptime expected_signedness: Signedness) void {
        if (self.signedness() != expected_signedness) {
            errorUnexpectedType(self.found_type, "{s} scalar", .{ @tagName(expected_signedness) });
        }
    }

    pub fn assertKind(comptime self: Self, comptime expected_kind: Kind) void {
        if (self.kind_info != expected_kind) {
            errorUnexpectedType(self.found_type, "{s} scalar", .{ expected_kind.toString() });
        }
    }

    pub fn assertFormat(comptime self: Self, comptime expected_format: Format) void {
        if (self.format() != expected_format) {
            errorUnexpectedType(self.found_type, "{s} scalar", .{ @tagName(expected_format) });
        }
    }

    pub const Format = ScalarFormat;
    pub const Kind = ScalarKind;


    pub const SignedIntegerInfo = struct {
        
        bits: usize,

    };

    pub const UnsignedIntegerInfo = struct {
        
        bits: usize,

    };

    pub const FloatInfo = struct {
        
        bits: FloatBits,

    };


};

pub const FloatBits = enum(usize) {

    x16 = 16,
    x32 = 32,
    x64 = 64,
    x128 = 128,

    const Self = @This();

    pub fn toUsize(comptime self: Self) usize {
        return @enumToInt(self);
    }

    pub fn fromUsize(comptime value: usize) Self {
        return switch (value) {
            16, 32, 64, 128 => @intToEnum(Self, value),
            else => compileError("invalid bit count {d} for floating point type", .{value}),
        };
    }

};

pub const Signedness = std.builtin.Signedness;

pub const ScalarKind = enum {

    signed_integer,
    unsigned_integer,
    float,

    const Self = @This();

    pub fn toString(comptime self: Self) []const u8 {
        return switch (self) {
            .signed_integer => "signed integer",
            .unsigned_integer => "unsigned integer",
            .float => "float",
        };
    }

};

pub const ScalarFormat = enum {

    integer,
    float,

};