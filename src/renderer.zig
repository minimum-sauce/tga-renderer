const tga = @import("tgaimage.zig");

fn line(x0: u32, y0: u32, x1: u32, y1: u32, image: tga.TGAImage, color: tga.TGAColor) void {
    var t: f32 = 0.0;
    while (t < 1) : (t += 0.01) {
        const x: u32 = x0 + (x1 - x0) * t;
        const y: u32 = x0 + (y1 - y0) * t;
        image.set(x, y, color);
    }
}
