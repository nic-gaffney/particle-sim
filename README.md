# Particle Simulator
This is a simple particle simulator written in zig using [Raylib](https://www.raylib.com)

Learn more about it on my [website](https://ngaffney.dev/portfolio/particle-sim/)
## Dependencies
- rlImgui bindings
- zgui
- raylib
## Building and Running
Compile with `zig build` and run with `./zig-out/bin/particle-sim`
Alternatively, just run `zig build run`

## Known Issues
- If you reduce the radius to be equal to or below the minimum idstance, it will crash.
