const cfg = @import("config.zig");
const std = @import("std");

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
    std.debug.print("\n| {s:^7} ", .{"Rules"});
    for (0..cfg.colors.len) |c|
        std.debug.print("| {s:^7} ", .{colorToString(c)});

    std.debug.print("|\n", .{});
    for (rules, 0..) |row, i| {
        std.debug.print("| {s:^7} ", .{colorToString(i)});
        for (row) |col|
            std.debug.print("| {d:^7.1} ", .{col});

        std.debug.print("|\n", .{});
    }
}

pub fn loadRules(allocator: std.mem.Allocator, absolutePath: [:0]u8) !void {
    const file = try std.fs.openFileAbsoluteZ(absolutePath, .{ .mode = .read_only });
    defer file.close();
    var reader = file.reader();
    for (&cfg.rules) |*row| {
        std.debug.print("Row\n", .{});
        for (row) |*col| {
            const buf = try reader.readUntilDelimiterAlloc(allocator, ',', 16);
            defer allocator.free(buf);
            col.* = try std.fmt.parseFloat(f32, buf);
        }
        try reader.skipBytes(1, .{});
    }
}

pub fn saveRules(absolutePath: [:0]u8) !void {
    const file = try std.fs.createFileAbsoluteZ(absolutePath, .{ .read = true });
    defer file.close();
    var writer = file.writer();
    for (cfg.rules) |row| {
        for (row) |col| {
            try writer.print("{d:.3},", .{col});
        }
        _ = try writer.write("\n");
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
