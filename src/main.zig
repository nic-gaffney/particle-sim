const std = @import("std");
const rl = @import("raylib");

const particle = struct {
    color: rl.Color,
    attrs: particleAttrs,
    x: i32,
    y: i32,
    xvel: i32,
    yvel: i32,
};

const particleAttrs = struct {};
const screenWidth = 1920;
const screenHeight = 1080;
const particleMax = 5000;

pub fn main() !void {
    rl.initWindow(screenWidth, screenHeight, "Particle Simulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var particles = try initParticles(gpa.allocator(), 1);
    defer particles.deinit(gpa.allocator());

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        if (rl.isKeyPressed(rl.KeyboardKey.key_q)) break;

        defer rl.endDrawing();

        for (particles.items(.y), particles.items(.yvel)) |*y, yvel|
            y.* = @mod((y.* + yvel), screenHeight);

        for (particles.items(.x), particles.items(.xvel)) |*x, xvel|
            x.* = @mod((x.* + xvel), screenWidth);

        for (particles.items(.y), particles.items(.x), particles.items(.color)) |*y, *x, color|
            rl.drawRectangle(x.*, y.*, 1, 1, color);

        if (particles.slice().len < particleMax) try particles.append(gpa.allocator(), createParticle(.{}));
        std.debug.print("{}\n", .{particles.slice().len});

        rl.clearBackground(rl.Color.black);
    }
}

/// Generates a particle with a random Color and Location
pub fn createParticle(attrs: particleAttrs) particle {
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = std.rand.DefaultPrng.init(seed);
    const colors = [_]rl.Color{ rl.Color.red, rl.Color.blue, rl.Color.green };
    const x = prng.random().uintLessThan(u32, screenWidth);
    const y = prng.random().uintLessThan(u32, screenHeight);
    const color = colors[prng.random().uintLessThan(u32, 3)];
    return particle{
        .color = color,
        .attrs = attrs,
        .x = @intCast(x),
        .y = @intCast(y),
        .xvel = 5,
        .yvel = -7,
    };
}

/// Initialize a MultiArrayList of size amnt with particles created by createParticle
pub fn initParticles(allocator: std.mem.Allocator, amnt: u32) !std.MultiArrayList(particle) {
    var particles = std.MultiArrayList(particle){};
    try particles.setCapacity(allocator, 10000);
    for (0..amnt) |_| {
        try particles.append(allocator, createParticle(.{}));
    }
    return particles;
}
