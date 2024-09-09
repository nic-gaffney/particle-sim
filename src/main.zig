const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const part = @import("particle.zig");
const cfg = @import("config.zig");
const img = @import("imgui.zig");
const rules = @import("rules.zig");

const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});

pub fn main() !void {
    cfg.colors = cfg.customColors();
    cfg.rules = rules.ruleMatrix();
    rules.printRules(cfg.rules);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    rl.initWindow(cfg.screenWidth, cfg.screenHeight, "Particle Simulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    rl.setWindowState(rl.ConfigFlags{ .window_resizable = true });

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

    const buf = try gpa.allocator().allocSentinel(u8, 128, 0);
    std.mem.copyForwards(u8, buf, "Absolute File Path" ++ .{0});
    defer gpa.allocator().free(buf);
    const pool = try gpa.allocator().alloc(std.Thread, cfg.numThreads);
    defer gpa.allocator().free(pool);

    while (!rl.windowShouldClose()) {
        if (particles.items(.x).len < cfg.particleCount) {
            for (0..@intCast(cfg.particleCount - @as(i32, @intCast(particles.items(.x).len)))) |_| {
                std.debug.print("without this print statement it breaks on arm idk why {d}\n", .{cfg.particleCount});
                try particles.append(gpa.allocator(), part.createParticle());
            }
        }

        if (particles.items(.x).len > cfg.particleCount) {
            particles.shrinkRetainingCapacity(@intCast(cfg.particleCount));
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        if (rl.isKeyPressed(rl.KeyboardKey.key_q)) break;
        rl.clearBackground(rl.getColor(0x1E1E2EFF));

        for (pool, 0..) |*thread, i|
            thread.* = try std.Thread.spawn(.{}, part.updateVelocities, .{ &particles, i });

        for (pool) |thread|
            thread.join();

        // part.updateVelocities(particles, cfg.rules);
        part.updatePosition(particles);
        part.draw(particles);
        try img.update(gpa.allocator(), buf);
    }
}
