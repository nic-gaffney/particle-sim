const std = @import("std");
const rl = @import("raylib");

const particle = struct {
    colorId: u32,
    attrs: particleAttrs,
    x: i32,
    y: i32,
    xvel: f32,
    yvel: f32,
};

const particleAttrs = struct {};
const screenWidth = 2560;
const screenHeight = 1440;
const particleMax = 5000;
const radius = 100.0;
const minDistance = 20.0;
const colors = [_]rl.Color{
    rl.Color.red,
    rl.Color.green,
    rl.Color.blue,
    rl.Color.yellow,
    rl.Color.magenta,
    rl.Color.brown,
    rl.Color.orange,
};
const colorAmnt = colors.len;

pub fn main() !void {
    const rules = ruleMatrix(colors.len);
    printRules(rules);

    rl.initWindow(screenWidth, screenHeight, "Particle Simulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var particles = try initParticles(gpa.allocator(), 3000);
    defer particles.deinit(gpa.allocator());

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        if (rl.isKeyPressed(rl.KeyboardKey.key_q)) break;

        defer rl.endDrawing();

        updateVelocities(particles, rules);

        for (particles.items(.y), particles.items(.yvel)) |*y, yvel|
            y.* = @mod(@as(i32, @intFromFloat(@round((@as(f32, @floatFromInt(y.*)) + yvel)))), screenHeight);

        for (particles.items(.x), particles.items(.xvel)) |*x, xvel|
            x.* = @mod(@as(i32, @intFromFloat(@round((@as(f32, @floatFromInt(x.*)) + xvel)))), screenWidth);

        for (particles.items(.y), particles.items(.x), particles.items(.colorId)) |*y, *x, colorId|
            rl.drawRectangle(x.*, y.*, 5, 5, colors[colorId]);

        rl.clearBackground(rl.Color.black);
    }
}

fn colorToString(c: usize) []const u8 {
    return switch (c) {
        0 => "R",
        1 => "G",
        2 => "Bl",
        3 => "Y",
        4 => "M",
        5 => "Br",
        6 => "O",
        else => " ",
    };
}

fn printRules(rules: [colorAmnt][colorAmnt]f32) void {
    std.debug.print("\n|{s:^6}", .{"Rules"});
    for (0..colors.len) |c|
        std.debug.print("| {s:^4} ", .{colorToString(c)});

    std.debug.print("|\n", .{});
    for (rules, 0..) |row, i| {
        std.debug.print("| {s:^4} ", .{colorToString(i)});
        for (row) |col|
            std.debug.print("| {d:^4.1} ", .{col});

        std.debug.print("|\n", .{});
    }
}

fn force(distance: f32, attraction: f32) f32 {
    const beta = minDistance / radius;
    const r: f32 = distance / radius;
    if (r < beta)
        return -(r / beta - 1.0);
    if (beta <= r and r < 1)
        return attraction * (1 - @abs(2.0 * r - 1.0 - beta) / (1.0 - beta));
    return 0;
}

fn updateVelocities(particles: std.MultiArrayList(particle), rules: [colorAmnt][colorAmnt]f32) void {
    const colorList = particles.items(.colorId);
    var xvel = particles.items(.xvel);
    var yvel = particles.items(.yvel);
    for (particles.items(.x), particles.items(.y), 0..) |x, y, i| {
        var forceX: f32 = 0.0;
        var forceY: f32 = 0.0;

        for (particles.items(.x), particles.items(.y), 0..) |x2, y2, j| {
            if (i == j) continue;
            const rx: f32 = @floatFromInt(x - x2);
            const ry: f32 = @floatFromInt(y - y2);
            var r = @sqrt(rx * rx + ry * ry);
            if (r == 0) {
                r = 0.0001;
            }
            if (r > 0 and r < radius) {
                const f = force(r, rules[colorList[i]][colorList[j]]);
                forceX = forceX + rx / r * f;
                forceY = forceY + ry / r * f;
            }
        }

        forceX = forceX * minDistance / radius;
        forceY = forceY * minDistance / radius;

        xvel[i] = xvel[i] * 0.95 + forceX;
        yvel[i] = yvel[i] * 0.95 + forceY;
    }
}

/// Generates a particle with a random Color and Location
pub fn createParticle(attrs: particleAttrs) particle {
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = std.rand.DefaultPrng.init(seed);
    const x = prng.random().uintLessThan(u32, screenWidth);
    const y = prng.random().uintLessThan(u32, screenHeight);
    const color = prng.random().uintLessThan(u32, colorAmnt);
    return particle{
        .colorId = color,
        .attrs = attrs,
        .x = @intCast(x),
        .y = @intCast(y),
        .xvel = 0,
        .yvel = 0,
    };
}

fn ruleMatrix(comptime size: u32) [size][size]f32 {
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = std.rand.DefaultPrng.init(seed);
    var rules: [size][size]f32 = undefined;
    for (0..size) |i| {
        for (0..size) |j| {
            var val = prng.random().float(f32);
            const isNeg = prng.random().uintAtMost(u8, 1);
            if (isNeg == 1) val = 0 - val;
            rules[i][j] = val;
        }
    }
    return rules;
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
