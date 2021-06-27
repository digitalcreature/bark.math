const std = @import("std");
usingnamespace @import("../assert.zig");

pub fn InfoResult(comptime Info: type, comptime kind_name: []const u8) type {

    return union(enum) {
        
        info: Info,
        invalid: Invalid,

        pub const Invalid = struct {
            
            found_type: type,

        };

        const Self = @This();

        pub fn initValid(comptime info: Info) Self {
            return Self {
                .info = info,
            };
        }

        pub fn initInvalid(comptime found_type: type) Self {
            return Self {
                .invalid = .{
                    .found_type = found_type,
                },
            };
        }

        pub fn assert(comptime self: Self) Info {
            switch (self) {
                .info => |info| return info,
                .invalid => |e| {
                    errorUnexpectedType(e.found_type, "{s}", .{ kind_name });
                },
            }
        }

        pub fn opt(comptime self: Self) ?Info {
            return switch (self) {
                .info => |info| info,
                .invalid => null,
            };
        }
        
    };

}
