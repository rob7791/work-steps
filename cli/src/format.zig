//! Versione del formato dei documenti (indipendente dalla versione del tool) e migrazioni.
//! La versione sta nell'entrypoint: `**Document version:** N`. Assente = 0 (formato sperimentale
//! precedente: voci senza ID, nessun Avanzamento in Current task).
const std = @import("std");
const W = @import("work.zig");
const E = @import("entry.zig");
const S = @import("sync.zig");
const A = std.mem.Allocator;

pub const current: u32 = 1;

pub const Migration = struct { from: u32, to: u32, summary: []const u8 };

pub const migrations = [_]Migration{
    .{
        .from = 0,
        .to = 1,
        .summary = "assign IDs to checklist items, declare the document version, and synchronize step Status and Current task (File, Status, Progress). Preserve prose, notes, and other sections.",
    },
};

pub const Report = struct { from: u32, to: u32, summary: []const u8, assigned_ids: usize, sync_changes: usize };

pub fn find(from: u32) ?Migration {
    for (migrations) |m| if (m.from == from) return m;
    return null;
}

/// Applica una migrazione. Con `dry` non modifica nulla (conta solo ciò che farebbe).
pub fn apply(a: A, w: *const W.Work, entry: *E.Entry, m: Migration, dry: bool) !Report {
    var rep: Report = .{ .from = m.from, .to = m.to, .summary = m.summary, .assigned_ids = 0, .sync_changes = 0 };
    switch (m.from) {
        0 => {
            rep.assigned_ids = try W.assignIds(a, w, null, dry);
            if (!dry) {
                try entry.setFormatVersion(a, m.to);
                var eo: ?E.Entry = entry.*;
                const r = try S.sync(a, w, &eo);
                entry.* = eo.?;
                rep.sync_changes = r.changes.len;
            }
        },
        else => unreachable,
    }
    if (!dry and m.from != 0) try entry.setFormatVersion(a, m.to);
    return rep;
}
