//! Serializzazione JSON / testo delle voci.
const std = @import("std");
const W = @import("work.zig");
const Writer = std.Io.Writer;

pub const Format = enum { json, text, ids };

pub const View = struct {
    brief: bool = false,
    /// se presente: solo questi campi (built-in o chiavi personalizzate)
    fields: ?[]const []const u8 = null,
    format: Format = .json,
    /// senza troncare i valori lunghi (opzione --full)
    full: bool = false,
};

/// Valori più lunghi di `clip_over` caratteri compaiono accorciati nella vista predefinita;
/// il testo intero si chiede con `--fields CHIAVE` oppure `--full`.
pub const clip_over: usize = 300;
const clip_keep: usize = 240;
const never_clip = [_][]const u8{ "answer", "hold", "hold_options", "hold_default" };

fn clipped(s: []const u8, key: []const u8, v: View) ?usize {
    if (v.full or s.len <= clip_over) return null;
    for (never_clip) |k| if (std.ascii.eqlIgnoreCase(k, key)) return null;
    var k: usize = clip_keep;
    while (k > 0 and (s[k] & 0xC0) == 0x80) k -= 1;
    return k;
}

/// stringa JSON, accorciata se serve, con l'indicazione di come leggerla per intero
fn clipStr(w: *Writer, s: []const u8, id: []const u8, key: []const u8, v: View) !void {
    const k = clipped(s, key, v) orelse return jstr(w, s);
    var buf: [200]u8 = undefined;
    const tail = std.fmt.bufPrint(&buf, "… [+{d} car.: wk get {s} --fields {s}]", .{ s.len - k, id, key }) catch "…";
    var tmp: [clip_over + 220]u8 = undefined;
    @memcpy(tmp[0..k], s[0..k]);
    @memcpy(tmp[k .. k + tail.len], tail);
    try jstr(w, tmp[0 .. k + tail.len]);
}

pub fn jstr(w: *Writer, s: []const u8) !void {
    try w.writeByte('"');
    for (s) |c| switch (c) {
        '"' => try w.writeAll("\\\""),
        '\\' => try w.writeAll("\\\\"),
        '\n' => try w.writeAll("\\n"),
        '\r' => try w.writeAll("\\r"),
        '\t' => try w.writeAll("\\t"),
        else => if (c < 0x20) try w.print("\\u{x:0>4}", .{c}) else try w.writeByte(c),
    };
    try w.writeByte('"');
}

fn tagsJson(w: *Writer, tags: []const []const u8) !void {
    try w.writeByte('[');
    for (tags, 0..) |t, i| {
        if (i > 0) try w.writeByte(',');
        try jstr(w, t);
    }
    try w.writeByte(']');
}

/// ID delle dipendenze ancora aperte.
fn blockedByJson(w: *Writer, wk: *const W.Work, it: W.Item) !void {
    try w.writeByte('[');
    var n: usize = 0;
    for (it.deps) |d| {
        const r = W.findItem(wk, d) orelse continue;
        if (W.item(wk, r).done) continue;
        if (n > 0) try w.writeByte(',');
        try jstr(w, d);
        n += 1;
    }
    try w.writeByte(']');
}

pub fn isBlocked(wk: *const W.Work, it: W.Item) bool {
    if (it.done) return false;
    for (it.deps) |d| {
        const r = W.findItem(wk, d) orelse continue;
        if (!W.item(wk, r).done) return true;
    }
    return false;
}

fn fieldsJson(w: *Writer, fields: []const W.Field, id: []const u8, v: View) !void {
    try w.writeByte('{');
    for (fields, 0..) |f, i| {
        if (i > 0) try w.writeByte(',');
        try jstr(w, f.key);
        try w.writeByte(':');
        try clipStr(w, f.value, id, f.key, v);
    }
    try w.writeByte('}');
}

pub fn fieldValue(it: W.Item, key: []const u8) ?[]const u8 {
    for (it.fields) |f| if (std.ascii.eqlIgnoreCase(f.key, key)) return f.value;
    return null;
}

fn builtin(w: *Writer, wk: *const W.Work, it: W.Item, name: []const u8) !bool {
    const step = wk.steps[it.step];
    if (std.mem.eql(u8, name, "id")) try jstr(w, it.id) else if (std.mem.eql(u8, name, "done")) try w.writeAll(if (it.done) "true" else "false") else if (std.mem.eql(u8, name, "label")) try jstr(w, it.label) else if (std.mem.eql(u8, name, "step")) try jstr(w, step.key) else if (std.mem.eql(u8, name, "step_title")) try jstr(w, step.title) else if (std.mem.eql(u8, name, "group")) try jstr(w, it.group) else if (std.mem.eql(u8, name, "tags")) try tagsJson(w, it.tags) else if (std.mem.eql(u8, name, "fields")) try fieldsJson(w, it.fields, it.id, .{ .full = true }) else if (std.mem.eql(u8, name, "notes")) try tagsJson(w, it.notes) else if (std.mem.eql(u8, name, "deps")) try tagsJson(w, it.deps) else if (std.mem.eql(u8, name, "blocked_by")) try blockedByJson(w, wk, it) else if (std.mem.eql(u8, name, "line")) try w.print("{d}", .{it.line + 1}) else return false;
    return true;
}

pub fn itemJson(w: *Writer, wk: *const W.Work, it: W.Item, v: View) !void {
    try w.writeByte('{');
    if (v.fields) |names| {
        for (names, 0..) |n, i| {
            if (i > 0) try w.writeByte(',');
            try jstr(w, n);
            try w.writeByte(':');
            if (!try builtin(w, wk, it, n)) {
                if (fieldValue(it, n)) |val| try jstr(w, val) else try w.writeAll("null");
            }
        }
    } else if (v.brief) {
        try w.writeAll("\"id\":");
        try jstr(w, it.id);
        try w.print(",\"done\":{s},\"label\":", .{if (it.done) "true" else "false"});
        try jstr(w, it.label);
    } else {
        const step = wk.steps[it.step];
        try w.writeAll("\"id\":");
        try jstr(w, it.id);
        try w.writeAll(",\"step\":");
        try jstr(w, step.key);
        try w.print(",\"done\":{s},\"label\":", .{if (it.done) "true" else "false"});
        try jstr(w, it.label);
        if (it.group.len > 0) {
            try w.writeAll(",\"group\":");
            try jstr(w, it.group);
        }
        try w.writeAll(",\"tags\":");
        try tagsJson(w, it.tags);
        try w.writeAll(",\"fields\":");
        try fieldsJson(w, it.fields, it.id, v);
        if (it.deps.len > 0) {
            try w.writeAll(",\"deps\":");
            try tagsJson(w, it.deps);
            if (isBlocked(wk, it)) {
                try w.writeAll(",\"blocked_by\":");
                try blockedByJson(w, wk, it);
            }
        }
        if (it.notes.len > 0) {
            try w.writeAll(",\"notes\":[");
            for (it.notes, 0..) |n, i| {
                if (i > 0) try w.writeByte(',');
                try clipStr(w, n, it.id, "notes", v);
            }
            try w.writeByte(']');
        }
    }
    try w.writeByte('}');
}

pub fn itemText(w: *Writer, wk: *const W.Work, it: W.Item, v: View) !void {
    try w.print("[{c}] {s: <5} {s}", .{ @as(u8, if (it.done) 'x' else ' '), if (it.id.len > 0) it.id else "-", it.label });
    if (v.brief) return;
    for (it.tags) |t| try w.print("  #{s}", .{t});
    for (it.fields) |f| {
        if (clipped(f.value, f.key, v)) |k| try w.print("  {s}={s}… [+{d} car.: wk get {s} --fields {s}]", .{ f.key, f.value[0..k], f.value.len - k, it.id, f.key }) else try w.print("  {s}={s}", .{ f.key, f.value });
    }
    if (it.deps.len > 0) {
        try w.writeAll("  deps=");
        for (it.deps, 0..) |d, i| try w.print("{s}{s}", .{ if (i > 0) "," else "", d });
        if (isBlocked(wk, it)) try w.writeAll(" (bloccata)");
    }
}

pub fn itemsOut(w: *Writer, wk: *const W.Work, refs: []const W.ItemRef, total: usize, v: View) !void {
    switch (v.format) {
        .json => {
            try w.print("{{\"total\":{d},\"count\":{d},\"items\":[", .{ total, refs.len });
            for (refs, 0..) |r, i| {
                if (i > 0) try w.writeByte(',');
                try itemJson(w, wk, wk.steps[r.si].items[r.ii], v);
            }
            try w.writeAll("]}\n");
        },
        .text => {
            for (refs) |r| {
                try itemText(w, wk, wk.steps[r.si].items[r.ii], v);
                try w.writeByte('\n');
            }
        },
        .ids => for (refs) |r| try w.print("{s}\n", .{wk.steps[r.si].items[r.ii].id}),
    }
}

pub fn oneOut(w: *Writer, wk: *const W.Work, r: ?W.ItemRef, v: View) !void {
    switch (v.format) {
        .json => {
            try w.writeAll("{\"item\":");
            if (r) |x| try itemJson(w, wk, wk.steps[x.si].items[x.ii], v) else try w.writeAll("null");
            try w.writeAll("}\n");
        },
        .text => if (r) |x| {
            try itemText(w, wk, wk.steps[x.si].items[x.ii], v);
            try w.writeByte('\n');
        } else try w.writeAll("(nessuna voce)\n"),
        .ids => if (r) |x| try w.print("{s}\n", .{wk.steps[x.si].items[x.ii].id}),
    }
}
