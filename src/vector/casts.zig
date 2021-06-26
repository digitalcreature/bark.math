usingnamespace @import("_imports.zig");

usingnamespace @import("private.zig");
usingnamespace @import("common.zig");

const scalar = @import("../scalar.zig");

pub fn casts(comptime Self: type) type {

    return struct {
        
        usingnamespace private(Self);
        usingnamespace common(Self);

        fn doCast(self: Self, comptime Target: type, comptime op: ScalarCastFn(Target)) TargetVector(Target) {
            const Result = TargetVector(Target);
            const ResultScalar = TargetScalar(Target);
            const result_set = common(Result).set;
            var result: TargetVector(Target) = undefined;
            inline for (Axis.values) |axis| {
                result_set(&result, axis, op(ResultScalar, self.get(axis)));
            }
            return result;
        }

        fn ScalarCastFn(comptime Target: type) type {
            return fn (type, anytype) TargetScalar(Target);
        }

        fn TargetVector(comptime Target: type) type {
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

        fn TargetScalar(comptime Target: type) type {
            return private(TargetVector(Target)).Scalar;
        }

        pub fn as(self: Self, comptime Target: type) TargetVector(Target)
            { return doCast(self, Target, scalar.as); }
        pub fn bitCast(self: Self, comptime Target: type) TargetVector(Target)
            { return doCast(self, Target, scalar.bitCast); }

        pub usingnamespace switch (scalar_info.kind) {
            .signed_int, .unsigned_int => int_mixin,
            .float => float_mixin,
        };

        const int_mixin = struct {
            pub fn intCast(self: Self, comptime Target: type) TargetVector(Target)
                { return doCast(self, Target, scalar.intCast); }
            pub fn intToFloat(self: Self, comptime Target: type) TargetVector(Target)
                { return doCast(self, Target, scalar.intToFloat); }
            pub fn truncate(self: Self, comptime Target: type) TargetVector(Target)
                { return doCast(self, Target, scalar.truncate); }
        };

        const float_mixin = struct {
            pub fn floatCast(self: Self, comptime Target: type) TargetVector(Target)
                { return doCast(self, Target, scalar.floatCast); }
            pub fn floatToInt(self: Self, comptime Target: type) TargetVector(Target)
                { return doCast(self, Target, scalar.floatToInt); }
        };


    };

}