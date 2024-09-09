const cfg = @import("config.zig");
const std = @import("std");
const rl = @import("raylib");

pub const particle = struct {
    colorId: u32,
    x: i32,
    y: i32,
    xvel: f32,
    yvel: f32,
};
/// Initialize a MultiArrayList of size amnt with particles created by createParticle
pub fn initParticles(allocator: std.mem.Allocator, amnt: u32) !std.MultiArrayList(particle) {
    var particles = std.MultiArrayList(particle){};
    try particles.setCapacity(allocator, cfg.particleMax);
    for (0..amnt) |_|
        try particles.append(allocator, createParticle());

    return particles;
}

/// Applies forces from the ruleset to each particle
pub fn updateVelocities(
    particles: *std.MultiArrayList(particle),
    threadidx: u64,
) void {
    const rules = cfg.rules;
    const colorList = particles.items(.colorId);
    var xvel = particles.items(.xvel);
    var yvel = particles.items(.yvel);
    var i: usize = threadidx;
    while (i < particles.len) : (i += cfg.numThreads) {
        const p = particles.get(i);
        const radius = cfg.radius[p.colorId];
        var forceX: f32 = 0.0;
        var forceY: f32 = 0.0;

        var j: usize = threadidx;
        while (j < particles.len) : (j += 1) {
            const p2 = particles.get(j);
            if (i == j) continue;
            var check2x = p.x - rl.getScreenWidth();
            var check2y = p.y - rl.getScreenHeight();
            if (p.x < @divExact(rl.getScreenWidth(), 2)) check2x = p.x + rl.getScreenWidth();
            if (p.y < @divExact(rl.getScreenHeight(), 2)) check2y = p.y + rl.getScreenHeight();

            var distance_x: f32 = @floatFromInt(p.x - p2.x);
            var distance_y: f32 = @floatFromInt(p.y - p2.y);
            const check2rx: f32 = @floatFromInt(check2x - p2.x);
            const check2ry: f32 = @floatFromInt(check2y - p2.y);

            if (@abs(distance_x) > @abs(check2rx)) distance_x = check2rx;
            if (@abs(distance_y) > @abs(check2ry)) distance_y = check2ry;

            if (distance_x > radius or distance_y > radius) continue;

            var distance = @sqrt(distance_x * distance_x + distance_y * distance_y);

            if (distance == 0) distance = 0.0001;
            if (distance > 0 and distance < radius) {
                const f = -force(distance, radius, rules[colorList[i]][colorList[j]]);
                forceX += (distance_x / distance) * f;
                forceY += (distance_y / distance) * f;
            }
        }

        forceX = forceX * cfg.minDistance / radius;
        forceY = forceY * cfg.minDistance / radius;

        xvel[i] = xvel[i] * cfg.friction + forceX;
        yvel[i] = yvel[i] * cfg.friction + forceY;
    }
}

/// Applies the particles velocity and updates position
pub fn updatePosition(particles: std.MultiArrayList(particle)) void {
    for (
        particles.items(.colorId),
        particles.items(.y),
        particles.items(.yvel),
    ) |col, *y, yvel| // (y + yvel) % screenHeight
        y.* = @intFromFloat(@round(@as(f32, @floatFromInt(@mod(@as(i32, @intFromFloat(@round((@as(f32, @floatFromInt(y.*)) + (@as(f32, @floatFromInt(cfg.speed[col])) / 1000.0) * yvel)))), rl.getScreenHeight())))));

    for (
        particles.items(.colorId),
        particles.items(.x),
        particles.items(.xvel),
    ) |col, *x, xvel| // (y + yvel) % screenHeight
        x.* = @intFromFloat(@round(@as(f32, @floatFromInt(@mod(@as(i32, @intFromFloat(@round((@as(f32, @floatFromInt(x.*)) + (@as(f32, @floatFromInt(cfg.speed[col])) / 1000.0) * xvel)))), rl.getScreenWidth())))));
}

/// Draw the particles onto the screen using raylib
pub fn draw(particles: std.MultiArrayList(particle)) void {
    for (particles.items(.y), particles.items(.x), particles.items(.colorId)) |*y, *x, colorId|
        rl.drawRectangle(x.*, y.*, 5, 5, cfg.colors[colorId]);
}

fn force(distance: f32, radius: f32, attraction: f32) f32 {
    const beta = cfg.minDistance / radius;
    const r: f32 = distance / radius;
    if (r < beta)
        return ((beta - r) / (beta - 1.0));
    if (beta <= r and r < 1)
        return attraction * (1 - @abs(2.0 * r - 1.0 - beta) / (1.0 - beta));
    return 0;
}

pub fn createParticle() particle {
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = std.rand.DefaultPrng.init(seed);
    const x = prng.random().uintLessThan(u32, @intCast(rl.getScreenWidth()));
    const y = prng.random().uintLessThan(u32, @intCast(rl.getScreenHeight()));
    const color = prng.random().uintLessThan(u32, cfg.colorAmnt);
    return particle{
        .colorId = color,
        .x = @intCast(x),
        .y = @intCast(y),
        .xvel = 0,
        .yvel = 0,
    };
}

//TODO: Create tests
test "Force values" {
    const expect = std.testing.expect;
    const radius = 50;
    cfg.minDistance = 20;
    const belowMin = force(5.0, radius, 0.5);
    const aboveMin = force(25.0, radius, 0.5);
    try expect(aboveMin > 0);
    try expect(belowMin < 0);
}
