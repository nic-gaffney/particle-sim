const std = @import("std");
const cfg = @import("config.zig");

pub const Point = struct {
    x: i32,
    y: i32,
};

pub fn Node(T: type) type {
    return struct {
        pos: Point,
        data: T,
    };
}

pub fn Quad(T: type, comptime splitLimit: usize) type {
    return struct {
        allocator: std.mem.Allocator,
        nodes: ?std.ArrayList(Node(T)),
        topLeft: Point,
        bottomRight: Point,
        children: [4]?*Quad(T, splitLimit),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, tl: Point, br: Point) !Self {
            return Quad(T, splitLimit){
                .allocator = allocator,
                .nodes = try std.ArrayList(Node(T)).initCapacity(allocator, splitLimit * cfg.leafCapacityMod),
                .topLeft = tl,
                .bottomRight = br,
                .children = [4]?*Quad(T, splitLimit){ null, null, null, null },
            };
        }

        inline fn inBoundry(self: Self, pos: Point) bool {
            return pos.x >= self.topLeft.x and pos.x <= self.bottomRight.x and
                   pos.y >= self.topLeft.y and pos.y <= self.bottomRight.y;
        }

        fn isLeaf(self: Self) bool {
            return self.children[0] == null and self.children[1] == null and
                   self.children[2] == null and self.children[3] == null;
        }

        fn shouldSplit(self: Self) bool {
            if (@abs(self.topLeft.x - self.bottomRight.x) <= cfg.minQuadSize and
                @abs(self.topLeft.y - self.bottomRight.y) <= cfg.minQuadSize) {
                return false;
            }
            if (self.nodes) |nodes|
                return nodes.items.len >= cfg.quadSplitLimit;
            return false;
        }

        fn getQuadrant(self: Self, pos: Point) usize {
            const midX = @divTrunc(self.topLeft.x + self.bottomRight.x, 2);
            const midY = @divTrunc(self.topLeft.y + self.bottomRight.y, 2);

            if (pos.x <= midX) {
                if (pos.y <= midY) {
                    return 0; // Top-left
                } else {
                    return 2; // Bottom-left
                }
            } else {
                if (pos.y <= midY) {
                    return 1; // Top-right
                } else {
                    return 3; // Bottom-right
                }
            }
        }

        fn createChild(self: *Self, quadrant: usize) std.mem.Allocator.Error!void {
            const midX = @divTrunc(self.topLeft.x + self.bottomRight.x, 2);
            const midY = @divTrunc(self.topLeft.y + self.bottomRight.y, 2);
            const tl: Point = switch (quadrant) {
                0 => self.topLeft,
                1 => .{ .x = midX, .y = self.topLeft.y },
                2 => .{ .x = self.topLeft.x, .y = midY },
                3 => .{ .x = midX, .y = midY },
                else => unreachable,
            };
            const br: Point = switch (quadrant) {
                0 => .{ .x = midX, .y = midY },
                1 => .{ .x = self.bottomRight.x, .y = midY },
                2 => .{ .x = midX, .y = self.bottomRight.y },
                3 => self.bottomRight,
                else => unreachable,
            };
            self.children[quadrant] = try self.allocator.create(Self);
            self.children[quadrant].?.* = try Self.init(self.allocator, tl, br);
        }

        fn split(self: *Quad(T, splitLimit)) !void {
            if (self.nodes == null) return;
            for (0..4) |i|
                if (self.children[i] == null)
                    try self.createChild(i);
            const nodesToRedistribute = self.nodes.?.items;
            for (nodesToRedistribute) |node| {
                const quadrant = self.getQuadrant(node.pos);
                try self.children[quadrant].?.insert(node);
            }
            self.nodes = null;
        }

        pub fn insert(self: *Quad(T, splitLimit), node: Node(T)) std.mem.Allocator.Error!void {
            if (!self.inBoundry(node.pos)) return;
            if (!self.isLeaf()) {
                const quadrant = self.getQuadrant(node.pos);
                if (self.children[quadrant] == null)
                    try self.createChild(quadrant);
                try self.children[quadrant].?.insert(node);
                return;
            }
            if (self.nodes) |*nodes| {
                if (!shouldSplit(self.*)) {
                    nodes.appendBounded(node) catch {
                        cfg.leafCapacityMod += 1;
                        try nodes.ensureTotalCapacity(self.allocator, splitLimit * cfg.leafCapacityMod);
                        try nodes.appendBounded(node);
                    };
                    return;
                }
                try self.split();
                const quadrant = self.getQuadrant(node.pos);
                try self.children[quadrant].?.insert(node);
            }
        }

        pub fn search(self: Self, p: Point) ?Node(T) {
            if (!self.inBoundry(p)) return null;

            if (self.nodes) |nodes| {
                for (nodes.items) |node|
                    if (node.pos.x == p.x and node.pos.y == p.y)
                        return node;
                return null;
            }

            const quadrant = self.getQuadrant(p);
            if (self.children[quadrant]) |child|
                return child.search(p);
            return null;
        }

        pub fn radiusSearch(self: Self, center: Point, radius: u32, results: *std.ArrayList(T)) !void {
            if (!self.intersectsCircle(center, radius)) return;

            if (self.nodes) |nodes| {
                for (nodes.items) |node|
                    if (locationInRadius(center, node.pos, radius)) {
                        try results.appendBounded(node.data);
                    };
                return;
            }

            for (self.children) |child|
                if (child) |c| try c.radiusSearch(center, radius, results);

        }

        pub fn radiusSearchWrapping(
            self: Self,
            center: Point,
            radius: u32,
            results: *std.ArrayList(T),
            worldWidth: i32,
            worldHeight: i32,
        ) !void {
            try self.radiusSearch(center, radius, results);

            const radiusInt: i32 = @intCast(radius);

            const nearLeft = center.x - radiusInt < 0;
            const nearRight = center.x + radiusInt > worldWidth;
            const nearTop = center.y - radiusInt < 0;
            const nearBottom = center.y + radiusInt > worldHeight;

            if (nearLeft) {
                const wrappedCenter = Point{ .x = center.x + worldWidth, .y = center.y };
                try self.radiusSearch(wrappedCenter, radius, results);
            }
            if (nearRight) {
                const wrappedCenter = Point{ .x = center.x - worldWidth, .y = center.y };
                try self.radiusSearch(wrappedCenter, radius, results);
            }
            if (nearTop) {
                const wrappedCenter = Point{ .x = center.x, .y = center.y + worldHeight };
                try self.radiusSearch(wrappedCenter, radius, results);
            }
            if (nearBottom) {
                const wrappedCenter = Point{ .x = center.x, .y = center.y - worldHeight };
                try self.radiusSearch(wrappedCenter, radius, results);
            }

            if (nearLeft and nearTop) {
                const wrappedCenter = Point{ .x = center.x + worldWidth, .y = center.y + worldHeight };
                try self.radiusSearch(wrappedCenter, radius, results);
            }
            if (nearLeft and nearBottom) {
                const wrappedCenter = Point{ .x = center.x + worldWidth, .y = center.y - worldHeight };
                try self.radiusSearch(wrappedCenter, radius, results);
            }
            if (nearRight and nearTop) {
                const wrappedCenter = Point{ .x = center.x - worldWidth, .y = center.y + worldHeight };
                try self.radiusSearch(wrappedCenter, radius, results);
            }
            if (nearRight and nearBottom) {
                const wrappedCenter = Point{ .x = center.x - worldWidth, .y = center.y - worldHeight };
                try self.radiusSearch(wrappedCenter, radius, results);
            }
        }

        fn intersectsCircle(self: Self, center: Point, radius: u32) bool {
            const closestX = std.math.clamp(center.x, self.topLeft.x, self.bottomRight.x);
            const closestY = std.math.clamp(center.y, self.topLeft.y, self.bottomRight.y);

            const dx = center.x - closestX;
            const dy = center.y - closestY;
            const distSq = dx * dx + dy * dy;
            const radiusInt: i32 = @intCast(radius);

            return distSq <= (radiusInt * radiusInt);
        }

        fn locationInRadius(center: Point, loc: Point, radius: u32) bool {
            const dx = loc.x - center.x;
            const dy = loc.y - center.y;
            const dSquared = dx * dx + dy * dy;
            const radiusInt: i32 = @intCast(radius);
            return dSquared <= radiusInt * radiusInt;
        }

        fn inRadius(self: Self, center: Point, radius: u32) bool {
            const points: [4]Point = .{
                self.topLeft,
                Point{ .x = self.topLeft.x, .y = self.bottomRight.y }, // Bottom-left
                Point{ .x = self.bottomRight.x, .y = self.topLeft.y }, // Top-right
                self.bottomRight,
            };
            for (points) |p|
                if (locationInRadius(center, p, radius)) return true;

            return false;
        }

        fn checkRegion(self: Self, center: Point, radius: u32) bool {
            return self.inRadius(center, radius) or self.inBoundry(center);
        }

        pub fn deinit(self: *Self) void {
            if (self.nodes) |*n|
                n.deinit(self.allocator);
            for (self.children) |child| {
                if (child) |c| {
                    c.deinit();
                    self.allocator.destroy(c);
                }
            }
        }
    };
}

test "radius search" {
    const alloc = std.testing.allocator;
    const topleft: Point = .{ .x=0, .y=0 };
    const bottomright: Point = .{ .x=2560, .y=1440 };
    var quad = Quad(i32, 8).init(alloc, topleft, bottomright);
    defer quad.deinit();

    const arr: [17]i32 =      .{ 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16 };
    const points: [17]Point = .{
        .{ .x=50, .y=50, },
        .{ .x=70, .y=70, },
        .{ .x=71, .y=71, },
        .{ .x=30, .y=30, },
        .{ .x=29, .y=29, },
        .{ .x=30, .y=70, },
        .{ .x=70, .y=30 },
        .{ .x=70, .y=29, },
        .{ .x=71, .y=30, },
        .{ .x=30, .y=70 },
        .{ .x=29, .y=70 },
        .{ .x=30, .y=71, },
        .{ .x=100, .y=100, },
        .{ .x=51, .y=31, },
        .{ .x=50, .y=70 },
        .{ .x=38, .y=52 },
        .{ .x=50, .y=30 } };
    var expected: [5]i32 = .{ 16, 13, 15, 0, 14 };
    for (arr, points) |n, p| try quad.insert(.{.data= n, .pos=p});
    var out = std.ArrayList(i32).init(alloc);
    defer out.deinit();
    try quad.radiusSearch(points[0], 20, &out);
    std.mem.sort(i32, &expected, {}, comptime std.sort.asc(i32));
    std.mem.sort(i32, out.items, {}, comptime std.sort.asc(i32));
    try std.testing.expect(std.mem.eql(i32, &expected, out.items));
}

test "insertion" {
    const alloc = std.testing.allocator;
    const topleft: Point = .{ .x=0, .y=0 };
    const bottomright: Point = .{ .x=2560, .y=1440 };
    var quad = Quad(i32, 8).init(alloc, topleft, bottomright);
    defer quad.deinit();

    var arr: [15]i32 =      .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
    const points: [15]Point = .{
        .{ .x=10, .y=1, },
        .{ .x=22, .y=235, },
        .{ .x=1233, .y=1323, },
        .{ .x=4, .y=423, },
        .{ .x=53, .y=645, },
        .{ .x=6, .y=6, },
        .{ .x=7, .y=70, },
        .{ .x=8, .y=88, },
        .{ .x=129, .y=9, },
        .{ .x=102, .y=10 },
        .{ .x=121, .y=161 },
        .{ .x=12, .y=125, },
        .{ .x=132, .y=135, },
        .{ .x=142, .y=514, },
        .{ .x=215, .y=515 } };
    for (arr, points) |n, p| try quad.insert(.{.data= n, .pos=p});
    var arr_out: [15]i32 = undefined;
    for (points, 0..) |p, i| arr_out[i]=quad.search(p).?.data;
    std.mem.sort(i32, &arr, {}, comptime std.sort.asc(i32));
    std.mem.sort(i32, &arr_out, {}, comptime std.sort.asc(i32));
    try std.testing.expect(std.mem.eql(i32, &arr_out, &arr));
}
