//! Ambiente di esecuzione (Zig 0.17): l'istanza `std.Io` va passata a ogni operazione su file, tempo e
//! processi. Qui sta quella del processo, impostata in `main`, e le poche funzioni di servizio usate ovunque.
const std = @import("std");

pub var io: std.Io = undefined;

pub const Dir = std.Io.Dir;
pub const File = std.Io.File;

pub fn cwd() Dir {
    return Dir.cwd();
}

pub fn openDir(path: []const u8, opts: Dir.OpenOptions) !Dir {
    return cwd().openDir(io, path, opts);
}

pub fn readFileAlloc(a: std.mem.Allocator, path: []const u8, max: usize) ![]u8 {
    return cwd().readFileAlloc(io, path, a, .limited(max));
}

pub fn createFile(path: []const u8, opts: Dir.CreateFileOptions) !File {
    return cwd().createFile(io, path, opts);
}

pub fn rename(old: []const u8, new: []const u8) !void {
    return Dir.rename(cwd(), old, cwd(), new, io);
}

pub fn makePath(path: []const u8) !void {
    return cwd().createDirPath(io, path);
}

pub fn realpathAlloc(a: std.mem.Allocator, path: []const u8) ![]const u8 {
    return try cwd().realPathFileAlloc(io, path, a);
}

pub fn exists(path: []const u8) bool {
    cwd().access(io, path, .{}) catch return false;
    return true;
}

/// millisecondi dall'epoca Unix
pub fn nowMs() i64 {
    return @intCast(@divFloor(std.Io.Timestamp.now(io, .real).nanoseconds, std.time.ns_per_ms));
}

pub fn sleepMs(ms: u64) void {
    io.sleep(.fromMilliseconds(@intCast(ms)), .awake) catch {};
}
