const print = @import("std").debug.print;
const tga = @import("tgaimage.zig");
const renderer = @import("renderer.zig");

pub fn main() !void {
    const blue = tga.TGAColor{ .bgra = .{ 255, 0, 0, 255 }, .bytesPerPixel = @intFromEnum(tga.Format.BRG) };
    const white = tga.TGAColor{ .bgra = .{ 255, 255, 255, 255 }, .bytesPerPixel = @intFromEnum(tga.Format.BRG) };
    _ = white;
    var image = tga.tgaImage(100, 100, tga.TGAColor{ .bytesPerPixel = @intFromEnum(tga.Format.BRG) });

    const img_renderer = renderer.ImageRenderer(@TypeOf(image), @TypeOf(blue));
    img_renderer.line(20, 10, 80, 60, &image, blue);
    //
    // print("hello", .{});
    _ = image.writeTGAFile("tga/dot.tga", false, true);
    _ = image.readTgaFile("tga/dot.tga");

    return;
}
