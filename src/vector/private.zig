usingnamespace @import("_imports.zig");

const cardinal = @import("../cardinal.zig");

pub fn private(comptime Self: type) type {

    return struct {

        pub const self_info = VectorInfo.fromTypeAssert(Self);
        pub const scalar_info = self_info.scalar_info;

        pub const Scalar = self_info.scalar_type;
        pub const dimensions = self_info.dimensions;

        pub const Cardinal = cardinal.Cardinal(dimensions);
        pub const Axis = cardinal.Axis(dimensions);


    };

}