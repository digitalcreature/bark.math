usingnamespace @import("_imports.zig");
usingnamespace @import("private.zig");

pub fn common(comptime Self: type) type {

    return struct {

        usingnamespace private(Self);

        pub const zero = fill(0);
        pub const one = fill(1);

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
                    const src_get = common(Src).get;
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

        pub fn get(self: Self, comptime axis: Axis) Scalar {
            return @field(self, self_info.field_names[comptime axis.toIndex()]);
        }

        pub fn ptr(self: Self, comptime axis: Axis) *Scalar {
            return &@field(self, self_info.field_names[comptime axis.toIndex()]);
        }

        pub fn set(self: Self, comptime axis: Axis, value: Scalar) void {
            @field(self, self_info.field_names[comptime axis.toIndex()]) = value;
        }

        fn Swizzle(comptime swizzle_string: []const u8) type {
            return switch (swizzle_string.len) {
                2, 3, 4 => Vector(Scalar, swizzle_string.len),
                else => compileError("invalid swizzle string \"{s}\" length must be 2, 3, or 4", .{swizzle_string}),
            };
        }

        pub fn swizzle(self: Self, comptime swizzle_string: []const u8) Swizzle(swizzle_string) {
            var result: [swizzle_string.len]Scalar = undefined;
            inline for (swizzle_string) |specifier, i| {
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

        pub const HashContext = struct {

            pub fn eql(self: Context, lhs: Self, rhs: Self) bool {
                return lhs.eql(rhs);
            }

            pub fn hash(self: Context, value: Self) u64 {
                return value.hash();
            }

        };

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
        };
        
    };

}