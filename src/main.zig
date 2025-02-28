const print = @import("std").debug.print;
const tga = @import("tgaimage.zig");
const renderer = @import("renderer.zig");

pub fn main() !void {
    const blue = tga.TGAColor{ .bgra = .{ 255, 0, 0, 255 }, .bytesPerPixel = @intFromEnum(tga.Format.BRG) };
    const white = tga.TGAColor{ .bgra = .{ 255, 255, 255, 255 }, .bytesPerPixel = @intFromEnum(tga.Format.BRG) };
    var image = tga.tgaImage(100, 100, tga.TGAColor{ .bytesPerPixel = @intFromEnum(tga.Format.BRG) });

    const img_renderer = renderer.ImageRenderer(@TypeOf(image), @TypeOf(blue));
    img_renderer.line(0, 0, 80, 60, &image, blue);
    img_renderer.line(9, 16, 60, 60, &image, blue);
    img_renderer.line(14, 90, 80, 16, &image, white);

    _ = image.writeTGAFile("tga/dot.tga", false, true);
    // _ = image.readTgaFile("tga/dot.tga");

    return;
}
