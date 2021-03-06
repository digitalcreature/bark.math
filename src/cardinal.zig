usingnamespace @import("_imports.zig");

pub const Sign = enum(u1) {
    positive = 0,
    negative = 1,

    const Self = @This();

    pub fn inverted(self: Self) Self {
        return @intToEnum(Self, ~ @enumToInt(self));
    }

    pub fn toScalar(self: Self, comptime Scalar: type) Scalar {
        const info = meta.scalarInfo(Scalar).assert();
        return switch (info.signedness()) {
            .signed => switch (self) {
                .positive => @as(Scalar, 1),
                .negative => @as(Scalar, -1),
            },
            .unsigned => switch (self) {
                .positive => @as(Scalar, 1),
                .negative => @as(Scalar, 0),
            },
        };
    }

};

fn CommonMixin(comptime Self: type) type {
    return struct {

        pub const values = std.enums.values(Self);

        const Tag = @typeInfo(Self).Enum.tag_type;

        pub fn toIndex(comptime self: Self) usize {
            return @enumToInt(self);
        }

        pub fn fromIndex(comptime value: usize) Self {
            return @intToEnum(Self, @truncate(Tag, value));
        }

    };
}

fn AxisMixin(comptime Self: type) type {


    return struct {

        pub usingnamespace CommonMixin(Self);
        pub const dimensions = values.len;

        pub fn relativeAxis(self: Self, relative: Self) Self {
            const int = (self.toIndex() + relative.toIndex()) % dimensions;
            return fromIndex(int);
        }

    };
}

fn CardinalMixin(comptime Self: type) type {

    return struct {

        pub usingnamespace CommonMixin(Self);
        pub const dimensions = values.len / 2;

        pub fn init(a: Axis(dimensions), s: Sign) Self {
            const offset: usize = @enumToInt(s) * dimensions;
            return fromIndex(a.toIndex() + offset);
        }

        pub fn axis(self: Self) Axis(dimensions) {
            const value = self.toIndex();
            return Axis(dimensions).fromIndex(value % dimensions);
        }

        pub fn sign(self: Self) Sign {
            return @intToEnum(Sign, @truncate(u1, self.toIndex() / dimensions));
        }

        pub fn inverted(self: Self) Self {
            const val = self.toIndex();
            return fromIndex((val + dimensions) % values.len);
        }

    };

}

pub fn Cardinal(comptime dimensions: usize) type {
    return switch(dimensions) {
        2 => enum(u32) {
            x_positive = 0,
            y_positive = 1,
            
            x_negative = 2,
            y_negative = 3,

            pub usingnamespace CardinalMixin(@This());
        },
        3 => enum(u32) {
            x_positive = 0,
            y_positive = 1,
            z_positive = 2,
            
            x_negative = 3,
            y_negative = 4,
            z_negative = 5,

            pub usingnamespace CardinalMixin(@This());
        },
        4 => enum(u32) {
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