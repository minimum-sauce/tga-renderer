const tga = @import("tgaimage.zig");
const print = @import("std").debug.print;
const math = @import("std").math;

pub fn ImageRenderer(comptime ImageType: type, comptime ColorFormat: type) type {
    return struct {
        pub fn line(x0: u32, y0: u32, x1: u32, y1: u32, image: *ImageType, color: ColorFormat) void {
            const delta_x: u32 = if (x1 > x0) x1 - x0 else x0 - x1;
            const delta_y: u32 = if (y1 > y0) y1 - y0 else y0 - y1;
            // const length: f64 = @sqrt(math.pow(f64, @floatFromInt(delta_x), 2) + math.pow(f64, @floatFromInt(delta_y), 2));
            // if (length == 0.0) {
            //     return;
            // }
            const increment: f64 = if (delta_x > delta_y) 1.0 / @as(f64, @floatFromInt(delta_x)) else 1.0 / @as(f64, @floatFromInt(delta_y)); // const increment = 0.01

            var t: f64 = 0.0;
            while (t < 1.0) : (t += increment) {
                var x: u32 = 0;
                var y: u32 = 0;
                if (x0 < x1) {
                    x = x0 + @as(u32, @intFromFloat(@round(@as(f32, @floatFromInt(delta_x)) * t)));
                } else {
                    x = x0 - @as(u32, @intFromFloat(@round(@as(f32, @floatFromInt(delta_x)) * t)));
                }
                if (y0 < y1) {
                    y = y0 + @as(u32, @intFromFloat(@round(@as(f32, @floatFromInt(delta_y)) * t)));
                } else {
                    y = y0 - @as(u32, @intFromFloat(@round(@as(f32, @floatFromInt(delta_y)) * t)));
                }
                // print("x: {}, y: {}\n", .{ x, y });
                image.set(x, y, color);
            }
        }
    };
}
