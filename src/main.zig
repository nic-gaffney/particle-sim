const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const part = @import("particle.zig");
const cfg = @import("config.zig");
const img = @import("imgui.zig");

const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});

pub fn main() !void {
    cfg.rules = part.ruleMatrix();
    part.printRules(cfg.rules);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    rl.initWindow(cfg.screenWidth, cfg.screenHeight, "Particle Simulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    c.rlImGuiSetup(true);
    defer c.rlImGuiShutdown();

    z.initNoContext(gpa.allocator());
    defer z.deinitNoContext();
    const imgui_width: f32 = cfg.screenWidth / 2;
    const imgui_height: f32 = cfg.screenHeight / 3;
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = imgui_width, .h = imgui_height });

    var particles = try part.initParticles(gpa.allocator(), cfg.initialParticles);
    defer particles.deinit(gpa.allocator());

    while (!rl.windowShouldClose()) {
        if (particles.items(.x).len < cfg.particleCount) {
            for (0..@intCast(cfg.particleCount - @as(i32, @intCast(particles.items(.x).len)))) |_| {
                try particles.append(gpa.allocator(), part.createParticle());
            }
        }

        if (particles.items(.x).len > cfg.particleCount) {
            particles.shrinkRetainingCapacity(@intCast(cfg.particleCount));
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        if (rl.isKeyPressed(rl.KeyboardKey.key_q)) break;
        rl.clearBackground(rl.Color.black);

        part.updateVelocities(particles, cfg.rules);
        part.updatePosition(particles);
        part.draw(particles);
        try img.update();
    }
}
