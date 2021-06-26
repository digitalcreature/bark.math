usingnamespace @import("_imports.zig");
usingnamespace @import("private.zig");
usingnamespace @import("common.zig");

const scalar = @import("../scalar.zig");

pub fn operators(comptime Self: type) type {

    return struct {

        usingnamespace private(Self);
        usingnamespace common(Self);

        fn doBinaryOp(lhs: Self, rhs: Self, comptime op: fn(Scalar, Scalar) Scalar) Self {
            var result: Self = undefined;
            inline for (Axis.values) |axis| {
                result.set(axis, op(lhs.get(axis), rhs.get(axis)));
            }
            return result;
        }

        fn doUnaryOp(rhs: Self, comptime op: fn(Scalar) Scalar) Self {
            var result: Self = undefined;
            inline for (Axis.values) |axis| {
                result.set(axis, op(rhs.get(axis)));
            }
            return result;
        }

        pub fn fold(self: Self, initial: Scalar, comptime op: fn(Scalar, Scalar) Scalar) Scalar {
            var result = initial;
            inline for (Axis.values) |axis| {
                result = op(result, self.get(axis));
            }
            return result;
        }

        pub fn add(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.add); }
        pub fn sub(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.sub); }
        pub fn mul(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.mul); }
        pub fn div(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.div); }
        pub fn rem(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.rem); }
        pub fn mod(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.mod); }

        pub fn sum(self: Self) Scalar
            { return fold(0, scalar.add); }
        pub fn product(self: Self) Scalar
            { return fold(1, scalar.mul); }

        pub fn dot(lhs: Self, rhs: anytype) Scalar
            { return self.mul(rhs).sum(); }

        pub fn len2(self: Self) Scalar
            { return self.dot(self); }

        pub usingnamespace switch (scalar_info.kind) {
            .signed_int => signed_int_mixin,
            .unsigned_int => int_mixin,
            .float => float_mixin,
        };

        const int_mixin = struct {
            pub fn addWrap(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.addWrap); }
            pub fn subWrap(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.subWrap); }
            pub fn mulWrap(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.mulWrap); }
            pub fn divWrap(lhs: Self, rhs: anytype) Self { return doBinaryOp(lhs, from(rhs), scalar.divWrap); }
            
            pub fn sumWrap(self: Self) Scalar { return fold(0, scalar.addWrap); }
            pub fn productWrap(self: Self) Scalar { return fold(1, scalar.mulWrap); }

        };

        const signed_mixin = struct {

            pub fn negate(rhs: Self) Self { return doUnaryOp(rhs, scalar.negate); }

        };

        const signed_int_mixin = struct {

            pub usingnamespace signed_mixin;
            pub usingnamespace integer_mixin;

            pub fn negateWrap(rhs: Self) Self { return doUnaryOp(rhs, scalar.negateWrap); }

        };

        const float_mixin = struct {

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

                    pub fn cross(lhs: Self, rhs: Self) Self {
                        const a = lhs.toArray();
                        const b = rhs.toArray();
                        var result: Self = undefined;
                        result.set(.x, a[1] * b[2] - a[2] * b[1]);
                        result.set(.y, a[2] * b[0] - a[0] * b[2]);
                        result.set(.z, a[0] * b[1] - a[1] * b[0]);
                        return result;
                    }

                },
                4 => struct {},
                else => unreachable,
            };

        };


    };

}