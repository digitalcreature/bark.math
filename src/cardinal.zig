usingnamespace @import("_imports.zig");

pub const Sign = enum(u1) {
    positive = 0,
    negative = 1,

    const Self = @This();

    pub fn inverted(self: Self) Self {
        return @intToEnum(Self, ~ @enumToInt(self));
    }

    pub fn toScalar(self: Self, comptime Scalar: type) Scalar {
        const info = ScalarInfo.fromTypeAssert(Scalar);
        return if (info.isSigned()) (
            switch (self) {
                .positive => 1,
                .negative => -1,
            }
        )
        else (
            @as(Scalar, ~ @enumToInt(self))
        );
    }

};

fn CommonMixin(comptime Self: type) type {
    return struct {

        pub const values = std.enums.values(Self);
        pub const dimensions = values.len;

        pub fn toIndex(self: Self) usize {
            return @enumToInt(self);
        }

        pub fn fromIndex(value: usize) Self {
            return @intToEnum(Self, value);
        }

    };
}

fn AxisMixin(comptime Self: type) type {


    return struct {

        pub usingnamespace CommonMixin(Self);

        pub fn relativeAxis(self: Self, relative: Self) Self {
            const int = (self.toIndex() + relative.toIndex()) % dimensions;
            return fromIndex(int);
        }

    };
}

fn CardinalMixin(comptime Self: type) type {

    return struct {

        pub usingnamespace CommonMixin(Self);

        pub fn init(axis: Axis(dimensions), sign: Sign) Self {
            const offset: usize = @enumToInt(sign) * dimensions;
            return fromIndex(axis.toIndex() + offset);
        }

        pub fn axis(self: Self) Axis(dimensions) {
            const value = self.toIndex();
            return Axis(dimensions).fromIndex(value % dimensions);
        }

        pub fn sign(self: Self) Sign {
            return @intToEnum(Sign, self.toIndex() / dimensions);
        }

        pub fn inverted(self: Self) Self {
            const val = self.toIndex();
            return fromIndex((val + dimensions) % values.len);
        }

    };

}

pub fn Cardinal(comptime dimensions: usize) type {
    return switch(dimensions) {
        2 => enum {
            x_positive = 0,
            y_positive = 1,
            
            x_negative = 2,
            y_negative = 3,

            pub usingnamespace CardinalMixin(@This());
        },
        3 => enum {
            x_positive = 0,
            y_positive = 1,
            z_positive = 2,
            
            x_negative = 3,
            y_negative = 4,
            z_negative = 5,

            pub usingnamespace CardinalMixin(@This());
        },
        4 => enum {
            x_positive = 0,
            y_positive = 1,
            z_positive = 2,
            w_positive = 3,

            x_negative = 4,
            y_negative = 5,
            z_negative = 6,
            w_negative = 7,

            pub usingnamespace CardinalMixin(@This());
        },
        else => errorDimensionCountUnsupported(dimensions),
    };
}

pub fn Axis(comptime dimensions: usize) type {
    return switch (dimensions) {
        2 => enum {
            x,
            y,

            pub usingnamespace AxisMixin(@This());
        },
        3 => enum {
            x,
            y,
            z,

            pub usingnamespace AxisMixin(@This());
        },
        4 => enum {
            x,
            y,
            z,
            w,

            pub usingnamespace AxisMixin(@This());
        },
        else => errorDimensionCountUnsupported(dimensions),
    };
}

pub const Axis2 = Axis(2);
pub const Axis3 = Axis(3);
pub const Axis4 = Axis(4);

pub const Cardinal2 = Cardinal(2);
pub const Cardinal3 = Cardinal(3);
pub const Cardinal4 = Cardinal(4);