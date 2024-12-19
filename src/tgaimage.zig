const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const File = std.fs.File;
const writePackedInt = std.mem.writePackedInt;
const readPackedInt = std.mem.readPackedInt;
const endian = std.builtin.Endian.little;

pub const Format = enum(u8) { GRAYSCALE = 1, RGB = 3, RGBA = 4 };
//pub const DataTypeCode = enum(u8) { NO_DATA = 0, UNCOMPRESSED_COLOR_MAPPED = 1, UNCOMPRESSED_RGB = 2, UNCOMPRESSED_GRAYSCALE = 3, RUNLENGTH_ENCODED_RGB = 9, COMPRESSED_GRAYSCALE = 10 };

const TGAHeader = packed struct {
    const Self = @This();
    idLength: u8 = 0,
    colorMapType: u8 = 0,
    dataTypeCode: u8 = 0,
    colorMapOrigin: u16 = 0,
    colorMapLength: u16 = 0,
    colorMapDepth: u8 = 0,
    xOrigin: u16 = 0,
    yOrigin: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,
    bitsperpixel: u8 = 0,
    imageDescriptor: u8 = 0,

    fn serialize(header: Self) [18]u8 {
        var arr_header: [18]u8 = [1]u8{@as(u8, 0)} ** 18;

        arr_header[0] = header.idLength;
        arr_header[1] = header.colorMapType;
        arr_header[2] = header.dataTypeCode;

        // Color map specification
        writePackedInt(u16, arr_header[3..5], 0, header.colorMapOrigin, endian);
        writePackedInt(u16, arr_header[5..7], 0, header.colorMapLength, endian);
        arr_header[7] = header.colorMapDepth;

        // Image specification
        writePackedInt(u16, arr_header[8..10], 0, header.xOrigin, endian);
        writePackedInt(u16, arr_header[10..12], 0, header.yOrigin, endian);
        writePackedInt(u16, arr_header[12..14], 0, header.width, endian);
        writePackedInt(u16, arr_header[14..16], 0, header.height, endian);
        arr_header[16] = header.bitsperpixel;
        arr_header[17] = header.imageDescriptor;
        std.debug.print("serialized header: ", .{});
        for (arr_header) |byte| {
            std.debug.print(" {b} ", .{byte});
        }
        return arr_header;
    }
    fn deserialize(self: Self, serialized_header: [18]u8) void {
        self.idLength = serialized_header[0];
        self.colorMapType = serialized_header[1];
        self.dataTypeCode = serialized_header[2];

        writePackedInt(u16, serialized_header[3..5], 0, self.colorMapOrigin, endian);
        writePackedInt(u16, serialized_header[5..7], 0, self.colorMapLength, endian);
        self.colorMapDepth = serialized_header[7];

        readPackedInt(u16, serialized_header[8..10], 0, self.xOrigin, endian);
        readPackedInt(u16, serialized_header[10..12], 0, self.yOrigin, endian);
        readPackedInt(u16, serialized_header[12..14], 0, self.width, endian);
        readPackedInt(u16, serialized_header[14..16], 0, self.height, endian);
        self.bitsperpixel = serialized_header[16];
        self.imageDescriptor = serialized_header[17];
    }
};

pub const TGAColor = struct {
    const Self = @This();
    bgra: [4]u8 = .{ 0, 0, 0, 0 },
    bytesPerPixel: u8 = 4,

    pub fn Print(self: Self) void {
        std.debug.print("[B: {d}, G: {d}, R: {d}, A: {d}]\n", .{ self.bgra[0], self.bgra[1], self.bgra[2], self.bgra[3] });
    }
};

pub fn TGAImage(comptime width: u16, comptime height: u16, comptime pixel: TGAColor) type {
    return struct {
        const Self = @This();
        width: u16 = width,
        height: u16 = height,
        bitsPerPixel: u8 = pixel.bytesPerPixel,
        data: [width * height * pixel.bytesPerPixel]u8,

        pub fn init() Self {
            return Self{
                .data = [_]u8{@as(u8, 0)} ** (width * height * pixel.bytesPerPixel),
            };
        }

        pub fn readTgaFile(self: *Self, fileName: [:0]const u8) bool {
            const image = std.fs.cwd().openFile(fileName, .{}) catch |err| {
                std.debug.print("unable to open file: error '{d}'", .{@intFromError(err)});
                unreachable;
            };
            defer image.close();

            var r = std.io.bitReader(endian, image.reader());
            var reader = r.reader();

            var header = TGAHeader{};

            _ = reader.readAll(@as([*]u8, @ptrCast(&header))[0..18]) catch unreachable;
            std.debug.print("'{s}', data_type_code: {d}\n", .{ @as([*]u8, @ptrCast(&header))[0..@sizeOf(TGAHeader)], header.dataTypeCode });

            std.debug.print("header width: {d}, height: {d}, bpp: {d}\n", .{ header.width, header.height, header.bitsperpixel >> 3 });
            self.width = header.width;
            self.height = header.height;
            self.bitsPerPixel = header.bitsperpixel >> 3;

            if (self.width <= 0 or self.height <= 0) {
                std.debug.print("bad width/height value\n", .{});
                return false;
            }

            switch (self.bitsPerPixel) {
                @intFromEnum(Format.GRAYSCALE) => {},
                @intFromEnum(Format.RGB) => {},
                @intFromEnum(Format.RGBA) => {},
                else => {
                    std.debug.print("bad Bits Per Pixel (format) value\n", .{});
                    return false;
                },
            }

            if (header.dataTypeCode == 2 or header.dataTypeCode == 3) {
                _ = reader.readAll(&self.data) catch unreachable;
            } else if (header.dataTypeCode == 10 or header.dataTypeCode == 11) {
                if (self.loadRleData(image)) {
                    std.debug.print("an error occured while reading the data\n", .{});
                    return false;
                }
            } else {
                std.debug.print("Error: unknown file format {d}\n", .{header.dataTypeCode});
                return false;
            }

            return true;
        }

        pub fn loadRleData(self: *Self, file: std.fs.File) bool {
            const pixelCount: u64 = self.width * self.height;
            var currentPixel: u64 = 0;
            var currentByte: u64 = 0;
            var colorBuffer = TGAColor{};

            while (currentPixel < pixelCount) : (currentPixel += 1) {
                var chunkHeader: u8 = 0;
                _ = file.readAll(@as([*]u8, @ptrCast(&chunkHeader))[0..1]) catch unreachable;
                if (chunkHeader == 0) {
                    std.debug.print("an error has occured while reading the data \n", .{});
                    return false;
                }
                if (chunkHeader < 128) {
                    chunkHeader += 1;
                    var i: u32 = 0;
                    while (i < chunkHeader) : (i += 1) {
                        _ = file.readAll(@as([*]u8, &colorBuffer.bgra)[0..self.bitsPerPixel]) catch unreachable;
                    }

                    for (colorBuffer.bgra[0..self.bitsPerPixel]) |color| {
                        self.data[currentByte] = color;
                        currentByte += 1;
                    }
                    if (currentPixel >= pixelCount) {
                        std.debug.print("Too many pixels read", .{});
                        return false;
                    }
                } else {
                    chunkHeader -= 127;
                    var i: u32 = 0;
                    while (i < chunkHeader) : (i += 1) {
                        _ = file.readAll(@as([*]u8, &colorBuffer.bgra)[0..self.bitsPerPixel]) catch unreachable;
                    }

                    for (colorBuffer.bgra[0..self.bitsPerPixel]) |color| {
                        self.data[currentByte] = color;
                        currentByte += 1;
                    }
                    if (currentPixel >= pixelCount) {
                        std.debug.print("Too many pixels read", .{});
                        return false;
                    }
                }
            }
            return true;
        }

        pub fn writeTGAFile(self: Self, fileName: []const u8, vflip: bool, rle: bool) bool {
            const developerAreaRef: [4]u8 = .{ 0, 0, 0, 0 };
            const extentionAreaRef: [4]u8 = .{ 0, 0, 0, 0 };
            const footer: [18:0]u8 = [18:0]u8{ 'T', 'R', 'U', 'E', 'V', 'I', 'S', 'I', 'O', 'N', '-', 'X', 'F', 'I', 'L', 'E', '.', 0 };

            const image = std.fs.cwd().openFile(fileName, File.OpenFlags{ .mode = File.OpenMode.write_only }) catch |err| {
                std.debug.print("unable to open file: '{s}'", .{@errorName(err)});
                unreachable;
            };
            defer image.close();
            //var buffWriter = std.io.bufferedWriter(image.writer());
            var w = std.io.bitWriter(endian, image.writer());

            var writer = w.writer();

            const header = TGAHeader{
                .bitsperpixel = self.bitsPerPixel << 3,
                .width = @as(u16, self.width),
                .height = @as(u16, self.height),
                .imageDescriptor = if (vflip) 0x00 else 0x20,
                .dataTypeCode = switch (self.bitsPerPixel == @intFromEnum(Format.GRAYSCALE)) {
                    true => switch (rle) {
                        true => 11,
                        false => 3,
                    },
                    false => switch (rle) {
                        true => 10,
                        false => 2,
                    },
                },
            };

            _ = writer.write(header.serialize()[0..]) catch |err| {
                std.debug.print("error: {s}", .{@errorName(err)});
            };

            if (!rle) {
                writer.writeAll(self.data[0..]) catch unreachable;
            } else if (!self.unloadRleData(writer)) {
                std.debug.print("can't dump the tga file\n", .{});
                return false;
            }
            _ = writer.writeAll(developerAreaRef[0..]) catch unreachable;
            _ = writer.writeAll(extentionAreaRef[0..]) catch unreachable;
            _ = writer.writeAll(footer[0..]) catch unreachable;

            return true;
        }

        pub fn unloadRleData(self: Self, writer: std.io.BitWriter(std.builtin.Endian.little, File.Writer).Writer) bool {
            const maxChunkLength: u8 = 128;
            const nPixels = self.width * self.height;
            std.debug.print("\npixels: {d}\n", .{nPixels});
            var val: u8 = 0;
            var currentPixel: u32 = 0;

            while (currentPixel < nPixels) : (currentPixel += 1) {
                const chunkStart = currentPixel * self.bitsPerPixel;
                var currentByte = currentPixel * self.bitsPerPixel;
                var runLength: u8 = 1;
                var raw = true;

                while (currentPixel + runLength < nPixels and runLength < maxChunkLength) : (runLength += 1) {
                    var succ_eq = true;
                    var t: u32 = 0;
                    if (self.data[currentByte] != 0 or self.data[currentByte + 1] != 0 or self.data[currentByte + 2] != 0) {
                        std.debug.print("[B: {d}, G: {d}, R:{d}]\n", .{ self.data[currentByte], self.data[currentByte + 1], self.data[currentByte + 2] });
                    }

                    while (succ_eq and t < self.bitsPerPixel) : (t += 1) {
                        succ_eq = (self.data[currentByte + t] == self.data[currentByte + t + self.bitsPerPixel]);
                    }
                    currentByte += self.bitsPerPixel;
                    if (runLength == 1) {
                        raw = !succ_eq;
                    }
                    if (raw) {
                        std.debug.print("red!\n", .{});
                    }
                    if (raw and succ_eq) {
                        runLength -= 1;
                        break;
                    }
                    if (!raw and !succ_eq) {
                        break;
                    }
                }
                currentPixel += runLength;
                if (raw) {
                    const rl = runLength - 1;
                    val += 1 + runLength * self.bitsPerPixel;
                    std.debug.print("added 1 pixel!\n", .{});
                    writer.writeByte(rl) catch unreachable;
                    writer.writeAll(self.data[chunkStart .. chunkStart + runLength * self.bitsPerPixel]) catch unreachable;
                } else {
                    val += 1 + self.bitsPerPixel;
                    std.debug.print("added {d} bytes!\n", .{runLength});
                    const rl = runLength + 127;
                    writer.writeByte(rl) catch unreachable;
                    writer.writeAll(self.data[chunkStart .. chunkStart + self.bitsPerPixel]) catch unreachable;
                }
            }
            std.debug.print("total bytes: {d}\n", .{val});
            return true;
        }

        pub fn get(self: *Self, x: u32, y: u32) TGAColor {
            if (self.data.len == 0 or x < 0 or y < 0 or x >= self.width or y >= self.height) {
                unreachable;
            }
            var ret: TGAColor = TGAColor{ .bytesPerPixel = self.bitsPerPixel };
            const start: u32 = (x + y + self.width) * self.bitsPerPixel;
            for (self.data[start .. start + self.bitsPerPixel], 0..) |color, index| {
                ret.bgra[index] = color;
            }
            return ret;
        }

        pub fn set(self: *Self, x: u32, y: u32, color: TGAColor) void {
            const start: u32 = (x + y * self.width) * self.bitsPerPixel;
            for (self.data[start .. start + self.bitsPerPixel], 0..) |*rgbValue, index| {
                rgbValue.* = color.bgra[index];
            }
        }

        pub fn flip_horizontally(self: *Self) void {
            const half = self.width >> 1;
            comptime var w = 0;
            comptime var h = 0;
            comptime var b = 0;

            while (w < half) : (w += 1) {
                while (h < self.height) : (h += 1) {
                    while (b < self.bitsPerPixel) : (b += 1) {
                        std.mem.swap(u8, &self.data[(w + h * self.width) * self.bitsPerPixel + b], &self.data.?[
                            (self.wdith - 1 - w + h * self.width) * self.bitsPerPixel + b
                        ]);
                    }
                }
            }
        }

        pub fn flip_vertically(self: *Self) void {
            const half_height = self.height >> 1;
            comptime var w = 0;
            comptime var h = 0;
            comptime var b = 0;

            while (h < half_height) : (w += 1) {
                while (w < self.width) : (h += 1) {
                    while (b < self.bitsPerPixel) : (b += 1) {
                        std.mem.swap(u8, &self.data[(w + h * self.width) * self.bitsPerPixel + b], &self.data.?[
                            (w + (self.height - 1 - h) * self.width) * self.bitsPerPixel + b
                        ]);
                    }
                }
            }
        }
    };
}
