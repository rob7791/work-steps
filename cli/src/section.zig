//! Sezioni `## Titolo` di un documento markdown, operando sulle righe.
//! Le intestazioni dentro blocchi di codice (```) vengono ignorate.
const std = @import("std");
const W = @import("work.zig");
const A = std.mem.Allocator;

pub const Span = struct { start: usize, end: usize };

fn isHeading(l: []const u8) bool {
    return std.mem.startsWith(u8, l, "## ");
}

pub fn titleOf(l: []const u8) []const u8 {
    return W.trim(l[3..]);
}

pub fn find(lines: []const []const u8, title: []const u8) ?Span {
    var fence = false;
    var start: ?usize = null;
    for (lines, 0..) |l, i| {
        if (std.mem.startsWith(u8, l, "```")) fence = !fence;
        if (fence or !isHeading(l)) continue;
        if (start) |s| return .{ .start = s, .end = i };
        if (std.ascii.eqlIgnoreCase(titleOf(l), W.trim(title))) start = i;
    }
    if (start) |s| return .{ .start = s, .end = lines.len };
    return null;
}

pub fn titles(a: A, lines: []const []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var fence = false;
    for (lines) |l| {
        if (std.mem.startsWith(u8, l, "```")) fence = !fence;
        if (!fence and isHeading(l)) try out.append(a, titleOf(l));
    }
    return out.items;
}

/// Corpo della sezione senza righe vuote iniziali/finali.
pub fn body(lines: []const []const u8, sp: Span) []const []const u8 {
    var s = sp.start + 1;
    var e = sp.end;
    while (s < e and W.trim(lines[s]).len == 0) s += 1;
    while (e > s and W.trim(lines[e - 1]).len == 0) e -= 1;
    return lines[s..e];
}

/// Sostituisce il corpo (o crea la sezione in fondo). Ritorna le nuove righe.
pub fn replace(a: A, lines: []const []const u8, title: []const u8, text: []const u8) ![]const []const u8 {
    var body_lines: std.ArrayList([]const u8) = .empty;
    const t = std.mem.trimEnd(u8, text, "\r\n");
    var sp = std.mem.splitScalar(u8, t, '\n');
    while (sp.next()) |l| try body_lines.append(a, l);

    var out: std.ArrayList([]const u8) = .empty;
    if (find(lines, title)) |span| {
        try out.appendSlice(a, lines[0..span.start]);
        try out.append(a, lines[span.start]); // intestazione com'era scritta
        try out.append(a, "");
        try out.appendSlice(a, body_lines.items);
        if (span.end < lines.len) try out.append(a, "");
        try out.appendSlice(a, lines[span.end..]);
    } else {
        try out.appendSlice(a, lines);
        if (lines.len > 0 and W.trim(lines[lines.len - 1]).len != 0) try out.append(a, "");
        try out.append(a, try std.fmt.allocPrint(a, "## {s}", .{W.trim(title)}));
        try out.append(a, "");
        try out.appendSlice(a, body_lines.items);
    }
    return out.items;
}

test "sostituzione e creazione di sezioni" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const doc = [_][]const u8{ "# T", "", "## Uno", "", "vecchio", "", "## Due", "x", "```", "## finto", "```" };
    const r1 = try replace(a, &doc, "uno", "nuovo\nsu due righe");
    try std.testing.expectEqualStrings("nuovo", r1[4]);
    try std.testing.expectEqualStrings("## Due", r1[7]);
    const r2 = try replace(a, &doc, "Tre", "z");
    try std.testing.expectEqualStrings("## Tre", r2[r2.len - 3]);
    try std.testing.expect(find(&doc, "finto") == null);
    const sp = find(&doc, "Due").?;
    try std.testing.expectEqual(@as(usize, 4), body(&doc, sp).len);
}
