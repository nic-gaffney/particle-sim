# Particle Simulator
This is a simple particle simulator written in zig using [Raylib](https://www.raylib.com)
## Dependencies
- rlImgui bindings
- zgui
- raylib
## Running
Compile with `zig build --release=fast` and run with `./zig-out/bin/particle-sim`
Alternatively, just run `zig build --release=fast run`

## Known Issues
Sometimes there is a memory leak from outside zig that causes the entire program to freeze up and crash. Work in progress.
