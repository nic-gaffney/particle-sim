const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const rul = @import("rules.zig");
const cfg = @import("config.zig");

const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});

pub fn update(alloc: std.mem.Allocator, buf: [:0]u8) !void {
    c.rlImGuiBegin();
    defer c.rlImGuiEnd();

    z.setNextWindowCollapsed(.{ .collapsed = true, .cond = .first_use_ever });

    _ = z.begin("Configuration", .{});
    defer z.end();
    if (z.collapsingHeader("General Settings", .{ .default_open = true })) {
        if (z.button("Reset", .{})) {
            cfg.particleCount = cfg.initialParticles;
            //            cfg.radius = 100.0;
            cfg.minDistance = 20.0;
        }
        _ = z.sliderInt("Particles", .{ .v = &cfg.particleCount, .min = 1, .max = cfg.particleMax });
        _ = z.sliderFloat("Friction", .{ .v = &cfg.friction, .min = 0, .max = 1 });
        // _ = z.sliderFloat("Radius", .{ .v = &cfg.radius, .min = cfg.minDistance, .max = 500 });
        _ = z.sliderInt("Minimum Distance", .{ .v = &cfg.minDistance, .min = 1.0, .max = 500 });
    }
    if (z.collapsingHeader("Radius", .{ .default_open = true })) {
        for (&cfg.radius, 0..) |*r, i| {
            const str  = rul.colorToStringZ(i, "", " Radius");
            _ = z.sliderInt(str, .{ .v = r, .min = cfg.minDistance, .max = 500 });
        }
    }
    if (z.collapsingHeader("Speed", .{ .default_open = true })) {
        for (&cfg.speed, 0..) |*s, i| {
            const str = rul.colorToStringZ(i, "", " Speed");
            _ = z.sliderInt(str, .{ .v = s, .min = 1, .max = 1000 });
        }
    }
    if (z.collapsingHeader("Ruleset", .{ .default_open = true })) {
        _ = z.beginTable("Rules", .{
            .column = cfg.colorAmnt + 1,
            .flags = .{},
            .outer_size = .{ 0, 0 },
            .inner_width = 0,
        });
        _ = z.tableNextRow(.{});
        _ = z.tableSetColumnIndex(0);
        z.text("Rules", .{});
        for (0..cfg.colorAmnt) |i| {
            _ = z.tableNextColumn();
            z.text("{s}", .{rul.colorToString(i)});
        }

        for (&cfg.rules, 0..) |*row, i| {
            _ = z.tableNextRow(.{});
            _ = z.tableSetColumnIndex(0);
            z.text("{s}", .{rul.colorToString(i)});
            _ = z.tableNextColumn();
            for (row, 0..) |*cols, j| {
                var id: [2:0]u8 = undefined;
                id[0] = @intCast(i + 1);
                id[1] = @intCast(j + 1);
                _ = z.tableSetColumnIndex(@intCast(j + 1));
                _ = z.pushItemWidth(z.getContentRegionAvail()[0]);
                _ = z.inputFloat(&id, .{ .v = cols, .step = 0.001, .step_fast = 0.1 });
                _ = z.popItemWidth();
            }
        }
        z.endTable();
        if (z.button("Randomize", .{}))
            cfg.rules = rul.ruleMatrix(false, false);
    }
    if (z.collapsingHeader("Load / Save", .{ .default_open = true })) {
        _ = z.inputText("Save Path", .{ .buf = buf });
        if (z.button("Save", .{})) {
            const path = buf;
            _ = rul.saveRules(path) catch void;
        }
        _ = z.inputText("Load Path", .{ .buf = buf });
        if (z.button("Load", .{})) {
            const path = buf;
            _ = rul.loadRules(alloc, path) catch void;
        }
    }
}
