const std = @import("std");
const rl = @import("raylib");
const part = @import("particle.zig");

pub const screenWidth = 1920;
pub const screenHeight = 1080;
pub const particleMax = 100000;
pub const initialParticles = 2000;
pub const colorAmnt = colors.len;
pub const numThreads = 16;
pub const minQuadSize = 1;
pub const quadSplitLimit = 64;
pub var leafCapacityMod: u32 = 1;
pub var particleCount: i32 = initialParticles;
pub var minDistance: i32 = 20;
pub var friction: f32 = 0.95;
pub var radius: [colorAmnt]i32 = undefined;
pub var speed: [colorAmnt]i32 = undefined;
pub var rules: [colorAmnt][colorAmnt]f32 = undefined;
pub var colors = [_]rl.Color{
    rl.Color.red,
    rl.Color.green,
    rl.Color.blue,
    rl.Color.yellow,
    rl.Color.magenta,
    rl.Color.brown,
    rl.Color.orange,
    rl.Color.gray,
};

pub fn customColors() [colorAmnt]rl.Color {
    return .{
        rl.getColor(0xF38BA8FF),
        rl.getColor(0xA6E3A1FF),
        rl.getColor(0x89B4FAFF),
        rl.getColor(0xF9E2AFFF),
        rl.getColor(0xF5C2E7FF),
        rl.getColor(0x94E2D5FF),
        rl.getColor(0xBAC2DEFF),
        rl.getColor(0xCBA6F7FF),
    };
}
