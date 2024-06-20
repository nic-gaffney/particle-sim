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
            cfg.radius = 100.0;
            cfg.minDistance = 20.0;
        }
        _ = z.sliderInt("Particles", .{ .v = &cfg.particleCount, .min = 1, .max = cfg.particleMax });
        _ = z.sliderFloat("Radius", .{ .v = &cfg.radius, .min = 1, .max = 500 });
        _ = z.sliderFloat("Minimum Distance", .{ .v = &cfg.minDistance, .min = 1.0, .max = 100.0 });
    }
    if (z.collapsingHeader("Ruleset", .{ .default_open = true })) {
        _ = z.beginTable("Rules", .{
            .column = cfg.colorAmnt + 1,
            .flags = .{},
            .outer_size = .{ 0, 0 },
            .inner_width = 0,
        });
        defer z.endTable();
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
