const rl = @import("raylib");
const part = @import("particle.zig");

pub const screenWidth = 2560;
pub const screenHeight = 1440;
pub const particleMax = 4000;
pub const initialParticles = 3000;
pub var particleCount: i32 = initialParticles;
pub var radius: f32 = 100.0;
pub var minDistance: f32 = 20.0;
pub const colors = [_]rl.Color{
    rl.Color.red,
    rl.Color.green,
    rl.Color.blue,
    rl.Color.yellow,
    rl.Color.magenta,
    rl.Color.brown,
    rl.Color.orange,
    rl.Color.gray,
};
pub const colorAmnt = colors.len;
pub var rules: [colorAmnt][colorAmnt]f32 = undefined;
