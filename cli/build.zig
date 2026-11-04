const std = @import("std");
const zon = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = b.option(bool, "strip", "Rimuove i simboli di debug (binari di rilascio)"),
    });
    // versione dal progetto (build.zig.zon) e commit di provenienza, per riconoscere il binario in uso
    const options = b.addOptions();
    options.addOption([]const u8, "version", zon.version);
    const described: []const u8 = b.option([]const u8, "commit", "Commit di provenienza (default: git describe)") orelse switch (b.runFallible(&.{ "git", "describe", "--always", "--dirty" }, .{ .stderr_behavior = .ignore })) {
        .success => |out| out,
        else => "unknown",
    };
    options.addOption([]const u8, "commit", std.mem.trim(u8, described, " \r\n"));
    mod.addImport("build_options", options.createModule());

    const exe = b.addExecutable(.{ .name = "wk", .root_module = mod });
    b.installArtifact(exe);

    const tests = b.addTest(.{ .root_module = mod });
    b.step("test", "Esegue i test").dependOn(&b.addRunArtifact(tests).step);
}
