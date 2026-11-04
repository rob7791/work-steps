//! Modello dei work: step (tasks-*.md), checklist, voci con ID, tag e chiavi-valore.
//!
//! Formato di una voce (nella sezione `## Checklist` di un tasks-*.md):
//!
//!     - [x] k3f9 | Etichetta libera della voce
//!       - tags: backend, urgente
//!       - owner: marco
//!
//! Tutto il resto del file viene preservato byte per byte: il tool riscrive
//! soltanto le righe delle voci che modifica.
const std = @import("std");
const rt = @import("rt.zig");
const A = std.mem.Allocator;

pub const Field = struct { key: []const u8, value: []const u8 };

pub const Item = struct {
    step: usize,
    /// indice della riga `- [ ] ...`
    line: usize,
    /// fine (esclusa) delle righe appartenenti alla voce
    end: usize,
    done: bool,
    /// vuoto se la voce non ha ancora un ID
    id: []const u8,
    label: []const u8,
    group: []const u8,
    tags: []const []const u8,
    fields: []const Field,
    /// ID da cui la voce dipende (sottoelemento riservato `deps`)
    deps: []const []const u8 = &.{},
    /// sottoelementi non riconosciuti come chiave: valore (preservati)
    notes: []const []const u8,
};

pub const Step = struct {
    idx: usize,
    file: []const u8,
    path: []const u8,
    /// nome senza prefisso/estensione, es. `step-001`
    key: []const u8,
    title: []const u8 = "",
    status: []const u8 = "",
    lines: std.ArrayList([]const u8) = .empty,
    final_newline: bool = true,
    cl_start: ?usize = null,
    cl_end: usize = 0,
    items: []Item = &.{},
    dirty: bool = false,
};

pub const Work = struct {
    dir: []const u8,
    steps: []Step,
};

pub const ItemRef = struct { si: usize, ii: usize };

pub const reserved_keys = [_][]const u8{ "id", "label", "done", "step", "line", "notes", "group", "fields", "deps", "blocked_by" };

pub fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r");
}

pub fn isStepFile(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "tasks-") and std.mem.endsWith(u8, name, ".md");
}

pub fn validId(s: []const u8) bool {
    if (s.len == 0 or s.len > 32) return false;
    for (s) |c| if (!(std.ascii.isAlphanumeric(c) or c == '_' or c == '-')) return false;
    return true;
}

pub fn validKey(s: []const u8) bool {
    return validId(s);
}

pub fn isWorkDir(dir: []const u8) bool {
    var d = rt.openDir(dir, .{ .iterate = true }) catch return false;
    defer d.close(rt.io);
    var it = d.iterate();
    while (it.next(rt.io) catch return false) |e| {
        if (e.kind == .file and isStepFile(e.name)) return true;
    }
    return false;
}

fn lessStr(_: void, x: []const u8, y: []const u8) bool {
    return std.mem.lessThan(u8, x, y);
}

pub fn load(a: A, dir: []const u8) !Work {
    var names: std.ArrayList([]const u8) = .empty;
    var d = try rt.openDir(dir, .{ .iterate = true });
    defer d.close(rt.io);
    var it = d.iterate();
    while (try it.next(rt.io)) |e| {
        if (e.kind == .file and isStepFile(e.name)) try names.append(a, try a.dupe(u8, e.name));
    }
    std.mem.sort([]const u8, names.items, {}, lessStr);

    const steps = try a.alloc(Step, names.items.len);
    for (names.items, 0..) |n, i| {
        const path = try std.fs.path.join(a, &.{ dir, n });
        const data = try rt.readFileAlloc(a, path, 64 * 1024 * 1024);
        steps[i] = .{
            .idx = i,
            .file = n,
            .path = path,
            .key = n["tasks-".len .. n.len - ".md".len],
        };
        try setContent(a, &steps[i], data);
    }
    return .{ .dir = dir, .steps = steps };
}

fn setContent(a: A, step: *Step, data: []const u8) !void {
    step.final_newline = data.len == 0 or data[data.len - 1] == '\n';
    const body = if (data.len > 0 and step.final_newline) data[0 .. data.len - 1] else data;
    step.lines = .empty;
    if (data.len > 0) {
        var sp = std.mem.splitScalar(u8, body, '\n');
        while (sp.next()) |l| try step.lines.append(a, l);
    }
    try parseStep(a, step);
}

fn checkboxPrefix(line: []const u8) ?bool {
    if (std.mem.startsWith(u8, line, "- [ ] ")) return false;
    if (std.mem.startsWith(u8, line, "- [x] ") or std.mem.startsWith(u8, line, "- [X] ")) return true;
    return null;
}

pub fn splitTags(a: A, s: []const u8, out: *std.ArrayList([]const u8)) !void {
    var sp = std.mem.splitScalar(u8, s, ',');
    while (sp.next()) |t| {
        const tt = trim(t);
        if (tt.len == 0) continue;
        if (!hasTag(out.items, tt)) try out.append(a, tt);
    }
}

pub fn hasTag(tags: []const []const u8, t: []const u8) bool {
    for (tags) |x| if (std.ascii.eqlIgnoreCase(x, t)) return true;
    return false;
}

pub fn parseStep(a: A, step: *Step) !void {
    step.title = "";
    step.status = "";
    step.cl_start = null;
    step.cl_end = step.lines.items.len;
    const lines = step.lines.items;

    for (lines, 0..) |l, i| {
        if (step.title.len == 0 and std.mem.startsWith(u8, l, "# ")) step.title = trim(l[2..]);
        if (step.status.len == 0 and std.mem.startsWith(u8, l, "**Stato:**")) step.status = trim(std.mem.trimEnd(u8, trim(l["**Stato:**".len..]), "\\"));
        if (std.mem.startsWith(u8, l, "## ")) {
            if (step.cl_start == null) {
                if (std.ascii.startsWithIgnoreCase(trim(l[3..]), "checklist")) step.cl_start = i;
            } else if (step.cl_end == lines.len) {
                step.cl_end = i;
            }
        }
    }

    var items: std.ArrayList(Item) = .empty;
    if (step.cl_start) |cs| {
        var group: []const u8 = "";
        var i = cs + 1;
        while (i < step.cl_end) {
            const l = lines[i];
            if (std.mem.startsWith(u8, l, "###")) {
                group = trim(std.mem.trimStart(u8, l, "#"));
                i += 1;
                continue;
            }
            const done = checkboxPrefix(l) orelse {
                i += 1;
                continue;
            };
            const rest = trim(l[6..]);
            var id: []const u8 = "";
            var label = rest;
            if (std.mem.indexOf(u8, rest, " | ")) |p| {
                const cand = trim(rest[0..p]);
                if (validId(cand)) {
                    id = cand;
                    label = trim(rest[p + 3 ..]);
                }
            }
            var tags: std.ArrayList([]const u8) = .empty;
            var deps: std.ArrayList([]const u8) = .empty;
            var fields: std.ArrayList(Field) = .empty;
            var notes: std.ArrayList([]const u8) = .empty;
            var j = i + 1;
            while (j < step.cl_end) : (j += 1) {
                const s = lines[j];
                if (s.len == 0 or (s[0] != ' ' and s[0] != '\t') or trim(s).len == 0) break;
                const t = trim(s);
                var is_kv = false;
                if (std.mem.startsWith(u8, t, "- ")) {
                    const body = t[2..];
                    if (std.mem.indexOfScalar(u8, body, ':')) |c| {
                        const key = trim(body[0..c]);
                        const val = trim(body[c + 1 ..]);
                        if (validKey(key)) {
                            is_kv = true;
                            if (std.ascii.eqlIgnoreCase(key, "tags")) {
                                try splitTags(a, val, &tags);
                            } else if (std.ascii.eqlIgnoreCase(key, "deps")) {
                                try splitTags(a, val, &deps);
                            } else {
                                try fields.append(a, .{ .key = key, .value = val });
                            }
                        }
                    }
                }
                if (!is_kv) try notes.append(a, t);
            }
            try items.append(a, .{
                .step = step.idx,
                .line = i,
                .end = j,
                .done = done,
                .id = id,
                .label = label,
                .group = group,
                .tags = try tags.toOwnedSlice(a),
                .deps = try deps.toOwnedSlice(a),
                .fields = try fields.toOwnedSlice(a),
                .notes = try notes.toOwnedSlice(a),
            });
            i = j;
        }
    }
    step.items = try items.toOwnedSlice(a);
}

// ---------------------------------------------------------------- lookup

pub fn findItem(w: *const Work, id: []const u8) ?ItemRef {
    for (w.steps, 0..) |s, si| {
        for (s.items, 0..) |it, ii| {
            if (it.id.len > 0 and std.mem.eql(u8, it.id, id)) return .{ .si = si, .ii = ii };
        }
    }
    return null;
}

pub fn item(w: *const Work, r: ItemRef) *Item {
    return &w.steps[r.si].items[r.ii];
}

pub fn newId(a: A, w: *const Work) ![]const u8 {
    const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789";
    while (true) {
        var buf: [4]u8 = undefined;
        var rnd: [4]u8 = undefined;
        rt.io.random(&rnd);
        for (&buf, rnd) |*c, r| c.* = alphabet[r % alphabet.len];
        const id = try a.dupe(u8, &buf);
        if (findItem(w, id) == null) return id;
    }
}

/// Trova uno step da: `1`, `001`, `step-001`, `tasks-step-001.md`.
pub fn findStep(w: *const Work, q: []const u8) ?usize {
    const all_digits = q.len > 0 and blk: {
        for (q) |c| if (!std.ascii.isDigit(c)) break :blk false;
        break :blk true;
    };
    for (w.steps, 0..) |s, i| {
        if (std.mem.eql(u8, s.key, q) or std.mem.eql(u8, s.file, q)) return i;
        if (all_digits) {
            if (trailingNumber(s.key)) |n| {
                const qn = std.fmt.parseInt(u64, q, 10) catch continue;
                if (n == qn) return i;
            }
        }
    }
    return null;
}

pub fn trailingNumber(s: []const u8) ?u64 {
    var i = s.len;
    while (i > 0 and std.ascii.isDigit(s[i - 1])) i -= 1;
    if (i == s.len) return null;
    return std.fmt.parseInt(u64, s[i..], 10) catch null;
}

// ---------------------------------------------------------------- scrittura

fn headerLine(a: A, done: bool, id: []const u8, label: []const u8) ![]const u8 {
    const mark: u8 = if (done) 'x' else ' ';
    if (id.len > 0) return std.fmt.allocPrint(a, "- [{c}] {s} | {s}", .{ mark, id, label });
    return std.fmt.allocPrint(a, "- [{c}] {s}", .{ mark, label });
}

fn itemLines(a: A, it: Item, out: *std.ArrayList([]const u8)) !void {
    try out.append(a, try headerLine(a, it.done, it.id, it.label));
    if (it.tags.len > 0) {
        var b: std.ArrayList(u8) = .empty;
        try b.appendSlice(a, "  - tags: ");
        for (it.tags, 0..) |t, i| {
            if (i > 0) try b.appendSlice(a, ", ");
            try b.appendSlice(a, t);
        }
        try out.append(a, try b.toOwnedSlice(a));
    }
    if (it.deps.len > 0) {
        var b: std.ArrayList(u8) = .empty;
        try b.appendSlice(a, "  - deps: ");
        for (it.deps, 0..) |d, i| {
            if (i > 0) try b.appendSlice(a, ", ");
            try b.appendSlice(a, d);
        }
        try out.append(a, try b.toOwnedSlice(a));
    }
    for (it.fields) |f| try out.append(a, try std.fmt.allocPrint(a, "  - {s}: {s}", .{ f.key, f.value }));
    for (it.notes) |n| try out.append(a, try std.fmt.allocPrint(a, "  {s}", .{n}));
}

pub fn replaceRange(a: A, step: *Step, start: usize, end: usize, new: []const []const u8) !void {
    var nl: std.ArrayList([]const u8) = .empty;
    try nl.appendSlice(a, step.lines.items[0..start]);
    try nl.appendSlice(a, new);
    try nl.appendSlice(a, step.lines.items[end..]);
    step.lines = nl;
    step.dirty = true;
    try parseStep(a, step);
}

/// Riscrive le righe di una voce a partire dalla struttura modificata.
pub fn commitItem(a: A, w: *const Work, r: ItemRef, it: Item) !void {
    const step = &w.steps[r.si];
    const old = step.items[r.ii];
    var nl: std.ArrayList([]const u8) = .empty;
    try itemLines(a, it, &nl);
    try replaceRange(a, step, old.line, old.end, nl.items);
}

pub fn removeItem(a: A, w: *const Work, r: ItemRef) !void {
    const step = &w.steps[r.si];
    const old = step.items[r.ii];
    try replaceRange(a, step, old.line, old.end, &.{});
}

/// Inserisce una nuova voce. `after` = dopo quella voce; altrimenti in fondo alla checklist.
pub fn addItem(a: A, w: *const Work, si: usize, after: ?ItemRef, it: Item) !void {
    const step = &w.steps[si];
    var nl: std.ArrayList([]const u8) = .empty;
    const lines = step.lines.items;

    if (step.cl_start == null) {
        // nessuna sezione checklist: la crea in fondo al file
        try nl.appendSlice(a, &.{ "", "## Checklist", "" });
        try itemLines(a, it, &nl);
        const at = lines.len;
        try replaceRange(a, step, at, at, nl.items);
        return;
    }
    const cs = step.cl_start.?;
    var at: usize = undefined;
    if (after) |r| {
        at = step.items[r.ii].end;
    } else if (step.items.len > 0) {
        at = step.items[step.items.len - 1].end;
    } else {
        at = cs + 1;
        if (at >= lines.len or trim(lines[at]).len != 0) {
            try nl.append(a, "");
        } else {
            at += 1;
        }
        try itemLines(a, it, &nl);
        if (at < lines.len and trim(lines[at]).len != 0) try nl.append(a, "");
        try replaceRange(a, step, at, at, nl.items);
        return;
    }
    try itemLines(a, it, &nl);
    try replaceRange(a, step, at, at, nl.items);
}

/// Riscrive il valore di `**Stato:**` preservando il suffisso (spazi di a-capo markdown).
pub fn setStatus(a: A, step: *Step, value: []const u8) !void {
    for (step.lines.items, 0..) |l, i| {
        if (std.mem.startsWith(u8, l, "**Stato:**")) {
            const suffix = l[std.mem.trimEnd(u8, l, " \t\r\\").len..]; // spazi o `\` di a capo markdown
            step.lines.items[i] = try std.fmt.allocPrint(a, "**Stato:** {s}{s}", .{ value, suffix });
            step.status = value;
            step.dirty = true;
            return;
        }
    }
}

/// Imposta (o inserisce sotto `**Stato:**`) una riga di metadati `**Etichetta:** valore`.
pub fn setMeta(a: A, step: *Step, label: []const u8, value: []const u8) !void {
    const prefix = try std.fmt.allocPrint(a, "**{s}:**", .{label});
    const lines = step.lines.items;
    var first_h2: usize = lines.len;
    var stato: ?usize = null;
    var title: ?usize = null;
    for (lines, 0..) |l, i| {
        if (std.mem.startsWith(u8, l, "## ")) {
            first_h2 = i;
            break;
        }
        if (title == null and std.mem.startsWith(u8, l, "# ")) title = i;
        if (std.mem.startsWith(u8, l, "**Stato:**")) stato = i;
    }
    for (lines[0..first_h2], 0..) |l, i| {
        if (!std.mem.startsWith(u8, l, prefix)) continue;
        const suffix = l[std.mem.trimEnd(u8, l, " \t\r\\").len..];
        step.lines.items[i] = try std.fmt.allocPrint(a, "{s} {s}{s}", .{ prefix, value, suffix });
        step.dirty = true;
        try parseStep(a, step);
        return;
    }
    var suffix: []const u8 = "  ";
    var at: usize = undefined;
    if (stato) |si| {
        suffix = lines[si][std.mem.trimEnd(u8, lines[si], " \t\r\\").len..];
        at = si + 1;
    } else at = (title orelse 0) + 2;
    if (at > lines.len) at = lines.len;
    const line = try std.fmt.allocPrint(a, "{s} {s}{s}", .{ prefix, value, suffix });
    try replaceRange(a, step, at, at, &.{line});
}

/// Cambia il titolo mantenendo il prefisso `Step NNN — `.
pub fn setTitle(a: A, step: *Step, title: []const u8) !void {
    for (step.lines.items, 0..) |l, i| {
        if (!std.mem.startsWith(u8, l, "# ")) continue;
        const old = l[2..];
        var prefix: []const u8 = "";
        if (std.mem.startsWith(u8, old, "Step ")) {
            if (std.mem.indexOf(u8, old, " — ")) |p| prefix = old[0 .. p + " — ".len];
        }
        step.lines.items[i] = try std.fmt.allocPrint(a, "# {s}{s}", .{ prefix, title });
        step.dirty = true;
        try parseStep(a, step);
        return;
    }
}

/// Assegna gli ID mancanti. Ritorna quante voci sono state aggiornate.
pub fn assignIds(a: A, w: *const Work, only_step: ?usize, dry: bool) !usize {
    var n: usize = 0;
    for (w.steps, 0..) |*step, si| {
        if (only_step != null and only_step.? != si) continue;
        for (step.items) |*it| {
            if (it.id.len > 0) continue;
            n += 1;
            if (dry) continue;
            it.id = try newId(a, w);
            step.lines.items[it.line] = try headerLine(a, it.done, it.id, it.label);
            step.dirty = true;
        }
    }
    return n;
}

pub fn save(a: A, w: *const Work) !void {
    for (w.steps) |s| {
        if (!s.dirty) continue;
        try writeFileAtomic(a, s.path, s.lines.items, s.final_newline);
    }
}

pub fn writeFileAtomic(a: A, path: []const u8, lines: []const []const u8, final_newline: bool) !void {
    var buf: std.ArrayList(u8) = .empty;
    for (lines, 0..) |l, i| {
        if (i > 0) try buf.append(a, '\n');
        try buf.appendSlice(a, l);
    }
    if (final_newline and lines.len > 0) try buf.append(a, '\n');
    const tmp = try std.fmt.allocPrint(a, "{s}.tmp", .{path});
    {
        var f = try rt.createFile(tmp, .{ .truncate = true });
        defer f.close(rt.io);
        try f.writeStreamingAll(rt.io, buf.items);
    }
    try rt.rename(tmp, path);
}

// ---------------------------------------------------------------- test

test "parse voce con id, tag e campi" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var s: Step = .{ .idx = 0, .file = "tasks-step-001.md", .path = "x", .key = "step-001" };
    try setContent(a, &s, "# Titolo\n\n**Stato:** in corso\n\n## Checklist\n\n- [x] ab12 | Fare | cose\n  - tags: A, b ,a\n  - owner: io\n  testo libero\n- [ ] senza id\n\n## Altro\n");
    try std.testing.expectEqual(@as(usize, 2), s.items.len);
    const it = s.items[0];
    try std.testing.expect(it.done);
    try std.testing.expectEqualStrings("ab12", it.id);
    try std.testing.expectEqualStrings("Fare | cose", it.label);
    try std.testing.expectEqual(@as(usize, 2), it.tags.len);
    try std.testing.expectEqualStrings("io", it.fields[0].value);
    try std.testing.expectEqual(@as(usize, 1), it.notes.len);
    try std.testing.expectEqualStrings("", s.items[1].id);
    try std.testing.expectEqualStrings("in corso", s.status);
}
