//! Sincronizza i campi derivabili: `**Stato:**` degli step e "Current task" dell'entrypoint
//! (File, Stato, Avanzamento). I campi in prosa non vengono mai toccati.
const std = @import("std");
const W = @import("work.zig");
const E = @import("entry.zig");
const A = std.mem.Allocator;

pub const Change = struct { target: []const u8, field: []const u8, from: []const u8, to: []const u8 };

pub const Result = struct {
    current: ?[]const u8,
    entry_found: bool,
    changes: []Change,
};

fn counts(step: W.Step) struct { done: usize, total: usize } {
    var d: usize = 0;
    for (step.items) |it| if (it.done) {
        d += 1;
    };
    return .{ .done = d, .total = step.items.len };
}

/// Stato atteso: promuove e riapre, non retrocede mai e rispetta `bloccato`.
fn derive(step: W.Step) ?[]const u8 {
    const c = counts(step);
    if (c.total == 0) return null;
    const cur = step.status;
    const starts = std.ascii.startsWithIgnoreCase;
    if (c.done == c.total) return if (starts(cur, "completato")) null else "completato";
    if (starts(cur, "completato")) return "in corso";
    if (c.done > 0 and (cur.len == 0 or starts(cur, "da iniziare"))) return "in corso";
    return null;
}

/// Primo step con voci aperte; se tutti completati, l'ultimo.
pub fn currentStep(w: *const W.Work) ?usize {
    if (w.steps.len == 0) return null;
    for (w.steps, 0..) |s, i| if (counts(s).done < counts(s).total) return i;
    return w.steps.len - 1;
}

fn shortTitle(t: []const u8) []const u8 {
    // "Step 001 — Baseline" → "Baseline"
    if (std.mem.startsWith(u8, t, "Step ")) {
        if (std.mem.indexOf(u8, t, " — ")) |p| return t[p + " — ".len ..];
    }
    return t;
}

pub fn sync(a: A, w: *const W.Work, entry: *?E.Entry) !Result {
    var changes: std.ArrayList(Change) = .empty;

    for (w.steps) |*s| {
        if (derive(s.*)) |want| {
            if (s.status.len == 0) continue; // niente riga Stato: non la inventa
            const from = s.status;
            try W.setStatus(a, s, want);
            try changes.append(a, .{ .target = s.file, .field = "Stato", .from = from, .to = want });
        }
    }

    const cur = currentStep(w);
    if (entry.*) |*e| {
        if (cur) |ci| {
            const s = w.steps[ci];
            const c = counts(s);
            var tot_d: usize = 0;
            var tot_t: usize = 0;
            for (w.steps) |x| {
                tot_d += counts(x).done;
                tot_t += counts(x).total;
            }
            const file_v = try std.fmt.allocPrint(a, "[{s} — {s}]({s})", .{ s.file, shortTitle(s.title), s.file });
            const prog_v = try std.fmt.allocPrint(a, "{d}/{d} nello step, {d}/{d} nel work", .{ c.done, c.total, tot_d, tot_t });
            const stato_v = if (s.status.len > 0) s.status else "da iniziare";
            const Pair = struct { l: []const u8, v: []const u8, after: ?[]const u8 };
            const pairs = [_]Pair{
                .{ .l = "File", .v = file_v, .after = null },
                .{ .l = "Stato", .v = stato_v, .after = "File" },
                .{ .l = "Avanzamento", .v = prog_v, .after = "Stato" },
            };
            for (pairs) |p| {
                const from = e.get(p.l) orelse "";
                if (try e.set(a, p.l, p.v, p.after)) {
                    try changes.append(a, .{ .target = "entrypoint.md", .field = p.l, .from = from, .to = p.v });
                }
            }
        }
    }
    return .{
        .current = if (cur) |ci| w.steps[ci].key else null,
        .entry_found = entry.* != null and entry.*.?.cs != null,
        .changes = changes.items,
    };
}

test "derive: promuove, riapre, non retrocede" {
    var items = [_]W.Item{
        .{ .step = 0, .line = 0, .end = 0, .done = true, .id = "a", .label = "", .group = "", .tags = &.{}, .fields = &.{}, .notes = &.{} },
        .{ .step = 0, .line = 0, .end = 0, .done = false, .id = "b", .label = "", .group = "", .tags = &.{}, .fields = &.{}, .notes = &.{} },
    };
    var s: W.Step = .{ .idx = 0, .file = "f", .path = "p", .key = "k", .status = "da iniziare", .items = &items };
    try std.testing.expectEqualStrings("in corso", derive(s).?);
    s.status = "in corso";
    try std.testing.expect(derive(s) == null);
    items[1].done = true;
    try std.testing.expectEqualStrings("completato", derive(s).?);
    s.status = "completato";
    items[1].done = false;
    try std.testing.expectEqualStrings("in corso", derive(s).?);
    items[0].done = false;
    s.status = "in corso";
    try std.testing.expect(derive(s) == null);
}
