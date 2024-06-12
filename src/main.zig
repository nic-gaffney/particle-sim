const std = @import("std");
const rl = @import("raylib");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

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

pub fn main() !void {
    rl.initWindow(screenWidth, screenHeight, "Particle Simulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var particles = try initParticles(200);
    defer particles.deinit();
    defer {
        switch (gpa.deinit()) {
            std.heap.Check.leak => std.debug.print("\n\nLEAKS!!!!\n\n", .{}),
            std.heap.Check.ok => std.debug.print("No leaks :3", .{}),
        }
    }
    std.debug.print("{}\n", .{particles.items.len});

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        if (rl.isKeyPressed(rl.KeyboardKey.key_q)) break;

        defer rl.endDrawing();

        for (0..particles.items.len) |i| {
            updateParticle(&particles.items[i]);
            drawParticle(particles.items[i]);
        }

        rl.clearBackground(rl.Color.white);
    }
}

inline fn drawParticle(p: particle) void {
    rl.drawCircle(p.x, p.y, 1, p.color);
}

fn updateParticle(p: *particle) void {
    p.x = @mod((p.x + p.xvel), screenWidth);
    p.y = @mod((p.y + p.yvel), screenHeight);
}

fn createParticle(x: i32, y: i32, color: rl.Color, attrs: particleAttrs) particle {
    return particle{
        .color = color,
        .attrs = attrs,
        .x = x,
        .y = y,
        .xvel = 5,
        .yvel = -7,
    };
}

fn initParticles(amnt: u32) !std.ArrayList(particle) {
    const colors = [_]rl.Color{ rl.Color.red, rl.Color.blue, rl.Color.green };
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = std.rand.DefaultPrng.init(seed);

    var particles = std.ArrayList(particle).init(gpa.allocator());
    for (0..amnt) |_| {
        const x = prng.random().uintLessThan(u32, screenWidth);
        const y = prng.random().uintLessThan(u32, screenHeight);
        const color = colors[prng.random().uintLessThan(u32, 3)];
        try particles.append(createParticle(@intCast(x), @intCast(y), color, .{}));
    }
    return particles;
}
