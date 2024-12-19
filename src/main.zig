const std = @import("std");
const tga = @import("tgaimage.zig");

pub fn main() !void {
    const blue = tga.TGAColor{ .bgra = .{ 255, 0, 0, 255 }, .bytesPerPixel = @intFromEnum(tga.Format.RGB) };
    const white = tga.TGAColor{ .bgra = .{ 255, 255, 255, 255 }, .bytesPerPixel = @intFromEnum(tga.Format.RGB) };
    _ = white;

    var image = tga.TGAImage(10, 10, tga.TGAColor{ .bytesPerPixel = @intFromEnum(tga.Format.RGB) });
    image.set(1, 0, blue);

    _ = image.writeTGAFile("tga/dot.tga", false, true);
    _ = image.readTgaFile("tga/dot.tga");

    return;
}
