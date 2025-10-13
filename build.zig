const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });


    const raylib_zig = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib_artifact = raylib_zig.artifact("raylib");

    const zgui = b.dependency("zgui", .{
        .shared = false,
        .with_implot = true,
    });

    const rlimgui = b.dependency("rlimgui", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "particle-sim",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .link_libcpp = true,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_zig.module("raylib") },
                .{ .name = "zgui", .module = zgui.module("root") },
            },
            .target = target,
            .optimize = optimize,
        }),
    });
    // exe.linkLibCpp();
    exe.linkLibrary(raylib_artifact);
    exe.linkLibrary(zgui.artifact("imgui"));
    exe.addIncludePath(zgui.path("libs/imgui"));


    exe.root_module.addCSourceFile(.{
        .file = rlimgui.path("rlImGui.cpp"),
        .flags = &.{
            "-fno-sanitize=undefined",
            "-std=c++11",
            "-Wno-deprecated-declarations",
            "-DNO_FONT_AWESOME",
        },
    });
    exe.addIncludePath(rlimgui.path("."));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/quad.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    //
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}
