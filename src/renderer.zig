const tga = @import("tgaimage.zig");
const print = @import("std").debug.print;

pub fn ImageRenderer(comptime ImageType: type, comptime ColorFormat: type) type {
    return struct {
        pub fn line(x0: u32, y0: u32, x1: u32, y1: u32, image: *ImageType, color: ColorFormat) void {
            var t: f32 = 0.0;
            while (t < 1) : (t += 0.01) {
                // const x: u32 = x0 + (x1 - x0) * t;
                // const y: u32 = x0 + (y1 - y0) * t;
                const x: u32 = x0 + @as(u32, @intFromFloat(@as(f32, @floatFromInt(x1 - x0)) * t));
                const y: u32 = y0 + @as(u32, @intFromFloat(@as(f32, @floatFromInt(y1 - y0)) * t));
                print("x: {}, y: {}\n", .{ x, y });
                image.set(x, y, color);
            }
        }
    };
}

//pub fn imageRenderer(comptime image: anytype, color: anytype) ImageRenderer(@TypeOf(image), @TypeOf(color)) {}
