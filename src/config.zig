const rl = @import("raylib");

pub const screenWidth = 2560;
pub const screenHeight = 1440;
pub const particleMax = 4000;
pub const initialParticles = 3000;
pub const radius = 100.0;
pub const minDistance = 20.0;
pub const colors = [_]rl.Color{
    rl.Color.red,
    rl.Color.green,
    rl.Color.blue,
    rl.Color.yellow,
    rl.Color.magenta,
    rl.Color.brown,
    rl.Color.orange,
};
pub const colorAmnt = colors.len;
