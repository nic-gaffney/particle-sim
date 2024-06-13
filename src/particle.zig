const cfg = @import("config.zig");
const std = @import("std");
const rl = @import("raylib");

/// Generate the set of rules the particles will abide by
pub fn ruleMatrix() [cfg.colorAmnt][cfg.colorAmnt]f32 {
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = std.rand.DefaultPrng.init(seed);
    var rules: [cfg.colorAmnt][cfg.colorAmnt]f32 = undefined;
    for (0..cfg.colorAmnt) |i| {
        for (0..cfg.colorAmnt) |j| {
            var val = prng.random().float(f32);
            const isNeg = prng.random().uintAtMost(u8, 1);
            if (isNeg == 1) val = 0 - val;
            rules[i][j] = val;
        }
    }
    return rules;
}

/// Prints rules generated from ruleMatrix()
pub fn printRules(rules: [cfg.colorAmnt][cfg.colorAmnt]f32) void {
    std.debug.print("\n|{s:^6}", .{"Rules"});
    for (0..cfg.colors.len) |c|
        std.debug.print("| {s:^4} ", .{colorToString(c)});

    std.debug.print("|\n", .{});
    for (rules, 0..) |row, i| {
        std.debug.print("| {s:^4} ", .{colorToString(i)});
        for (row) |col|
            std.debug.print("| {d:^4.1} ", .{col});

        std.debug.print("|\n", .{});
    }
}

/// Convert the color index to a string
pub fn colorToString(c: usize) []const u8 {
    return switch (c) {
        0 => "Red",
        1 => "Green",
        2 => "Blue",
        3 => "Yellow",
        4 => "Magenta",
        5 => "Brown",
        6 => "Orange",
        7 => "Gray",
        else => " ",
    };
}

/// Initialize a MultiArrayList of size amnt with particles created by createParticle
pub fn initParticles(allocator: std.mem.Allocator, amnt: u32) !std.MultiArrayList(particle) {
    var particles = std.MultiArrayList(particle){};
    try particles.setCapacity(allocator, cfg.particleMax);
    for (0..amnt) |_| {
        try particles.append(allocator, createParticle());
    }
    return particles;
}

/// Applies forces from the ruleset to each particle
pub fn updateVelocities(particles: std.MultiArrayList(particle), rules: [cfg.colorAmnt][cfg.colorAmnt]f32) void {
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
            if (r > 0 and r < cfg.radius) {
                const f = force(r, rules[colorList[i]][colorList[j]]);
                forceX = forceX + rx / r * f;
                forceY = forceY + ry / r * f;
            }
        }

        forceX = forceX * cfg.minDistance / cfg.radius;
        forceY = forceY * cfg.minDistance / cfg.radius;

        xvel[i] = xvel[i] * 0.95 + forceX;
        yvel[i] = yvel[i] * 0.95 + forceY;
    }
}

/// Applies the particles velocity and updates position
pub fn updatePosition(particles: std.MultiArrayList(particle)) void {
    for (particles.items(.y), particles.items(.yvel)) |*y, yvel|
        y.* = @mod(@as(i32, @intFromFloat(@round((@as(f32, @floatFromInt(y.*)) + yvel)))), cfg.screenHeight);

    for (particles.items(.x), particles.items(.xvel)) |*x, xvel|
        x.* = @mod(@as(i32, @intFromFloat(@round((@as(f32, @floatFromInt(x.*)) + xvel)))), cfg.screenWidth);
}

/// Draw the particles onto the screen using raylib
pub fn draw(particles: std.MultiArrayList(particle)) void {
    for (particles.items(.y), particles.items(.x), particles.items(.colorId)) |*y, *x, colorId|
        rl.drawRectangle(x.*, y.*, 5, 5, cfg.colors[colorId]);
}

const particle = struct {
    colorId: u32,
    x: i32,
    y: i32,
    xvel: f32,
    yvel: f32,
};

fn force(distance: f32, attraction: f32) f32 {
    const beta = cfg.minDistance / cfg.radius;
    const r: f32 = distance / cfg.radius;
    if (r < beta)
        return -(r / beta - 1.0);
    if (beta <= r and r < 1)
        return attraction * (1 - @abs(2.0 * r - 1.0 - beta) / (1.0 - beta));
    return 0;
}

pub fn createParticle() particle {
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = std.rand.DefaultPrng.init(seed);
    const x = prng.random().uintLessThan(u32, cfg.screenWidth);
    const y = prng.random().uintLessThan(u32, cfg.screenHeight);
    const color = prng.random().uintLessThan(u32, cfg.colorAmnt);
    return particle{
        .colorId = color,
        .x = @intCast(x),
        .y = @intCast(y),
        .xvel = 0,
        .yvel = 0,
    };
}
