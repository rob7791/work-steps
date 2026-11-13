//! entrypoint.md: sezione `## Current task` con campi `- **Etichetta:** valore`.
//! Un campo può proseguire su righe successive indentate. Il resto del file non viene toccato.
const std = @import("std");
const rt = @import("rt.zig");
const W = @import("work.zig");
const A = std.mem.Allocator;

pub const Field = struct { label: []const u8, value: []const u8 };

pub const Entry = struct {
    path: []const u8,
    lines: std.ArrayList([]const u8) = .empty,
    final_newline: bool = true,
    dirty: bool = false,
    /// indice della riga `## Current task` e fine (esclusa) della sezione
    cs: ?usize = null,
    ce: usize = 0,

    pub fn load(a: A, dir: []const u8) !?Entry {
        const path = try std.fs.path.join(a, &.{ dir, "entrypoint.md" });
        const data = rt.readFileAlloc(a, path, 16 * 1024 * 1024) catch |e| switch (e) {
            error.FileNotFound => return null,
            else => return e,
        };
        return try parse(a, path, data);
    }

    pub fn parse(a: A, path: []const u8, data: []const u8) !Entry {
        var e: Entry = .{ .path = path };
        e.final_newline = data.len == 0 or data[data.len - 1] == '\n';
        const body = if (data.len > 0 and e.final_newline) data[0 .. data.len - 1] else data;
        if (data.len > 0) {
            var sp = std.mem.splitScalar(u8, body, '\n');
            while (sp.next()) |l| try e.lines.append(a, l);
        }
        e.locate();
        return e;
    }

    pub fn locate(self: *Entry) void {
        self.cs = null;
        self.ce = self.lines.items.len;
        for (self.lines.items, 0..) |l, i| {
            if (!std.mem.startsWith(u8, l, "## ")) continue;
            if (self.cs == null) {
                if (std.ascii.eqlIgnoreCase(W.trim(l[3..]), "current task")) self.cs = i;
            } else {
                self.ce = i;
                break;
            }
        }
    }

    const Span = struct { start: usize, end: usize, label: []const u8, value: []const u8 };

    fn parseField(line: []const u8) ?struct { label: []const u8, value: []const u8 } {
        if (!std.mem.startsWith(u8, line, "- **")) return null;
        const rest = line[4..];
        const e = std.mem.indexOf(u8, rest, ":**") orelse return null;
        return .{ .label = rest[0..e], .value = W.trim(rest[e + 3 ..]) };
    }

    fn find(self: *const Entry, label: []const u8) ?Span {
        const cs = self.cs orelse return null;
        var i = cs + 1;
        while (i < self.ce) : (i += 1) {
            const f = parseField(self.lines.items[i]) orelse continue;
            if (!std.ascii.eqlIgnoreCase(f.label, label)) continue;
            var j = i + 1;
            while (j < self.ce) : (j += 1) {
                const s = self.lines.items[j];
                if (s.len == 0 or (s[0] != ' ' and s[0] != '\t')) break;
            }
            return .{ .start = i, .end = j, .label = f.label, .value = f.value };
        }
        return null;
    }

    pub fn get(self: *const Entry, label: []const u8) ?[]const u8 {
        return (self.find(label) orelse return null).value;
    }

    pub fn fields(self: *const Entry, a: A) ![]Field {
        var out: std.ArrayList(Field) = .empty;
        const cs = self.cs orelse return out.items;
        var i = cs + 1;
        while (i < self.ce) : (i += 1) {
            if (parseField(self.lines.items[i])) |f| try out.append(a, .{ .label = f.label, .value = f.value });
        }
        return out.items;
    }

    fn splice(self: *Entry, a: A, start: usize, end: usize, new: []const []const u8) !void {
        var nl: std.ArrayList([]const u8) = .empty;
        try nl.appendSlice(a, self.lines.items[0..start]);
        try nl.appendSlice(a, new);
        try nl.appendSlice(a, self.lines.items[end..]);
        self.lines = nl;
        self.dirty = true;
        self.locate();
    }

    /// Imposta (o crea) un campo. Ritorna true se qualcosa è cambiato.
    /// Se manca viene inserito dopo `after` (se presente), altrimenti in fondo alla sezione.
    pub fn set(self: *Entry, a: A, label: []const u8, value: []const u8, after: ?[]const u8) !bool {
        if (self.cs == null) return error.NoSection;
        if (self.find(label)) |sp| {
            if (std.mem.eql(u8, sp.value, value) and sp.end == sp.start + 1) return false;
            const line = try std.fmt.allocPrint(a, "- **{s}:** {s}", .{ sp.label, value });
            try self.splice(a, sp.start, sp.end, &.{line});
            return true;
        }
        const line = try std.fmt.allocPrint(a, "- **{s}:** {s}", .{ label, value });
        var at: usize = undefined;
        if (after != null and self.find(after.?) != null) {
            at = self.find(after.?).?.end;
        } else {
            at = self.ce;
            while (at > self.cs.? + 1 and W.trim(self.lines.items[at - 1]).len == 0) at -= 1;
        }
        try self.splice(a, at, at, &.{line});
        return true;
    }

    pub fn unset(self: *Entry, a: A, label: []const u8) !bool {
        const sp = self.find(label) orelse return false;
        try self.splice(a, sp.start, sp.end, &.{});
        return true;
    }

    const version_prefix = "**Document version:**";

    /// Versione del formato dichiarata in testa al file (prima del primo `## `); null se assente.
    pub fn formatVersion(self: *const Entry) ?u32 {
        for (self.lines.items) |l| {
            if (std.mem.startsWith(u8, l, "## ")) return null;
            if (std.mem.startsWith(u8, l, version_prefix)) return std.fmt.parseInt(u32, W.trim(l[version_prefix.len..]), 10) catch null;
        }
        return null;
    }

    /// Scrive la riga `**Document version:** N` sotto il titolo (o aggiorna quella esistente).
    pub fn setFormatVersion(self: *Entry, a: A, v: u32) !void {
        const line = try std.fmt.allocPrint(a, "{s} {d}", .{ version_prefix, v });
        for (self.lines.items, 0..) |l, i| {
            if (std.mem.startsWith(u8, l, "## ")) break;
            if (std.mem.startsWith(u8, l, version_prefix)) {
                if (!std.mem.eql(u8, l, line)) {
                    self.lines.items[i] = line;
                    self.dirty = true;
                }
                return;
            }
        }
        var title: ?usize = null;
        for (self.lines.items, 0..) |l, i| {
            if (std.mem.startsWith(u8, l, "# ")) {
                title = i;
                break;
            }
        }
        var at: usize = if (title) |t| t + 1 else 0;
        if (at < self.lines.items.len and W.trim(self.lines.items[at]).len == 0) {
            at += 1;
            try self.splice(a, at, at, &.{ line, "" });
        } else {
            try self.splice(a, at, at, &.{ "", line, "" });
        }
    }

    pub fn save(self: *const Entry, a: A) !void {
        if (!self.dirty) return;
        try W.writeFileAtomic(a, self.path, self.lines.items, self.final_newline);
    }
};

test "set/get/unset campi Current task" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var e = try Entry.parse(a, "x", "# T\n\n## Current task\n\n- **File:** a\n- **Git:** uno\n  due\n- **Z:** z\n\n## Note\n\nciao\n");
    try std.testing.expectEqualStrings("a", e.get("file").?);
    try std.testing.expect(!try e.set(a, "File", "a", null));
    try std.testing.expect(try e.set(a, "Git", "nuovo", null));
    try std.testing.expect(try e.set(a, "Status", "in progress", "File"));
    try std.testing.expectEqualStrings("in progress", e.get("Status").?);
    try std.testing.expectEqualStrings("File", (try e.fields(a))[0].label);
    try std.testing.expectEqualStrings("Status", (try e.fields(a))[1].label);
    try std.testing.expect(try e.unset(a, "Z"));
    try std.testing.expectEqualStrings("## Note", e.lines.items[e.ce]);
}

test "versione documenti: lettura, inserimento, aggiornamento" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var e = try Entry.parse(a, "x", "# T\n\nintro\n\n## Current task\n\n- **File:** a\n");
    try std.testing.expect(e.formatVersion() == null);
    try e.setFormatVersion(a, 1);
    try std.testing.expectEqual(@as(u32, 1), e.formatVersion().?);
    try std.testing.expectEqualStrings("**Document version:** 1", e.lines.items[2]);
    try std.testing.expectEqualStrings("intro", e.lines.items[4]);
    try e.setFormatVersion(a, 2);
    try std.testing.expectEqual(@as(u32, 2), e.formatVersion().?);
    try std.testing.expectEqualStrings("a", e.get("File").?);
}
