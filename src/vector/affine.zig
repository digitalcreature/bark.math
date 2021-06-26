usingnamespace @import("_imports.zig");
usingnamespace @import("private.zig");
usingnamespace @import("common.zig");

pub fn affine(comptime Self: type) type {

    if (private(Self).scalar_info.kind == .float) {
        
        return struct {

            usingnamespace private(Self);
            usingnamespace common(Self);

            const float3_mixin = struct {

                const float4 = Vector(Scalar, 4);

                pub fn asAffinePosition(self: Self) float4 {
                    return float4.init(
                        self.get(.x),
                        self.get(.y),
                        self.get(.z),
                        1,
                    );
                }

                pub fn asAffineDirection(self: Self) float4 {
                    return float4.init(
                        self.get(.x),
                        self.get(.y),
                        self.get(.z),
                        0,
                    );
                }

                pub const fromAffinePosition = float4_mixin.asAffinePosition;
                pub const fromAffineDirection = float4_mixin.asAffineDirection;

            };

            const float4_mixin = struct {
                const float3 = Vector(Scalar, 3);

                pub fn asAffinePosition(self: Self) ?float3 {
                    const w = self.get(.w);
                    if (w == 0) return null;
                    return float3.init(
                        self.get(.x) / w,
                        self.get(.y) / w,
                        self.get(.z) / w,
                    );
                }

                pub fn asAffineDirection(self: Self) float3 {
                    return float3.init(
                        self.get(.x),
                        self.get(.y),
                        self.get(.z),
                    );
                }

                pub const fromAffinePosition = float3_mixin.asAffinePosition;
                pub const fromAffineDirection = float3_mixin.asAffineDirection;

            };

            pub usingnamespace switch (dimensions) {
                2 => struct { },
                3 => float3_mixin,
                4 => float4_mixin,
                else => unreachable,
            };

        };

    }
    else {
        return struct {};
    }

}