const cfg = @import("config.zig");
const std = @import("std");

/// Generate the set of rules the particles will abide by
pub fn ruleMatrix(radius: bool, speed: bool) [cfg.colorAmnt][cfg.colorAmnt]f32 {
    const seed = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
    var prng = std.Random.DefaultPrng.init(seed);
    var rules: [cfg.colorAmnt][cfg.colorAmnt]f32 = undefined;
    for (0..cfg.colorAmnt) |i| {
        for (0..cfg.colorAmnt) |j| {
            var val = prng.random().float(f32);
            const isNeg = prng.random().uintAtMost(u8, 1);
            if (isNeg == 1) val = 0 - val;
            rules[i][j] = val;
        }
        if (radius)
            cfg.radius[i] = @intCast(@abs(prng.random().intRangeAtMost(i32, cfg.minDistance+1, 100)));
        if (speed)
            cfg.speed[i] = prng.random().intRangeAtMost(i32, 1, 1000);
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

/// Loads rules from a csv
pub fn loadRules(allocator: std.mem.Allocator, absolutePath: [:0]u8) !void {
    var buffer: [256]u8 = undefined;
    const file = try std.fs.openFileAbsoluteZ(absolutePath, .{ .mode = .read_only });
    defer file.close();
    var reader = file.reader(&buffer).interface;
    for (&cfg.rules) |*row| {
        for (row) |*col| {
            const buf = try reader.takeDelimiterExclusive(',');
            defer allocator.free(buf);
            col.* = try std.fmt.parseFloat(f32, buf);
        }
        reader.toss(1);
    }
    for (&cfg.speed) |*s| {
        const buf = try reader.takeDelimiterExclusive(',');
        defer allocator.free(buf);
        s.* = try std.fmt.parseInt(i32, buf, 10);
    }
    reader.toss(1);
    for (&cfg.radius) |*r| {
        const buf = try reader.takeDelimiterExclusive(',');
        defer allocator.free(buf);
        r.* = try std.fmt.parseInt(i32, buf, 10);
    }
    reader.toss(1);
    {
        const buf = try reader.takeDelimiterExclusive(',');
        defer allocator.free(buf);
        cfg.minDistance = try std.fmt.parseInt(i32, buf, 10);
    }
    {
        const buf = try reader.takeDelimiterExclusive(',');
        defer allocator.free(buf);
        cfg.friction = try std.fmt.parseFloat(f32, buf);
    }
}

/// Save rules to a csv
pub fn saveRules(absolutePath: [:0]u8) !void {
    var buffer: [256]u8 = undefined;
    const file = try std.fs.createFileAbsoluteZ(absolutePath, .{ .read = true });
    defer file.close();
    var writer = file.writer(&buffer).interface;
    for (cfg.rules) |row| {
        for (row) |col| {
            try writer.print("{d:.3},", .{col});
        }
        _ = try writer.write("\n");
    }
    for (cfg.speed) |s| {
        try writer.print("{d},", .{s});
    }
    _ = try writer.write("\n");
    for (cfg.radius) |r| {
        try writer.print("{d:.3},", .{r});
    }
    _ = try writer.write("\n");
    try writer.print("{d:.3},", .{cfg.minDistance});
    try writer.print("{d:.3},", .{cfg.friction});
    try writer.flush();
}

/// Convert the color index to a string
pub inline fn colorToString(c: usize) []const u8 {
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

pub inline fn colorToStringZ(c: usize, comptime prepend: []const u8, comptime append: []const u8) [:0]const u8 {
    return switch (c) {
        0 => prepend ++ "Red" ++ append,
        1 => prepend ++ "Green" ++ append,
        2 => prepend ++ "Blue" ++ append,
        3 => prepend ++ "Yellow" ++ append,
        4 => prepend ++ "Magenta" ++ append,
        5 => prepend ++ "Brown" ++ append,
        6 => prepend ++ "Orange" ++ append,
        7 => prepend ++ "Gray" ++ append,
        else => " ",
    };
}
