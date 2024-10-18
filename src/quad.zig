const std = @import("std");

const Point = struct {
    x: i32,
    y: i32,
};

pub fn Node(T: type) type {
    return struct {
        pos: Point,
        data: T,
    };
}

pub fn Quad(T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        node: ?*Node(T),
        topLeft: Point,
        bottomRight: Point,
        children: [4]?*Quad(T),

        pub fn init(allocator: std.mem.Allocator, tl: Point, br: Point) Quad(T) {
            return Quad(T){
                .allocator = allocator,
                .node = null,
                .topLeft = tl,
                .bottomRight = br,
                .children = [4]?*Quad(T){ null, null, null, null },
            };
        }

        inline fn inBoundry(self: Quad(T), pos: Point) bool {
            return pos.x >= self.topLeft.x and pos.x <= self.bottomRight.x and pos.y >= self.topLeft.y and pos.y <= self.bottomRight.y;
        }

        pub fn search(self: Quad(T), p: Point) ?*Node(T) {
            if (!self.inBoundry(p)) return null;
            if (self.node) |n| return n;
            if (@divTrunc((self.topLeft.x + self.bottomRight.x), 2) >= p.x) {
                if (@divTrunc((self.topLeft.y + self.bottomRight.y), 2) >= p.y) {
                    if (self.children[0] == null)
                        return null;
                    return self.children[0].?.search(p);
                } else {
                    if (self.children[2] == null)
                        return null;
                    return self.children[2].?.search(p);
                }
            } else {
                if (@divTrunc((self.topLeft.y + self.bottomRight.y), 2) >= p.y) {
                    if (self.children[1] == null)
                        return null;
                    return self.children[1].?.search(p);
                } else {
                    if (self.children[3] == null)
                        return null;
                    return self.children[3].?.search(p);
                }
            }
        }

        pub fn insert(self: *Quad(T), data: T, pos: Point) !void {
            const node: ?*Node(T) = try self.allocator.create(Node(T));
            node.* = Node(T){ .data = data, .pos = pos };
            const nNode = node.?;
            if (!self.inBoundry(nNode.pos)) return;
            if (@abs(self.topLeft.x - self.bottomRight.x) <= 1 and @abs(self.topLeft.y - self.bottomRight.y) <= 1) {
                self.node = if (self.node == null) node else self.node;
                return;
            }
            if (@divTrunc((self.topLeft.x + self.bottomRight.x), 2) >= nNode.pos.x) {
                if (@divTrunc((self.topLeft.y + self.bottomRight.y), 2) >= nNode.pos.y) {
                    if (self.children[0] == null) {
                        self.children[0] = try self.allocator.create(Quad(T));
                        self.children[0].?.* = Quad(T).init(
                            self.allocator,
                            self.topLeft,
                            .{
                                .x = @divTrunc((self.topLeft.x + self.bottomRight.x), 2),
                                .y = @divTrunc((self.topLeft.y + self.bottomRight.y), 2),
                            },
                        );
                    }
                    try self.children[0].?.insert(node);
                } else {
                    if (self.children[2] == null) {
                        self.children[2] = try self.allocator.create(Quad(T));
                        self.children[2].?.* = Quad(T).init(
                            self.allocator,
                            .{
                                .x = self.topLeft.x,
                                .y = @divTrunc(self.topLeft.y + self.bottomRight.y, 2),
                            },
                            .{
                                .x = @divTrunc((self.topLeft.x + self.bottomRight.x), 2),
                                .y = self.bottomRight.y,
                            },
                        );
                    }
                    try self.children[2].?.insert(node);
                }
            } else {
                if (@divTrunc((self.topLeft.y + self.bottomRight.y), 2) >= nNode.pos.y) {
                    if (self.children[1] == null) {
                        self.children[1] = try self.allocator.create(Quad(T));
                        self.children[1].?.* = Quad(T).init(
                            self.allocator,
                            .{
                                .x = @divTrunc(self.topLeft.x + self.bottomRight.x, 2),
                                .y = self.topLeft.y,
                            },
                            .{
                                .x = self.bottomRight.x,
                                .y = @divTrunc((self.topLeft.y + self.bottomRight.y), 2),
                            },
                        );
                    }
                    try self.children[1].?.insert(node);
                } else {
                    if (self.children[3] == null) {
                        self.children[3] = try self.allocator.create(Quad(T));
                        self.children[3].?.* = Quad(T).init(
                            self.allocator,
                            .{
                                .x = @divTrunc((self.topLeft.x + self.bottomRight.x), 2),
                                .y = @divTrunc((self.topLeft.y + self.bottomRight.y), 2),
                            },
                            self.bottomRight,
                        );
                    }
                    try self.children[3].?.insert(node);
                }
            }
        }

        pub fn deinit(self: *Quad(T)) void {
            if (self.node) |n| self.allocator.destroy(n);
            for (self.children) |child|
                if (child) |c| {
                    c.deinit();
                    self.allocator.destroy(c);
                };
        }
    };
}
