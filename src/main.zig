const std = @import("std");
const rl = @import("raylib");
const part = @import("particle.zig");
const cfg = @import("config.zig");

pub fn main() !void {
    const rules = part.ruleMatrix();
    part.printRules(rules);

    rl.initWindow(cfg.screenWidth, cfg.screenHeight, "Particle Simulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var particles = try part.initParticles(gpa.allocator(), cfg.initialParticles);
    defer particles.deinit(gpa.allocator());

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        if (rl.isKeyPressed(rl.KeyboardKey.key_q)) break;

        defer rl.endDrawing();

        part.updateVelocities(particles, rules);
        part.updatePosition(particles);
        part.draw(particles);

        rl.clearBackground(rl.Color.black);
    }
}
