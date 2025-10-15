const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const builtin = @import("builtin");
const part = @import("particle.zig");
const cfg = @import("config.zig");
const img = @import("imgui.zig");
const rules = @import("rules.zig");
const quad = @import("quad.zig");

const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});

pub fn main() !void {
    cfg.colors = cfg.customColors();
    cfg.rules = rules.ruleMatrix(true, true);
    rules.printRules(cfg.rules);
    var gpa: std.heap.DebugAllocator(.{
        .safety = true,
        .thread_safe = true,
    }) = undefined;
    defer {
        if (builtin.mode == .Debug) {
            _=gpa.detectLeaks();
            _=gpa.deinit();
    }}


    const allocator = allocblk: {
        if (builtin.mode == .Debug) {
            gpa = std.heap.DebugAllocator(.{ .safety = true, .thread_safe = true, }){};
            break :allocblk gpa.allocator();
        }
        if (builtin.target.os.tag == .emscripten)
            break :allocblk std.heap.c_allocator
        else
            break :allocblk std.heap.smp_allocator;
        };

    // defer {
    //     const leaked = smp.deinit();
    //     if (leaked == .leak) {
    //         std.debug.print("LEAKY PROGRAM\n", .{});
    //     }
    // }
    // gpa.setRequestedMemoryLimit(8000000);
    // const allocator = smp.allocator();
    // var buffer: [80000000]u8 = undefined;
    // var fbuffer = std.heap.FixedBufferAllocator.init(&buffer);
    // const allocator = fbuffer.threadSafeAllocator();

    rl.initWindow(cfg.screenWidth, cfg.screenHeight, "Particle Simulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    rl.setWindowState(rl.ConfigFlags{ .window_resizable = true });

    c.rlImGuiSetup(true);
    defer c.rlImGuiShutdown();

    z.initNoContext(allocator);
    defer z.deinitNoContext();
    const imgui_width: f32 = cfg.screenWidth / 2;
    const imgui_height: f32 = cfg.screenHeight / 3;
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = imgui_width, .h = imgui_height });

    var particles = try part.initParticles(allocator, cfg.initialParticles);
    defer particles.deinit();
    var quadTree: quad.Quad(part.particle, cfg.quadSplitLimit) = undefined;
    // defer quadTree.deinit();

    const buf = try allocator.allocSentinel(u8, 128, 0);
    std.mem.copyForwards(u8, buf, "Absolute File Path" ++ .{0});
    defer allocator.free(buf);
    const pool = try allocator.alloc(std.Thread, cfg.numThreads);
    var particleArrs: [cfg.numThreads]std.ArrayList(part.particle) = undefined;
    for (0..cfg.numThreads) |i|
        particleArrs[i] = try std.ArrayList(part.particle).initCapacity(allocator, comptime @divFloor(cfg.particleMax, cfg.numThreads) + cfg.numThreads);
    var particleArrEMCC = try std.ArrayList(part.particle).initCapacity(allocator, cfg.particleMax);
    defer allocator.free(pool);

    while (!rl.windowShouldClose()) {
        if (particles.items.len < cfg.particleCount) {
            for (0..@intCast(cfg.particleCount - @as(i32, @intCast(particles.items.len)))) |_| {
                _ = cfg.particleCount;
                try particles.append(part.createParticle());
            }
        }

        if (particles.items.len > cfg.particleCount) {
            particles.shrinkRetainingCapacity(@intCast(cfg.particleCount));
        }


        quadTree = try quad.Quad(part.particle, cfg.quadSplitLimit).init(allocator,
                .{ .x = 0, .y = 0 },
                .{ .x = rl.getScreenWidth(), .y = rl.getScreenHeight()});
        // defer quadTree.deinit();
        for (particles.items) |p| try quadTree.insert(.{ .pos = p.pos, .data = p});

        rl.beginDrawing();
        defer rl.endDrawing();
        if (rl.isKeyPressed(rl.KeyboardKey.q)) {
            quadTree.deinit();
            break;
        }
        rl.clearBackground(rl.getColor(0x1E1E2EFF));

        if (builtin.target.os.tag != .emscripten) {
            for (pool, 0..) |*thread, i| {
                thread.* = try std.Thread.spawn(.{}, part.updateVelocities, .{ particles, quadTree, i, &particleArrs[i] });
            }

            for (pool) |thread|
            thread.join();
        } else {
            try part.updateVelocities(particles, quadTree, 0, &particleArrEMCC);
        }
        quadTree.deinit();


        part.updatePosition(&particles);
        part.draw(particles);
        try img.update(buf);
    }
}
