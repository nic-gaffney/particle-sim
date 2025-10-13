const cfg = @import("config.zig");
const std = @import("std");
const rl = @import("raylib");
const quad = @import("quad.zig");

pub const particle = struct {
    colorId: u32,
    pos: quad.Point,
    xvel: f32,
    yvel: f32,
};
/// Initialize a MultiArrayList of size amnt with particles created by createParticle
pub fn initParticles(allocator: std.mem.Allocator, amnt: u32) !std.ArrayList(particle) {
    var particles = std.ArrayList(particle).init(allocator);
    try particles.ensureTotalCapacity(cfg.particleMax);
    for (0..amnt) |_|
        try particles.append(createParticle());

    return particles;
}

/// Applies forces from the ruleset to each particle
pub fn updateVelocities(
    particles: std.ArrayList(particle),
    qtree: quad.Quad(particle, cfg.quadSplitLimit),
    threadidx: u64,
) !void {
    const rules = cfg.rules;
    var particlesInRange = std.ArrayList(particle).init(qtree.allocator);
    defer particlesInRange.deinit();
    var i = threadidx;
    while (i < particles.items.len) : (i += cfg.numThreads) {
        var p: *particle = &(particles.items[i]);
        defer particlesInRange.clearRetainingCapacity();
        const radius = cfg.radius[p.colorId];
        try qtree.radiusSearchWrapping(p.pos, @intCast(radius), &particlesInRange, rl.getScreenWidth(), rl.getScreenHeight());
        var forceX: f32 = 0.0;
        var forceY: f32 = 0.0;
        const floatRadius = @as(f32, @floatFromInt(radius));
        const floattMinDistance = @as(f32, @floatFromInt(cfg.minDistance));
        for (particlesInRange.items) |p2| {
            if (p.pos.x == p2.pos.x and p.pos.y == p2.pos.y) continue;
            const distance_x: f32 = @floatFromInt(p.pos.x - p2.pos.x);
            const distance_y: f32 = @floatFromInt(p.pos.y - p2.pos.y);
            var distance = @sqrt(distance_x * distance_x + distance_y * distance_y);
            if (distance == 0) distance = 0.01;
            const f = -force(distance, floatRadius, rules[p.colorId][p2.colorId]);
            forceX += (distance_x / distance) * f;
            forceY += (distance_y / distance) * f;
        }
        forceX = forceX * floattMinDistance / floatRadius;
        // forceX = std.math.clamp(forceX, -10.0, 10.0);
        forceY = forceY * floattMinDistance / floatRadius;
        // forceY = std.math.clamp(forceY, -10.0, 10.0);
        p.xvel *= cfg.friction ;
        p.xvel += forceX;
        p.yvel *= cfg.friction;
        p.yvel += forceY;
    }
}

/// Applies the particles velocity and updates position
pub fn updatePosition(particles: *std.ArrayList(particle)) void {
    for (particles.items) |*p| {
        const maxVel: f32 = 4096.0;
        const posYplusVel: f32 = @as(f32, @floatFromInt(p.pos.y)) + std.math.clamp(p.yvel, -maxVel, maxVel);
        const posXplusVel: f32 = @as(f32, @floatFromInt(p.pos.x)) + std.math.clamp(p.xvel, -maxVel, maxVel);
        p.pos.y = @mod(@as(i32, @intFromFloat(posYplusVel)),  rl.getScreenHeight());
        p.pos.x = @mod(@as(i32, @intFromFloat(posXplusVel)),  rl.getScreenWidth());
    }
}

/// Draw the particles onto the screen using raylib
pub fn draw(particles: std.ArrayList(particle)) void {
    for (particles.items) |p|
        rl.drawRectangle(p.pos.x, p.pos.y, 5, 5, cfg.colors[p.colorId]);
}

fn force(distance: f32, radius: f32, attraction: f32) f32 {
    const beta = @as(f32, @floatFromInt(cfg.minDistance)) / radius;
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
        .pos = .{
            .x = @intCast(x),
            .y = @intCast(y),
        },
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
