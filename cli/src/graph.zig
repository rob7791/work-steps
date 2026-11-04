//! Dipendenze tra voci: stato calcolato (pronta/bloccata), alberatura, cicli, ondate.
//! Le voci si identificano per ID (globale nel work, anche tra step diversi).
//! Una dipendenza il cui ID non esiste più viene ignorata dai calcoli (la segnala `validate`).
const std = @import("std");
const W = @import("work.zig");
const A = std.mem.Allocator;

pub const Counts = struct { total: usize, done: usize };

/// Dipendenze risolvibili della voce e quante sono già completate.
pub fn counts(w: *const W.Work, it: W.Item) Counts {
    var c: Counts = .{ .total = 0, .done = 0 };
    for (it.deps) |d| {
        const r = W.findItem(w, d) orelse continue;
        c.total += 1;
        if (W.item(w, r).done) c.done += 1;
    }
    return c;
}

pub fn openDeps(a: A, w: *const W.Work, it: W.Item) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (it.deps) |d| {
        const r = W.findItem(w, d) orelse continue;
        if (!W.item(w, r).done) try out.append(a, d);
    }
    return out.items;
}

pub fn hasDep(it: W.Item, id: []const u8) bool {
    for (it.deps) |d| if (std.mem.eql(u8, d, id)) return true;
    return false;
}

/// Le voci che dipendono direttamente da `id`.
pub fn dependents(a: A, w: *const W.Work, id: []const u8) ![]W.ItemRef {
    var out: std.ArrayList(W.ItemRef) = .empty;
    for (w.steps, 0..) |s, si| for (s.items, 0..) |it, ii| {
        if (hasDep(it, id)) try out.append(a, .{ .si = si, .ii = ii });
    };
    return out.items;
}

/// Da `from` si arriva a `target` seguendo le dipendenze (cioè `from` dipende, anche indirettamente, da `target`)?
pub fn reaches(a: A, w: *const W.Work, from: []const u8, target: []const u8) !bool {
    var seen = std.StringHashMap(void).init(a);
    var stack: std.ArrayList([]const u8) = .empty;
    try stack.append(a, from);
    while (stack.pop()) |cur| {
        const r = W.findItem(w, cur) orelse continue;
        for (W.item(w, r).deps) |d| {
            if (std.mem.eql(u8, d, target)) return true;
            if (seen.contains(d)) continue;
            try seen.put(d, {});
            try stack.append(a, d);
        }
    }
    return false;
}

pub const Node = struct { ref: W.ItemRef, depth: usize, parent: ?[]const u8 };

const Walker = struct {
    a: A,
    w: *const W.Work,
    up: bool,
    max_depth: ?usize,
    only_open: bool,
    seen: std.StringHashMap(void),
    out: std.ArrayList(Node) = .empty,

    fn visit(self: *Walker, r: W.ItemRef, depth: usize, parent: ?[]const u8) !void {
        const it = W.item(self.w, r).*;
        try self.out.append(self.a, .{ .ref = r, .depth = depth, .parent = parent });
        if (it.id.len > 0) try self.seen.put(it.id, {});
        if (self.max_depth) |m| if (depth >= m) return;
        if (self.up) {
            for (it.deps) |d| {
                const cr = W.findItem(self.w, d) orelse continue;
                if (self.seen.contains(d)) continue;
                if (self.only_open and W.item(self.w, cr).done) continue;
                try self.visit(cr, depth + 1, it.id);
            }
        } else if (it.id.len > 0) {
            for (try dependents(self.a, self.w, it.id)) |cr| {
                const cit = W.item(self.w, cr).*;
                if (cit.id.len == 0 or self.seen.contains(cit.id)) continue;
                if (self.only_open and cit.done) continue;
                try self.visit(cr, depth + 1, it.id);
            }
        }
    }
};

/// Alberatura (lista piatta in preordine con profondità e genitore).
/// Con `root`: parte da lì (`up` = da cosa dipende, altrimenti chi dipende da lei).
/// Senza `root`: tutto il grafo; mostra solo voci collegate (con dipendenze o dipendenti).
pub fn walk(a: A, w: *const W.Work, root: ?W.ItemRef, up: bool, max_depth: ?usize, only_open: bool) ![]Node {
    var wk: Walker = .{ .a = a, .w = w, .up = up, .max_depth = max_depth, .only_open = only_open, .seen = std.StringHashMap(void).init(a) };
    if (root) |r| {
        try wk.visit(r, 0, null);
        return wk.out.items;
    }
    for (w.steps, 0..) |s, si| for (s.items, 0..) |it, ii| {
        if (it.id.len == 0 or wk.seen.contains(it.id)) continue;
        if (only_open and it.done) continue;
        const has_deps = counts(w, it).total > 0;
        const has_dependents = (try dependents(a, w, it.id)).len > 0;
        const is_root = if (up) (has_deps and !has_dependents) else (!has_deps and has_dependents);
        if (is_root) try wk.visit(.{ .si = si, .ii = ii }, 0, null);
    };
    return wk.out.items;
}

pub const Waves = struct { waves: [][]W.ItemRef, rest: []W.ItemRef };

/// Ondate di esecuzione delle voci aperte: la 1ª è eseguibile subito, la 2ª dopo la 1ª, ecc.
/// `rest` = voci che non entrano in nessuna ondata (cicli).
pub fn waves(a: A, w: *const W.Work) !Waves {
    var flat: std.ArrayList(W.ItemRef) = .empty;
    var idx = std.StringHashMap(usize).init(a);
    for (w.steps, 0..) |s, si| for (s.items, 0..) |it, ii| {
        if (it.done) continue;
        if (it.id.len > 0) try idx.put(it.id, flat.items.len);
        try flat.append(a, .{ .si = si, .ii = ii });
    };
    const placed = try a.alloc(bool, flat.items.len);
    @memset(placed, false);
    var result: std.ArrayList([]W.ItemRef) = .empty;
    while (true) {
        var wave: std.ArrayList(W.ItemRef) = .empty;
        for (flat.items, 0..) |r, i| {
            if (placed[i]) continue;
            var ok = true;
            for (W.item(w, r).deps) |d| {
                const j = idx.get(d) orelse continue; // completata o inesistente
                if (!placed[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) try wave.append(a, r);
        }
        if (wave.items.len == 0) break;
        for (wave.items) |r| {
            for (flat.items, 0..) |f, i| {
                if (f.si == r.si and f.ii == r.ii) placed[i] = true;
            }
        }
        try result.append(a, wave.items);
    }
    var rest: std.ArrayList(W.ItemRef) = .empty;
    for (flat.items, 0..) |r, i| if (!placed[i]) try rest.append(a, r);
    return .{ .waves = result.items, .rest = rest.items };
}

fn mkItem(id: []const u8, done: bool, deps: []const []const u8) W.Item {
    return .{ .step = 0, .line = 0, .end = 0, .done = done, .id = id, .label = id, .group = "", .tags = &.{}, .fields = &.{}, .notes = &.{}, .deps = deps };
}

test "grafo: stati, cicli, ondate" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var items = [_]W.Item{
        mkItem("a", true, &.{}),
        mkItem("b", false, &.{"a"}),
        mkItem("c", false, &.{ "a", "b" }),
        mkItem("d", false, &.{"c"}),
        mkItem("e", false, &.{}),
    };
    var steps = [_]W.Step{.{ .idx = 0, .file = "f", .path = "p", .key = "k", .items = &items }};
    const w: W.Work = .{ .dir = ".", .steps = &steps };

    const cc = counts(&w, items[2]);
    try std.testing.expectEqual(@as(usize, 2), cc.total);
    try std.testing.expectEqual(@as(usize, 1), cc.done);
    try std.testing.expect(try reaches(a, &w, "d", "a"));
    try std.testing.expect(!try reaches(a, &w, "a", "d"));

    const wv = try waves(a, &w);
    try std.testing.expectEqual(@as(usize, 3), wv.waves.len);
    try std.testing.expectEqual(@as(usize, 2), wv.waves[0].len); // b, e
    try std.testing.expectEqual(@as(usize, 0), wv.rest.len);

    const down = try walk(a, &w, .{ .si = 0, .ii = 0 }, false, null, false);
    try std.testing.expectEqual(@as(usize, 4), down.len); // a, b, c, d
    const up = try walk(a, &w, .{ .si = 0, .ii = 3 }, true, 1, false);
    try std.testing.expectEqual(@as(usize, 2), up.len); // d (0) e c (1); oltre il limite non si espande
}
