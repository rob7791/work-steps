const std = @import("std");
const rt = @import("rt.zig");
const W = @import("work.zig");
const O = @import("out.zig");
const H = @import("help.zig");
const E = @import("entry.zig");
const S = @import("sync.zig");
const G = @import("graph.zig");
const Sec = @import("section.zig");
const F = @import("format.zig");
const BO = @import("build_options");
const builtin = @import("builtin");

var g_a: std.mem.Allocator = undefined;
var g_env: *const std.process.Environ.Map = undefined;
var g_msg: []const u8 = "";
var g_warns: std.ArrayList([]const u8) = .empty;

fn warn(comptime fmt: []const u8, args: anytype) void {
    const m = std.fmt.allocPrint(g_a, fmt, args) catch return;
    g_warns.append(g_a, m) catch {};
}

const UserError = error{User};

fn fail(comptime fmt: []const u8, args: anytype) UserError {
    g_msg = std.fmt.allocPrint(g_a, fmt, args) catch "memoria esaurita";
    return error.User;
}

const Op = enum { eq, ne, contains };
const Where = struct { key: []const u8, op: Op, value: []const u8 };
const List = std.ArrayList([]const u8);

const Opts = struct {
    pos: List = .empty,
    work: ?[]const u8 = null,
    steps: List = .empty,
    tags: List = .empty,
    any_tags: List = .empty,
    has: List = .empty,
    where: std.ArrayList(Where) = .empty,
    sets: List = .empty,
    match: ?[]const u8 = null,
    sort: ?[]const u8 = null,
    fields: ?[]const u8 = null,
    format: O.Format = .json,
    label: ?[]const u8 = null,
    id: ?[]const u8 = null,
    after: ?[]const u8 = null,
    title: ?[]const u8 = null,
    limit: ?usize = null,
    desc: bool = false,
    brief: bool = false,
    open: bool = false,
    only_done: bool = false,
    dry_run: bool = false,
    force: bool = false,
    help: bool = false,
    checked: bool = false,
    no_sync: bool = false,
    count: bool = false,
    up: bool = false,
    down: bool = false,
    ready: bool = false,
    blocked: bool = false,
    no_deps: bool = false,
    has_deps: bool = false,
    delegable: bool = false,
    include_blocked: bool = false,
    depth: ?usize = null,
    deps_state: ?[]const u8 = null,
    needs: ?[]const u8 = null,
    needed_by: ?[]const u8 = null,
    mode: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    phase: ?[]const u8 = null,
    prereq: ?[]const u8 = null,
    first_step: ?[]const u8 = null,
    from: ?u32 = null,
    held: bool = false,
    claimed: bool = false,
    unclaimed: bool = false,
    any: bool = false,
    claimed_by: ?[]const u8 = null,
    result: ?[]const u8 = null,
    by: ?[]const u8 = null,
    exit_code: bool = false,
    options: List = .empty,
    default_answer: ?[]const u8 = null,
    wait_min: ?u32 = null,
    timeout: ?u32 = null,
    full: bool = false,
    long: bool = false,
    delegate: bool = false,
};

fn parseWhere(s: []const u8) !Where {
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        const c = s[i];
        if (c == '=') return .{ .key = W.trim(s[0..i]), .op = .eq, .value = W.trim(s[i + 1 ..]) };
        if (c == '~') return .{ .key = W.trim(s[0..i]), .op = .contains, .value = W.trim(s[i + 1 ..]) };
        if (c == '!' and i + 1 < s.len and s[i + 1] == '=') return .{ .key = W.trim(s[0..i]), .op = .ne, .value = W.trim(s[i + 2 ..]) };
    }
    return fail("--where '{s}': usa chiave=valore, chiave!=valore oppure chiave~valore", .{s});
}

fn parseOpts(a: std.mem.Allocator, cmd: []const u8, args: []const []const u8) !Opts {
    var o: Opts = .{};
    var i: usize = 0;
    const neg_positional = std.mem.eql(u8, cmd, "tag");
    var only_pos = false;
    while (i < args.len) : (i += 1) {
        var arg = args[i];
        if (only_pos or !std.mem.startsWith(u8, arg, "-") or arg.len == 1) {
            try o.pos.append(a, arg);
            continue;
        }
        if (std.mem.eql(u8, arg, "--")) { // da qui in poi tutto è posizionale (risposte che iniziano con '-')
            only_pos = true;
            continue;
        }
        if (neg_positional and !std.mem.startsWith(u8, arg, "--") and !std.mem.eql(u8, arg, "-h") and !std.mem.eql(u8, arg, "-w")) {
            try o.pos.append(a, arg);
            continue;
        }
        var inline_val: ?[]const u8 = null;
        if (std.mem.startsWith(u8, arg, "--")) {
            if (std.mem.indexOfScalar(u8, arg, '=')) |e| {
                inline_val = arg[e + 1 ..];
                arg = arg[0..e];
            }
        }
        const name = if (std.mem.startsWith(u8, arg, "--")) arg[2..] else if (std.mem.eql(u8, arg, "-w")) "work" else if (std.mem.eql(u8, arg, "-h")) "help" else return fail("opzione sconosciuta: {s} (vedi `wk {s} --help`)", .{ arg, cmd });

        // booleane
        if (std.mem.eql(u8, name, "desc")) { o.desc = true; continue; }
        if (std.mem.eql(u8, name, "brief")) { o.brief = true; continue; }
        if (std.mem.eql(u8, name, "full")) { o.full = true; continue; }
        if (std.mem.eql(u8, name, "delegate")) { o.delegate = true; continue; }
        if (std.mem.eql(u8, name, "long")) { o.long = true; g_long = true; continue; }
        if (std.mem.eql(u8, name, "open")) { o.open = true; continue; }
        if (std.mem.eql(u8, name, "done")) { o.only_done = true; continue; }
        if (std.mem.eql(u8, name, "dry-run")) { o.dry_run = true; continue; }
        if (std.mem.eql(u8, name, "force")) { o.force = true; continue; }
        if (std.mem.eql(u8, name, "help")) { o.help = true; continue; }
        if (std.mem.eql(u8, name, "checked")) { o.checked = true; continue; }
        if (std.mem.eql(u8, name, "no-sync")) { o.no_sync = true; continue; }
        if (std.mem.eql(u8, name, "count")) { o.count = true; continue; }
        if (std.mem.eql(u8, name, "up")) { o.up = true; continue; }
        if (std.mem.eql(u8, name, "down")) { o.down = true; continue; }
        if (std.mem.eql(u8, name, "ready")) { o.ready = true; continue; }
        if (std.mem.eql(u8, name, "blocked")) { o.blocked = true; continue; }
        if (std.mem.eql(u8, name, "no-deps")) { o.no_deps = true; continue; }
        if (std.mem.eql(u8, name, "has-deps")) { o.has_deps = true; continue; }
        if (std.mem.eql(u8, name, "delegable")) { o.delegable = true; continue; }
        if (std.mem.eql(u8, name, "include-blocked")) { o.include_blocked = true; continue; }
        if (std.mem.eql(u8, name, "held")) { o.held = true; continue; }
        if (std.mem.eql(u8, name, "claimed")) { o.claimed = true; continue; }
        if (std.mem.eql(u8, name, "unclaimed")) { o.unclaimed = true; continue; }
        if (std.mem.eql(u8, name, "any")) { o.any = true; continue; }
        if (std.mem.eql(u8, name, "exit-code")) { o.exit_code = true; continue; }

        const val: []const u8 = inline_val orelse blk: {
            i += 1;
            if (i >= args.len) return fail("--{s} richiede un valore", .{name});
            break :blk args[i];
        };
        if (std.mem.eql(u8, name, "work")) o.work = val
        else if (std.mem.eql(u8, name, "step")) try o.steps.append(a, val)
        else if (std.mem.eql(u8, name, "tag")) try W.splitTags(a, val, &o.tags)
        else if (std.mem.eql(u8, name, "any-tag")) try W.splitTags(a, val, &o.any_tags)
        else if (std.mem.eql(u8, name, "has")) try o.has.append(a, val)
        else if (std.mem.eql(u8, name, "where")) try o.where.append(a, try parseWhere(val))
        else if (std.mem.eql(u8, name, "set")) try o.sets.append(a, val)
        else if (std.mem.eql(u8, name, "match")) o.match = val
        else if (std.mem.eql(u8, name, "sort")) o.sort = val
        else if (std.mem.eql(u8, name, "fields")) o.fields = val
        else if (std.mem.eql(u8, name, "label")) o.label = val
        else if (std.mem.eql(u8, name, "id")) o.id = val
        else if (std.mem.eql(u8, name, "after")) o.after = val
        else if (std.mem.eql(u8, name, "title")) o.title = val
        else if (std.mem.eql(u8, name, "depth")) o.depth = std.fmt.parseInt(usize, val, 10) catch return fail("--depth: numero non valido '{s}'", .{val})
        else if (std.mem.eql(u8, name, "deps")) {
            if (!(std.mem.eql(u8, val, "all-done") or std.mem.eql(u8, val, "some-done") or std.mem.eql(u8, val, "none-done"))) return fail("--deps: usa all-done, some-done o none-done", .{});
            o.deps_state = val;
        } else if (std.mem.eql(u8, name, "needs")) o.needs = val
        else if (std.mem.eql(u8, name, "needed-by")) o.needed_by = val
        else if (std.mem.eql(u8, name, "mode")) {
            if (!(std.mem.eql(u8, val, "isolated") or std.mem.eql(u8, val, "integrated") or std.mem.eql(u8, val, "unset"))) return fail("--mode: usa isolated, integrated o unset", .{});
            o.mode = val;
        } else if (std.mem.eql(u8, name, "reason")) o.reason = val
        else if (std.mem.eql(u8, name, "phase")) o.phase = val
        else if (std.mem.eql(u8, name, "prereq")) o.prereq = val
        else if (std.mem.eql(u8, name, "first-step")) o.first_step = val
        else if (std.mem.eql(u8, name, "claimed-by")) o.claimed_by = val
        else if (std.mem.eql(u8, name, "result")) o.result = val
        else if (std.mem.eql(u8, name, "by")) o.by = val
        else if (std.mem.eql(u8, name, "option")) try o.options.append(a, val)
        else if (std.mem.eql(u8, name, "default")) o.default_answer = val
        else if (std.mem.eql(u8, name, "wait")) o.wait_min = std.fmt.parseInt(u32, val, 10) catch return fail("--wait: numero di minuti non valido '{s}'", .{val})
        else if (std.mem.eql(u8, name, "timeout")) o.timeout = std.fmt.parseInt(u32, val, 10) catch return fail("--timeout: numero di secondi non valido '{s}'", .{val})
        else if (std.mem.eql(u8, name, "from")) o.from = std.fmt.parseInt(u32, val, 10) catch return fail("--from: numero non valido '{s}'", .{val})
        else if (std.mem.eql(u8, name, "limit")) o.limit = std.fmt.parseInt(usize, val, 10) catch return fail("--limit: numero non valido '{s}'", .{val})
        else if (std.mem.eql(u8, name, "format")) {
            o.format = std.meta.stringToEnum(O.Format, val) orelse return fail("--format: usa json, text o ids", .{});
        } else return fail("opzione sconosciuta: --{s} (vedi `wk {s} --help`)", .{ name, cmd });
    }
    return o;
}

// ------------------------------------------------------------ work lookup

/// Variabile d'ambiente (portabile: su Windows le stringhe sono WTF-16).
fn getEnv(a: std.mem.Allocator, name: []const u8) ?[]const u8 {
    _ = a;
    return g_env.get(name);
}

fn dirExists(p: []const u8) bool {
    var d = rt.openDir(p, .{}) catch return false;
    d.close(rt.io);
    return true;
}

fn worksIn(a: std.mem.Allocator, dir: []const u8) !List {
    var res: List = .empty;
    var d = rt.openDir(dir, .{ .iterate = true }) catch return res;
    defer d.close(rt.io);
    var it = d.iterate();
    while (try it.next(rt.io)) |e| {
        if (e.kind != .directory) continue;
        const p = try std.fs.path.join(a, &.{ dir, e.name });
        if (W.isWorkDir(p)) try res.append(a, p);
    }
    std.mem.sort([]const u8, res.items, {}, struct {
        fn f(_: void, x: []const u8, y: []const u8) bool { return std.mem.lessThan(u8, x, y); }
    }.f);
    return res;
}

fn pickOne(a: std.mem.Allocator, found: List, where: []const u8) !?[]const u8 {
    if (found.items.len == 1) return found.items[0];
    if (found.items.len == 0) return null;
    var b: std.ArrayList(u8) = .empty;
    for (found.items) |p| try b.print(a, "\n  {s}", .{p});
    return fail("più work in {s}, indica quale con --work DIR:{s}", .{ where, b.items });
}

fn resolveWork(a: std.mem.Allocator, o: *const Opts) ![]const u8 {
    const explicit = o.work orelse getEnv(a, "WK_WORK");
    if (explicit) |p| {
        if (W.isWorkDir(p)) return p;
        if (try pickOne(a, try worksIn(a, p), p)) |x| return x;
        const sub = try std.fs.path.join(a, &.{ p, ".work" });
        if (try pickOne(a, try worksIn(a, sub), sub)) |x| return x;
        return fail("nessun work in '{s}' (cercati tasks-*.md). Per crearne uno: wk init DIR", .{p});
    }
    var cur: []const u8 = try rt.realpathAlloc(a, ".");
    while (true) {
        if (W.isWorkDir(cur)) return cur;
        const wd = try std.fs.path.join(a, &.{ cur, ".work" });
        if (dirExists(wd)) {
            if (try pickOne(a, try worksIn(a, wd), wd)) |x| return x;
        }
        const parent = std.fs.path.dirname(cur) orelse break;
        if (parent.len == cur.len) break;
        cur = parent;
    }
    return fail("nessun work trovato dalla directory corrente. Usa --work DIR, $WK_WORK oppure `wk init DIR`", .{});
}

/// Carica il work verificando la versione dei documenti dichiarata nell'entrypoint.
fn loadWork(a: std.mem.Allocator, o: *const Opts) !W.Work {
    const w = try loadWorkRaw(a, o);
    if (try E.Entry.load(a, w.dir)) |e| {
        const v = e.formatVersion() orelse 0;
        if (v > F.current) return fail("il work usa il formato documenti {d}, ma questo wk arriva alla {d}: aggiorna wk.", .{ v, F.current });
        if (v < F.current) warn("formato documenti {d} (wk è alla {d}): esegui `wk migrate --from {d}` prima di proseguire.", .{ v, F.current, v });
    }
    return w;
}

var g_lock = false;
/// --long: salta i limiti di lunghezza dei testi scritti
var g_long = false;

const max_field: usize = 400;
const max_label: usize = 240;
const max_question: usize = 700;

/// I testi scritti nei documenti restano brevi: i dettagli vanno in un file del repository.
fn checkLen(key: []const u8, val: []const u8, max: usize) !void {
    if (g_long or val.len <= max) return;
    return fail("'{s}' è di {d} caratteri (max {d}): sintetizza (esito, riferimento, prossimo passo). I dettagli vanno in un file del repository, qui solo il percorso (es. {s}_file=docs/…). Solo se indispensabile: --long", .{ key, val.len, max, key });
}
var g_lock_dir: ?rt.Dir = null;

/// Lock esclusivo sulla cartella del work (rilasciato all'uscita del processo): serializza le scritture
/// di più processi `wk` (es. sottoagenti in parallelo) evitando aggiornamenti persi.
fn lockWork(dir: []const u8) !void {
    if (builtin.os.tag == .windows) return; // nessun lock su Windows: evita comandi di scrittura concorrenti
    if (g_lock_dir != null) return;
    // senza `iterate` il descrittore sarebbe O_PATH, su cui flock non è ammesso
    var d = rt.openDir(dir, .{ .iterate = true }) catch return;
    var tries: usize = 0;
    while (true) : (tries += 1) {
        const got = (rt.File{ .handle = d.handle, .flags = .{ .nonblocking = false } }).tryLock(rt.io, .exclusive) catch {
            d.close(rt.io);
            return;
        };
        if (!got) {
            if (tries >= 600) {
                d.close(rt.io);
                return fail("il work è occupato da un altro comando wk (lock) da oltre 30 secondi", .{});
            }
            rt.sleepMs(50);
            continue;
        }
        break;
    }
    g_lock_dir = d;
}

fn needsLock(cmd: []const u8, o: *const Opts) bool {
    const writers = [_][]const u8{ "add", "check", "uncheck", "edit", "set", "unset", "tag", "rm", "classify", "dep", "step-set", "step-status", "new-step", "hold", "resolve", "claim", "unclaim" };
    for (writers) |x| if (std.mem.eql(u8, cmd, x)) return true;
    const sub = if (o.pos.items.len > 0) o.pos.items[0] else "";
    if (std.mem.eql(u8, cmd, "section")) return std.mem.eql(u8, sub, "set");
    if (std.mem.eql(u8, cmd, "entry")) return std.mem.eql(u8, sub, "set") or std.mem.eql(u8, sub, "unset") or (std.mem.eql(u8, sub, "slim") and !o.dry_run);
    if (std.mem.eql(u8, cmd, "auto")) return std.mem.eql(u8, sub, "start") or std.mem.eql(u8, sub, "stop");
    if (std.mem.eql(u8, cmd, "assign-ids") or std.mem.eql(u8, cmd, "migrate") or std.mem.eql(u8, cmd, "sync")) return !o.dry_run;
    return false;
}

fn loadWorkRaw(a: std.mem.Allocator, o: *const Opts) !W.Work {
    const dir = try resolveWork(a, o);
    if (g_lock) try lockWork(dir);
    return W.load(a, dir) catch |e| return fail("lettura di '{s}' fallita: {s}", .{ dir, @errorName(e) });
}

// ------------------------------------------------------------ filters

fn joinTags(a: std.mem.Allocator, tags: []const []const u8) ![]const u8 {
    var b: std.ArrayList(u8) = .empty;
    for (tags, 0..) |t, i| {
        if (i > 0) try b.appendSlice(a, ", ");
        try b.appendSlice(a, t);
    }
    return b.items;
}

/// Valore di una chiave per filtri e ordinamenti.
fn valueOf(a: std.mem.Allocator, w: *const W.Work, it: W.Item, key: []const u8) ?[]const u8 {
    if (std.ascii.eqlIgnoreCase(key, "id")) return if (it.id.len > 0) it.id else null;
    if (std.ascii.eqlIgnoreCase(key, "label")) return it.label;
    if (std.ascii.eqlIgnoreCase(key, "group")) return if (it.group.len > 0) it.group else null;
    if (std.ascii.eqlIgnoreCase(key, "step")) return w.steps[it.step].key;
    if (std.ascii.eqlIgnoreCase(key, "done")) return if (it.done) "1" else "0";
    if (std.ascii.eqlIgnoreCase(key, "tags")) return if (it.tags.len > 0) (joinTags(a, it.tags) catch null) else null;
    if (std.ascii.eqlIgnoreCase(key, "deps")) return if (it.deps.len > 0) (joinTags(a, it.deps) catch null) else null;
    return O.fieldValue(it, key);
}

fn contains(h: []const u8, n: []const u8) bool {
    return std.ascii.findIgnoreCase(h, n) != null;
}

fn passes(a: std.mem.Allocator, w: *const W.Work, it: W.Item, o: *const Opts, steps: []const usize, force_open: bool) bool {
    if (steps.len > 0) {
        var ok = false;
        for (steps) |s| if (s == it.step) { ok = true; break; };
        if (!ok) return false;
    }
    if ((o.open or force_open) and it.done) return false;
    if (o.only_done and !it.done) return false;
    for (o.tags.items) |t| if (!W.hasTag(it.tags, t)) return false;
    if (o.any_tags.items.len > 0) {
        var any = false;
        for (o.any_tags.items) |t| if (W.hasTag(it.tags, t)) { any = true; break; };
        if (!any) return false;
    }
    for (o.has.items) |k| {
        const v = valueOf(a, w, it, k) orelse return false;
        if (v.len == 0) return false;
    }
    for (o.where.items) |c| {
        if (std.ascii.eqlIgnoreCase(c.key, "tags") and c.op != .contains) {
            const has = W.hasTag(it.tags, c.value);
            if ((c.op == .eq) != has) return false;
            continue;
        }
        const v = valueOf(a, w, it, c.key);
        switch (c.op) {
            .eq => if (v == null or !std.ascii.eqlIgnoreCase(v.?, c.value)) return false,
            .ne => if (v != null and std.ascii.eqlIgnoreCase(v.?, c.value)) return false,
            .contains => if (v == null or !contains(v.?, c.value)) return false,
        }
    }
    if (o.match) |m| {
        if (!contains(it.label, m) and !contains(it.id, m)) return false;
    }
    if (o.mode) |m| {
        const v = O.fieldValue(it, "mode");
        if (std.mem.eql(u8, m, "unset")) {
            if (v != null) return false;
        } else if (v == null or !std.ascii.eqlIgnoreCase(v.?, m)) return false;
    }
    const cn = G.counts(w, it);
    const open_n = cn.total - cn.done;
    if (o.ready and (it.done or open_n != 0)) return false;
    if (o.blocked and (it.done or open_n == 0)) return false;
    if (o.no_deps and cn.total != 0) return false;
    if (o.has_deps and cn.total == 0) return false;
    if (o.deps_state) |st| {
        if (std.mem.eql(u8, st, "all-done") and !(cn.total > 0 and open_n == 0)) return false;
        if (std.mem.eql(u8, st, "some-done") and !(cn.done > 0 and open_n > 0)) return false;
        if (std.mem.eql(u8, st, "none-done") and !(cn.total > 0 and cn.done == 0)) return false;
    }
    const claim = O.fieldValue(it, "claimed_by");
    const is_held = O.fieldValue(it, "hold") != null;
    if (o.held and !is_held) return false;
    if (o.claimed and claim == null) return false;
    if (o.unclaimed and claim != null) return false;
    if (o.claimed_by) |n| {
        if (claim == null or !std.ascii.eqlIgnoreCase(claim.?, n)) return false;
    }
    if (o.delegable) {
        if (it.done or open_n != 0 or is_held or claim != null) return false;
        const v = O.fieldValue(it, "mode");
        if (v == null or !std.ascii.eqlIgnoreCase(v.?, "isolated")) return false;
    }
    if (o.needs) |id| if (!G.hasDep(it, id)) return false;
    if (o.needed_by) |id| {
        const tr = W.findItem(w, id) orelse return false;
        if (it.id.len == 0 or !G.hasDep(W.item(w, tr).*, it.id)) return false;
    }
    return true;
}

const SortCtx = struct {
    a: std.mem.Allocator,
    w: *const W.Work,
    key: []const u8,
    desc: bool,

    fn less(c: SortCtx, x: W.ItemRef, y: W.ItemRef) bool {
        const vx = valueOf(c.a, c.w, c.w.steps[x.si].items[x.ii], c.key);
        const vy = valueOf(c.a, c.w, c.w.steps[y.si].items[y.ii], c.key);
        if (vx == null and vy == null) return false;
        if (vx == null) return false;
        if (vy == null) return true;
        const fx = std.fmt.parseFloat(f64, vx.?) catch null;
        const fy = std.fmt.parseFloat(f64, vy.?) catch null;
        var lt: bool = undefined;
        var eq: bool = undefined;
        if (fx != null and fy != null) {
            lt = fx.? < fy.?;
            eq = fx.? == fy.?;
        } else {
            const ord = std.ascii.orderIgnoreCase(vx.?, vy.?);
            lt = ord == .lt;
            eq = ord == .eq;
        }
        if (eq) return false;
        return if (c.desc) !lt else lt;
    }
};

fn resolveSteps(a: std.mem.Allocator, w: *const W.Work, o: *const Opts) ![]usize {
    var res: std.ArrayList(usize) = .empty;
    for (o.steps.items) |s| {
        const i = W.findStep(w, s) orelse return fail("step '{s}' non trovato (vedi `wk steps`)", .{s});
        try res.append(a, i);
    }
    return res.items;
}

fn collect(a: std.mem.Allocator, w: *const W.Work, o: *const Opts, force_open: bool) ![]W.ItemRef {
    const steps = try resolveSteps(a, w, o);
    var refs: std.ArrayList(W.ItemRef) = .empty;
    for (w.steps, 0..) |s, si| {
        for (s.items, 0..) |it, ii| {
            if (passes(a, w, it, o, steps, force_open)) try refs.append(a, .{ .si = si, .ii = ii });
        }
    }
    if (o.sort) |k| {
        std.mem.sort(W.ItemRef, refs.items, SortCtx{ .a = a, .w = w, .key = k, .desc = o.desc }, SortCtx.less);
    } else if (o.desc) {
        std.mem.reverse(W.ItemRef, refs.items);
    }
    return refs.items;
}

fn viewOf(a: std.mem.Allocator, o: *const Opts) !O.View {
    var v: O.View = .{ .brief = o.brief, .format = o.format, .full = o.full };
    if (o.fields) |f| {
        var l: List = .empty;
        var sp = std.mem.splitScalar(u8, f, ',');
        while (sp.next()) |x| if (W.trim(x).len > 0) try l.append(a, W.trim(x));
        v.fields = l.items;
    }
    return v;
}

// ------------------------------------------------------------ comandi

const Ctx = struct { a: std.mem.Allocator, out: *std.Io.Writer };

fn needId(o: *const Opts, cmd: []const u8) ![]const u8 {
    if (o.pos.items.len < 1) return fail("manca l'ID (vedi `wk {s} --help`)", .{cmd});
    return o.pos.items[0];
}

fn needItem(w: *const W.Work, id: []const u8) !W.ItemRef {
    return W.findItem(w, id) orelse fail("voce '{s}' non trovata", .{id});
}

fn noNewline(s: []const u8, what: []const u8) !void {
    if (std.mem.indexOfAny(u8, s, "\r\n") != null) return fail("{s}: non può contenere a capo", .{what});
}

fn cmdSteps(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    var done: usize = 0;
    var total: usize = 0;
    for (w.steps) |s| {
        total += s.items.len;
        for (s.items) |it| if (it.done) { done += 1; };
    }
    const cnt = computeCounters(&w);
    const n_avail = cnt.avail;
    const n_blocked = cnt.blocked;
    const n_held = cnt.held;
    const n_claimed = cnt.claimed;
    const n_deleg = cnt.delegable;
    const out = c.out;
    if (o.format == .text) {
        for (w.steps) |s| {
            var d: usize = 0;
            for (s.items) |it| if (it.done) { d += 1; };
            try out.print("{s: <10} {d: >3}/{d: <3} {s: <12} {s}\n", .{ s.key, d, s.items.len, s.status, s.title });
        }
        try out.print("totale: {d}/{d}\ndisponibili {d} · bloccate {d} · in attesa {d} · in carico {d} · delegabili {d}\n", .{ done, total, n_avail, n_blocked, n_held, n_claimed, n_deleg });
        return;
    }
    try out.writeAll("{\"work\":");
    try O.jstr(out, w.dir);
    try out.print(",\"done\":{d},\"total\":{d},\"open\":{d},\"available\":{d},\"blocked\":{d},\"held\":{d},\"claimed\":{d},\"delegable\":{d},\"answered\":{d},\"keys\":{{", .{ done, total, total - done, n_avail, n_blocked, n_held, n_claimed, n_deleg, cnt.answered });
    const refs_all = try allRefs(c.a, &w);
    for (try keyRows(c.a, &w, refs_all), 0..) |r, i| {
        if (i > 0) try out.writeByte(',');
        try O.jstr(out, r.key);
        try out.print(":{d}", .{r.count});
    }
    try out.writeAll("},\"tags\":{");
    const trs = try tagRows(c.a, &w, refs_all);
    for (trs[0..@min(20, trs.len)], 0..) |r, i| {
        if (i > 0) try out.writeByte(',');
        try O.jstr(out, r.tag);
        try out.print(":{d}", .{r.count});
    }
    try out.writeAll("},\"steps\":[");
    for (w.steps, 0..) |s, i| {
        var d: usize = 0;
        for (s.items) |it| if (it.done) { d += 1; };
        if (i > 0) try out.writeByte(',');
        try out.writeAll("{\"key\":");
        try O.jstr(out, s.key);
        try out.writeAll(",\"file\":");
        try O.jstr(out, s.file);
        try out.writeAll(",\"title\":");
        try O.jstr(out, s.title);
        try out.writeAll(",\"status\":");
        try O.jstr(out, s.status);
        try out.print(",\"done\":{d},\"total\":{d}}}", .{ d, s.items.len });
    }
    try out.writeAll("]}\n");
}

fn cmdList(c: Ctx, o: *const Opts, next: bool) !void {
    const w = try loadWork(c.a, o);
    const refs = try collect(c.a, &w, o, next);
    const v = try viewOf(c.a, o);
    if (next) {
        var pick: ?W.ItemRef = null;
        var n_blocked: usize = 0;
        var n_held: usize = 0;
        var n_claimed: usize = 0;
        var ordered = refs;
        if (o.sort == null) { // le voci su cui l'utente ha risposto si riprendono per prime
            var pre: std.ArrayList(W.ItemRef) = .empty;
            for (refs) |r| if (O.fieldValue(W.item(&w, r).*, "answer") != null) try pre.append(c.a, r);
            for (refs) |r| if (O.fieldValue(W.item(&w, r).*, "answer") == null) try pre.append(c.a, r);
            ordered = pre.items;
        }
        for (ordered) |r| {
            const it = W.item(&w, r).*;
            const skip_blk = O.isBlocked(&w, it) and !(o.include_blocked or o.any or o.blocked);
            const skip_held = O.fieldValue(it, "hold") != null and !(o.any or o.held);
            const skip_claim = O.fieldValue(it, "claimed_by") != null and !(o.any or o.claimed or o.claimed_by != null);
            if (skip_blk or skip_held or skip_claim) {
                if (skip_blk) n_blocked += 1 else if (skip_held) n_held += 1 else n_claimed += 1;
                continue;
            }
            pick = r;
            break;
        }
        if (pick == null) {
            const reason = if (refs.len == 0) "no_open_items" else "nothing_available";
            const hint = if (n_held > 0) "wk questions" else if (n_claimed > 0) "attendi i sottoagenti (wk list --claimed)" else if (n_blocked > 0) "wk list --blocked" else "";
            switch (o.format) {
                .json => {
                    try c.out.print("{{\"item\":null,\"reason\":\"{s}\",\"open\":{d},\"blocked\":{d},\"held\":{d},\"claimed\":{d},\"hint\":", .{ reason, refs.len, n_blocked, n_held, n_claimed });
                    try O.jstr(c.out, hint);
                    try c.out.writeAll("}\n");
                },
                .text => try c.out.print("nessuna voce disponibile ({s}): aperte {d}, bloccate {d}, in attesa {d}, in carico {d}{s}{s}\n", .{ reason, refs.len, n_blocked, n_held, n_claimed, if (hint.len > 0) " — " else "", hint }),
                .ids => {},
            }
            return;
        }
        return O.oneOut(c.out, &w, pick, v);
    }
    if (o.count) return c.out.print("{{\"total\":{d}}}\n", .{refs.len});
    var shown = refs;
    if (o.limit) |l| if (l < shown.len) { shown = shown[0..l]; };
    try O.itemsOut(c.out, &w, shown, refs.len, v);
}

fn cmdGet(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    const r = try needItem(&w, try needId(o, "get"));
    try O.oneOut(c.out, &w, r, try viewOf(c.a, o));
}

const TagRow = struct { tag: []const u8, count: usize, open: usize };
const ValCount = struct { v: []const u8, n: usize };
const KeyRow = struct { key: []const u8, count: usize, vals: std.ArrayList(ValCount) = .empty };

fn tagRows(a: std.mem.Allocator, w: *const W.Work, refs: []const W.ItemRef) ![]TagRow {
    var rows: std.ArrayList(TagRow) = .empty;
    for (refs) |r| {
        const it = w.steps[r.si].items[r.ii];
        for (it.tags) |t| {
            var found = false;
            for (rows.items) |*row| {
                if (std.ascii.eqlIgnoreCase(row.tag, t)) {
                    row.count += 1;
                    if (!it.done) row.open += 1;
                    found = true;
                    break;
                }
            }
            if (!found) try rows.append(a, .{ .tag = t, .count = 1, .open = if (it.done) 0 else 1 });
        }
    }
    std.mem.sort(TagRow, rows.items, {}, struct {
        fn f(_: void, x: TagRow, y: TagRow) bool {
            if (x.count != y.count) return x.count > y.count;
            return std.ascii.lessThanIgnoreCase(x.tag, y.tag);
        }
    }.f);
    return rows.items;
}

fn keyRows(a: std.mem.Allocator, w: *const W.Work, refs: []const W.ItemRef) ![]KeyRow {
    var rows: std.ArrayList(KeyRow) = .empty;
    for (refs) |r| {
        for (w.steps[r.si].items[r.ii].fields) |f| {
            var row: *KeyRow = undefined;
            var found = false;
            for (rows.items) |*x| if (std.ascii.eqlIgnoreCase(x.key, f.key)) {
                row = x;
                found = true;
                break;
            };
            if (!found) {
                try rows.append(a, .{ .key = f.key, .count = 0 });
                row = &rows.items[rows.items.len - 1];
            }
            row.count += 1;
            var vf = false;
            for (row.vals.items) |*v| if (std.ascii.eqlIgnoreCase(v.v, f.value)) {
                v.n += 1;
                vf = true;
                break;
            };
            if (!vf) try row.vals.append(a, .{ .v = f.value, .n = 1 });
        }
    }
    for (rows.items) |*row| std.mem.sort(ValCount, row.vals.items, {}, struct {
        fn f(_: void, x: ValCount, y: ValCount) bool {
            return x.n > y.n;
        }
    }.f);
    std.mem.sort(KeyRow, rows.items, {}, struct {
        fn f(_: void, x: KeyRow, y: KeyRow) bool {
            if (x.count != y.count) return x.count > y.count;
            return std.ascii.lessThanIgnoreCase(x.key, y.key);
        }
    }.f);
    return rows.items;
}

fn cmdTags(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    const rows = try tagRows(c.a, &w, try collect(c.a, &w, o, false));
    if (o.format == .text or o.format == .ids) {
        for (rows) |r| if (o.format == .ids) try c.out.print("{s}\n", .{r.tag}) else try c.out.print("{s: <20} {d} ({d} aperte)\n", .{ r.tag, r.count, r.open });
        return;
    }
    try c.out.writeAll("{\"tags\":[");
    for (rows, 0..) |r, i| {
        if (i > 0) try c.out.writeByte(',');
        try c.out.writeAll("{\"tag\":");
        try O.jstr(c.out, r.tag);
        try c.out.print(",\"count\":{d},\"open\":{d}}}", .{ r.count, r.open });
    }
    try c.out.writeAll("]}\n");
}

fn cmdKeys(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    const rows = try keyRows(c.a, &w, try collect(c.a, &w, o, false));
    const max_vals = 8;
    if (o.format == .text or o.format == .ids) {
        for (rows) |r| {
            if (o.format == .ids) {
                try c.out.print("{s}\n", .{r.key});
                continue;
            }
            try c.out.print("{s: <16} {d} voci, {d} valori: ", .{ r.key, r.count, r.vals.items.len });
            for (r.vals.items[0..@min(max_vals, r.vals.items.len)], 0..) |v, i| try c.out.print("{s}{s}", .{ if (i > 0) ", " else "", v.v });
            try c.out.writeByte('\n');
        }
        return;
    }
    try c.out.writeAll("{\"keys\":[");
    for (rows, 0..) |r, i| {
        if (i > 0) try c.out.writeByte(',');
        try c.out.writeAll("{\"key\":");
        try O.jstr(c.out, r.key);
        try c.out.print(",\"count\":{d},\"distinct\":{d},\"values\":[", .{ r.count, r.vals.items.len });
        for (r.vals.items[0..@min(max_vals, r.vals.items.len)], 0..) |v, k| {
            if (k > 0) try c.out.writeByte(',');
            try O.jstr(c.out, v.v);
        }
        try c.out.writeAll("]}");
    }
    try c.out.writeAll("]}\n");
}

fn printUpdated(c: Ctx, w: *const W.Work, ids: []const []const u8, o: *const Opts) !void {
    var refs: std.ArrayList(W.ItemRef) = .empty;
    for (ids) |id| if (W.findItem(w, id)) |r| try refs.append(c.a, r);
    try O.itemsOut(c.out, w, refs.items, refs.items.len, try viewOf(c.a, o));
}

fn setDone(c: Ctx, o: *const Opts, done: bool, cmd: []const u8) !void {
    var w = try loadWork(c.a, o);
    if (o.pos.items.len == 0) return fail("manca almeno un ID (vedi `wk {s} --help`)", .{cmd});
    if (!done and o.result != null) return fail("--result vale solo con `check`", .{});
    if (o.result) |rs| {
        try noNewline(rs, "--result");
        if (W.trim(rs).len == 0) return fail("--result vuoto", .{});
    }
    for (o.pos.items) |id| _ = try needItem(&w, id);
    for (o.pos.items) |id| {
        const r = W.findItem(&w, id).?;
        var it = W.item(&w, r).*;
        if (it.done == done and !(done and o.result != null)) continue;
        if (done) {
            if (!it.done) {
                const od = try G.openDeps(c.a, &w, it);
                if (od.len > 0) warn("{s} ha dipendenze ancora aperte: {s}. Completata comunque (vedi `wk deps {s}`).", .{ id, try joinTags(c.a, od), id });
            }
            try dropField(c.a, &it, "claimed_by");
            try dropField(c.a, &it, "hold");
            if (o.result) |rs| {
                try checkLen("result", W.trim(rs), max_field);
                try putField(c.a, &it, "result", W.trim(rs));
            }
        }
        it.done = done;
        try W.commitItem(c.a, &w, r, it);
    }
    try commit(c, &w, o);
    var o2 = o.*;
    if (o2.fields == null) o2.brief = true;
    try printUpdated(c, &w, o.pos.items, &o2);
}

/// Salva lo stato del work; salvo --no-sync aggiorna anche Stato degli step e entrypoint.
fn commit(c: Ctx, w: *const W.Work, o: *const Opts) !void {
    var entry = try E.Entry.load(c.a, w.dir);
    if (!o.no_sync) _ = try S.sync(c.a, w, &entry);
    try W.save(c.a, w);
    if (entry) |e| try e.save(c.a);
}

fn canonKey(w: *const W.Work, key: []const u8) ?[]const u8 {
    for (w.steps) |s| for (s.items) |it| for (it.fields) |f| if (std.ascii.eqlIgnoreCase(f.key, key)) return f.key;
    return null;
}

fn canonTag(w: *const W.Work, tag: []const u8) ?[]const u8 {
    for (w.steps) |s| for (s.items) |it| for (it.tags) |t| if (std.ascii.eqlIgnoreCase(t, tag)) return t;
    return null;
}

fn listExisting(a: std.mem.Allocator, rows_keys: ?[]const KeyRow, rows_tags: ?[]const TagRow) []const u8 {
    var b: std.ArrayList(u8) = .empty;
    var n: usize = 0;
    if (rows_keys) |rk| for (rk) |r| {
        if (n == 12) break;
        b.print(a, "{s}{s}", .{ if (n > 0) ", " else "", r.key }) catch {};
        n += 1;
    };
    if (rows_tags) |rtags| for (rtags) |r| {
        if (n == 12) break;
        b.print(a, "{s}{s}", .{ if (n > 0) ", " else "", r.tag }) catch {};
        n += 1;
    };
    return b.items;
}

fn allRefs(a: std.mem.Allocator, w: *const W.Work) ![]W.ItemRef {
    var refs: std.ArrayList(W.ItemRef) = .empty;
    for (w.steps, 0..) |s, si| for (s.items, 0..) |_, ii| try refs.append(a, .{ .si = si, .ii = ii });
    return refs.items;
}

/// Allinea l'ortografia ai tag già presenti nel work e avvisa (stderr) se il tag è nuovo.
fn canonTags(a: std.mem.Allocator, w: *const W.Work, tags: []const []const u8) ![]const []const u8 {
    var out: List = .empty;
    const existing = try tagRows(a, w, try allRefs(a, w));
    for (tags) |t| {
        if (canonTag(w, t)) |c| {
            try out.append(a, c);
        } else {
            try out.append(a, t);
            if (existing.len > 0) warn("tag nuovo '{s}'. Tag esistenti: {s}. Se è lo stesso concetto usa quello esistente (vedi `wk tags`).", .{ t, listExisting(a, null, existing) });
        }
    }
    return out.items;
}

fn mergeSet(a: std.mem.Allocator, w: *const W.Work, it: *W.Item, kv_in: []const u8) !void {
    const kv = kv_in;
    const e = std.mem.indexOfScalar(u8, kv, '=') orelse return fail("'{s}': usa chiave=valore", .{kv});
    const key = W.trim(kv[0..e]);
    const val = W.trim(kv[e + 1 ..]);
    if (!W.validKey(key)) return fail("chiave '{s}' non valida (ammessi: lettere, cifre, _ e -)", .{key});
    if (val.len == 0) return fail("'{s}': valore vuoto (usa `wk unset` per rimuovere)", .{key});
    try noNewline(val, key);
    try checkLen(key, val, max_field);
    if (std.ascii.eqlIgnoreCase(key, "tags")) {
        var l: List = .empty;
        try W.splitTags(a, val, &l);
        it.tags = try canonTags(a, w, l.items);
        return;
    }
    if (std.ascii.eqlIgnoreCase(key, "deps") or std.ascii.eqlIgnoreCase(key, "deps_reason")) return fail("'{s}' si gestisce con `wk dep add|rm|set`", .{key});
    if (std.ascii.eqlIgnoreCase(key, "mode") or std.ascii.eqlIgnoreCase(key, "mode_reason")) return fail("'{s}' si gestisce con `wk classify`", .{key});
    if (std.ascii.eqlIgnoreCase(key, "hold") or std.ascii.eqlIgnoreCase(key, "answer") or std.ascii.eqlIgnoreCase(key, "asked") or std.ascii.eqlIgnoreCase(key, "hold_options") or std.ascii.eqlIgnoreCase(key, "hold_default") or std.ascii.eqlIgnoreCase(key, "answered_at")) return fail("'{s}' si gestisce con `wk hold` / `wk resolve` / `wk reply`", .{key});
    if (std.ascii.eqlIgnoreCase(key, "claimed_by")) return fail("'claimed_by' si gestisce con `wk claim` / `wk unclaim`", .{});
    for (W.reserved_keys) |r| if (std.ascii.eqlIgnoreCase(r, key)) return fail("'{s}' è una chiave riservata", .{key});
    var use_key = key;
    if (canonKey(w, key)) |ck| {
        use_key = ck;
    } else {
        const rows = try keyRows(a, w, try allRefs(a, w));
        if (rows.len > 0) warn("chiave nuova '{s}'. Chiavi esistenti: {s}. Se è la stessa informazione usa quella esistente (vedi `wk keys`).", .{ key, listExisting(a, rows, null) });
    }
    var fl: std.ArrayList(W.Field) = .empty;
    var replaced = false;
    for (it.fields) |f| {
        if (std.ascii.eqlIgnoreCase(f.key, use_key)) {
            try fl.append(a, .{ .key = f.key, .value = val });
            replaced = true;
        } else try fl.append(a, f);
    }
    if (!replaced) try fl.append(a, .{ .key = use_key, .value = val });
    it.fields = fl.items;
}

fn cmdSet(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    const id = try needId(o, "set");
    const r = try needItem(&w, id);
    if (o.pos.items.len < 2) return fail("manca chiave=valore (vedi `wk set --help`)", .{});
    var it = W.item(&w, r).*;
    for (o.pos.items[1..]) |kv| try mergeSet(c.a, &w, &it, kv);
    try W.commitItem(c.a, &w, r, it);
    try W.save(c.a, &w);
    try printUpdated(c, &w, &.{id}, o);
}

fn cmdUnset(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    const id = try needId(o, "unset");
    const r = try needItem(&w, id);
    if (o.pos.items.len < 2) return fail("manca la chiave da rimuovere", .{});
    var it = W.item(&w, r).*;
    for (o.pos.items[1..]) |key| {
        if (std.ascii.eqlIgnoreCase(key, "tags")) {
            it.tags = &.{};
            continue;
        }
        if (std.ascii.eqlIgnoreCase(key, "deps")) {
            it.deps = &.{};
            continue;
        }
        var fl: std.ArrayList(W.Field) = .empty;
        for (it.fields) |f| if (!std.ascii.eqlIgnoreCase(f.key, key)) try fl.append(c.a, f);
        it.fields = fl.items;
    }
    try W.commitItem(c.a, &w, r, it);
    try W.save(c.a, &w);
    try printUpdated(c, &w, &.{id}, o);
}

fn cmdTag(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    const id = try needId(o, "tag");
    const r = try needItem(&w, id);
    if (o.pos.items.len < 2) return fail("indica i tag: +nuovo -vecchio (vedi `wk tag --help`)", .{});
    var it = W.item(&w, r).*;
    var tags: List = .empty;
    try tags.appendSlice(c.a, it.tags);
    for (o.pos.items[1..]) |arg| {
        if (arg[0] == '-') {
            var rm: List = .empty;
            try W.splitTags(c.a, arg[1..], &rm);
            var keep: List = .empty;
            for (tags.items) |t| if (!W.hasTag(rm.items, t)) try keep.append(c.a, t);
            tags = keep;
        } else {
            const body = if (arg[0] == '+') arg[1..] else arg;
            try W.splitTags(c.a, body, &tags);
        }
    }
    // dedup (splitTags evita i duplicati nella stessa chiamata, non tra liste)
    var uniq: List = .empty;
    for (tags.items) |t| if (!W.hasTag(uniq.items, t)) try uniq.append(c.a, t);
    it.tags = try canonTags(c.a, &w, uniq.items);
    try W.commitItem(c.a, &w, r, it);
    try W.save(c.a, &w);
    try printUpdated(c, &w, &.{id}, o);
}

fn cmdEdit(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    const id = try needId(o, "edit");
    const r = try needItem(&w, id);
    const label = o.label orelse return fail("manca --label", .{});
    if (W.trim(label).len == 0) return fail("l'etichetta non può essere vuota", .{});
    try noNewline(label, "etichetta");
    try checkLen("label", W.trim(label), max_label);
    var it = W.item(&w, r).*;
    it.label = W.trim(label);
    try W.commitItem(c.a, &w, r, it);
    try W.save(c.a, &w);
    try printUpdated(c, &w, &.{id}, o);
}

fn cmdRm(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    if (o.pos.items.len == 0) return fail("manca almeno un ID", .{});
    for (o.pos.items) |id| _ = try needItem(&w, id);
    for (o.pos.items) |id| {
        for (try G.dependents(c.a, &w, id)) |dr| {
            const dit = W.item(&w, dr).*;
            var leaving = false;
            for (o.pos.items) |x| if (std.mem.eql(u8, x, dit.id)) {
                leaving = true;
            };
            if (leaving) continue;
            if (!o.force) return fail("'{s}' è una dipendenza di {s} (\"{s}\"). Usa --force per rimuoverla anche da lì, o `wk dep rm`.", .{ id, dit.id, dit.label });
            var nd: List = .empty;
            for (dit.deps) |d| if (!std.mem.eql(u8, d, id)) try nd.append(c.a, d);
            var it2 = dit;
            it2.deps = nd.items;
            try W.commitItem(c.a, &w, dr, it2);
        }
    }
    for (o.pos.items) |id| try W.removeItem(c.a, &w, W.findItem(&w, id).?);
    try commit(c, &w, o);
    try c.out.writeAll("{\"removed\":[");
    for (o.pos.items, 0..) |id, i| {
        if (i > 0) try c.out.writeByte(',');
        try O.jstr(c.out, id);
    }
    try c.out.writeAll("]}\n");
}

fn cmdAdd(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    if (w.steps.len == 0) return fail("il work non ha step: usa `wk new-step`", .{});
    if (o.pos.items.len == 0) return fail("manca l'etichetta: wk add --step S \"testo\"", .{});
    var lb: std.ArrayList(u8) = .empty;
    for (o.pos.items, 0..) |p, i| {
        if (i > 0) try lb.append(c.a, ' ');
        try lb.appendSlice(c.a, p);
    }
    const label = W.trim(lb.items);
    if (label.len == 0) return fail("l'etichetta non può essere vuota", .{});
    try noNewline(label, "etichetta");
    try checkLen("label", label, max_label);

    var after: ?W.ItemRef = null;
    if (o.after) |aid| after = try needItem(&w, aid);

    var si: usize = undefined;
    if (o.steps.items.len > 1) return fail("indica un solo --step", .{});
    if (o.steps.items.len == 1) {
        si = W.findStep(&w, o.steps.items[0]) orelse return fail("step '{s}' non trovato (vedi `wk steps`)", .{o.steps.items[0]});
        if (after != null and after.?.si != si) return fail("--after {s} appartiene a un altro step", .{o.after.?});
    } else if (after) |r| {
        si = r.si;
    } else if (w.steps.len == 1) {
        si = 0;
    } else return fail("indica lo step con --step (vedi `wk steps`)", .{});

    var id: []const u8 = undefined;
    if (o.id) |x| {
        if (!W.validId(x)) return fail("ID '{s}' non valido ([A-Za-z0-9_-], max 32)", .{x});
        if (W.findItem(&w, x) != null) return fail("ID '{s}' già in uso", .{x});
        id = x;
    } else id = try W.newId(c.a, &w);

    var it: W.Item = .{ .step = si, .line = 0, .end = 0, .done = o.checked, .id = id, .label = label, .group = "", .tags = o.tags.items, .fields = &.{}, .notes = &.{} };
    it.tags = try canonTags(c.a, &w, it.tags);
    for (o.sets.items) |kv| try mergeSet(c.a, &w, &it, kv);
    try W.addItem(c.a, &w, si, after, it);
    try commit(c, &w, o);
    const r = W.findItem(&w, id).?;
    if (!o.checked) {
        var graph = false;
        for (w.steps) |st| for (st.items) |x| if (x.deps.len > 0) {
            graph = true;
        };
        if (graph) warn("{s} è senza dipendenze né dipendenti, ma il work ha un grafo di dipendenze: se qualcosa la richiede prima, `wk dep add ALTRA {s}`; se lei richiede altro, `wk dep add {s} ALTRA` (altrimenti nessuna voce la aspetta e può restare indietro). Vedi `wk deps` / `wk help delegation`.", .{ id, id, id });
    }
    try O.oneOut(c.out, &w, r, try viewOf(c.a, o));
}

fn cmdAssign(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    var only: ?usize = null;
    if (o.steps.items.len > 0) only = W.findStep(&w, o.steps.items[0]) orelse return fail("step '{s}' non trovato", .{o.steps.items[0]});
    const n = try W.assignIds(c.a, &w, only, o.dry_run);
    if (!o.dry_run) try W.save(c.a, &w);
    try c.out.print("{{\"assigned\":{d},\"dry_run\":{s}}}\n", .{ n, if (o.dry_run) "true" else "false" });
}

fn cmdValidate(c: Ctx, o: *const Opts) !u8 {
    const w = try loadWorkRaw(c.a, o);
    const out = c.out;
    var errors: usize = 0;
    var warnings: usize = 0;
    var n: usize = 0;
    try out.writeAll("{\"issues\":[");
    const Emit = struct {
        fn f(out_: *std.Io.Writer, count: *usize, level: []const u8, step: []const u8, line: usize, msg: []const u8) !void {
            if (count.* > 0) try out_.writeByte(',');
            count.* += 1;
            try out_.writeAll("{\"level\":");
            try O.jstr(out_, level);
            try out_.writeAll(",\"step\":");
            try O.jstr(out_, step);
            try out_.print(",\"line\":{d},\"problem\":", .{line});
            try O.jstr(out_, msg);
            try out_.writeByte('}');
        }
    };
    const allowed = [_][]const u8{ "da iniziare", "in corso", "bloccato", "completato" };
    var any_mode = false;
    for (w.steps) |s| for (s.items) |it| if (O.fieldValue(it, "mode") != null) {
        any_mode = true;
    };
    var unclassified: usize = 0;

    if (try E.Entry.load(c.a, w.dir)) |e| {
        const v = e.formatVersion() orelse 0;
        if (v > F.current) {
            errors += 1;
            try Emit.f(out, &n, "error", "entrypoint", 1, try std.fmt.allocPrint(c.a, "formato documenti {d} più recente di questo wk ({d}): aggiorna wk", .{ v, F.current }));
        } else if (v < F.current) {
            warnings += 1;
            try Emit.f(out, &n, "warning", "entrypoint", 1, try std.fmt.allocPrint(c.a, "formato documenti {d} (wk è alla {d}): `wk migrate --from {d}`", .{ v, F.current, v }));
        }
    }
    {
        const sizes = [_]struct { f: []const u8, max: u64, hint: []const u8 }{
            .{ .f = "entrypoint.md", .max = 4000, .hint = "tienilo minimo: `wk entry slim` sposta le sezioni oltre 'Current task' in entrypoint-archive.md" },
            .{ .f = "plan.md", .max = 16000, .hint = "sintetizza: l'agente lo legge a sezioni (`wk section get plan \"titolo\"`)" },
        };
        for (sizes) |sz| {
            const st = rt.cwd().statFile(rt.io, try std.fs.path.join(c.a, &.{ w.dir, sz.f }), .{}) catch continue;
            if (st.size > sz.max) {
                warnings += 1;
                try Emit.f(out, &n, "warning", sz.f, 1, try std.fmt.allocPrint(c.a, "{s} è di {d} byte (soglia {d}): {s}", .{ sz.f, st.size, sz.max, sz.hint }));
            }
        }
        var longs: usize = 0;
        var ex_id: []const u8 = "";
        var ex_key: []const u8 = "";
        for (w.steps) |s| for (s.items) |it| for (it.fields) |f| {
            if (f.value.len > max_field and !std.ascii.eqlIgnoreCase(f.key, "answer")) {
                longs += 1;
                if (ex_id.len == 0) {
                    ex_id = it.id;
                    ex_key = f.key;
                }
            }
        };
        if (longs > 0) {
            warnings += 1;
            try Emit.f(out, &n, "warning", "work", 1, try std.fmt.allocPrint(c.a, "{d} campi oltre {d} caratteri (es. {s} {s}): appesantiscono ogni lettura; riassumili con `wk set` e metti i dettagli in un file", .{ longs, max_field, ex_id, ex_key }));
        }
    }
    for (w.steps) |s| {
        if (s.title.len == 0) {
            errors += 1;
            try Emit.f(out, &n, "error", s.key, 1, "manca il titolo '# …'");
        }
        if (s.status.len == 0) {
            errors += 1;
            try Emit.f(out, &n, "error", s.key, 1, "manca la riga '**Stato:**' (usa `wk step-status`)");
        } else {
            var ok = false;
            for (allowed) |x| if (std.ascii.startsWithIgnoreCase(s.status, x)) {
                ok = true;
            };
            if (!ok) {
                errors += 1;
                try Emit.f(out, &n, "error", s.key, 1, try std.fmt.allocPrint(c.a, "stato non ammesso '{s}' (da iniziare, in corso, bloccato, completato)", .{s.status}));
            }
        }
        if (s.cl_start == null) {
            errors += 1;
            try Emit.f(out, &n, "error", s.key, 1, "manca la sezione '## Checklist'");
        }
        for (s.items, 0..) |it, ii| {
            const line = it.line + 1;
            if (it.id.len == 0) {
                errors += 1;
                try Emit.f(out, &n, "error", s.key, line, "voce senza ID (esegui `wk assign-ids`)");
            }
            if (it.label.len == 0) {
                errors += 1;
                try Emit.f(out, &n, "error", s.key, line, "etichetta vuota");
            }
            if (it.id.len > 0) {
                const first = W.findItem(&w, it.id).?;
                if (first.si != s.idx or first.ii != ii) {
                    errors += 1;
                    try Emit.f(out, &n, "error", s.key, line, try std.fmt.allocPrint(c.a, "ID duplicato '{s}'", .{it.id}));
                }
            }
            if (O.fieldValue(it, "mode")) |m| {
                if (!(std.ascii.eqlIgnoreCase(m, "isolated") or std.ascii.eqlIgnoreCase(m, "integrated"))) {
                    errors += 1;
                    try Emit.f(out, &n, "error", s.key, line, try std.fmt.allocPrint(c.a, "mode '{s}' non valido (isolated o integrated)", .{m}));
                }
            } else if (!it.done) unclassified += 1;
            for (it.deps) |d| {
                if (it.id.len > 0 and std.mem.eql(u8, d, it.id)) {
                    errors += 1;
                    try Emit.f(out, &n, "error", s.key, line, "la voce dipende da se stessa");
                    continue;
                }
                const dr = W.findItem(&w, d) orelse {
                    errors += 1;
                    try Emit.f(out, &n, "error", s.key, line, try std.fmt.allocPrint(c.a, "dipendenza '{s}' inesistente", .{d}));
                    continue;
                };
                if (it.done and !W.item(&w, dr).done) {
                    warnings += 1;
                    try Emit.f(out, &n, "warning", s.key, line, try std.fmt.allocPrint(c.a, "completata con dipendenza '{s}' ancora aperta", .{d}));
                }
            }
            if (it.id.len > 0 and it.deps.len > 0 and try G.reaches(c.a, &w, it.id, it.id)) {
                errors += 1;
                try Emit.f(out, &n, "error", s.key, line, try std.fmt.allocPrint(c.a, "ciclo di dipendenze che include '{s}'", .{it.id}));
            }
        }
    }
    if (any_mode and unclassified > 0) {
        warnings += 1;
        try Emit.f(out, &n, "warning", "", 0, try std.fmt.allocPrint(c.a, "{d} voci aperte senza classificazione (`wk list --mode unset --open`)", .{unclassified}));
    }
    try out.print("],\"errors\":{d},\"warnings\":{d},\"ok\":{s}}}\n", .{ errors, warnings, if (errors == 0) "true" else "false" });
    return if (errors == 0) 0 else 2;
}

fn cmdStepStatus(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    if (o.pos.items.len != 2) return fail("uso: wk step-status STEP \"da iniziare|in corso|bloccato|completato\"", .{});
    const si = W.findStep(&w, o.pos.items[0]) orelse return fail("step '{s}' non trovato (vedi `wk steps`)", .{o.pos.items[0]});
    const val = W.trim(o.pos.items[1]);
    const allowed = [_][]const u8{ "da iniziare", "in corso", "bloccato", "completato" };
    var ok = false;
    for (allowed) |x| if (std.ascii.eqlIgnoreCase(x, val)) { ok = true; };
    if (!ok) return fail("stato '{s}' non ammesso: usa da iniziare, in corso, bloccato o completato", .{val});
    const step = &w.steps[si];
    if (step.status.len == 0) return fail("{s} non ha la riga `**Stato:**`", .{step.file});
    try W.setStatus(c.a, step, val);
    try commit(c, &w, o);
    try c.out.writeAll("{\"step\":");
    try O.jstr(c.out, step.key);
    try c.out.writeAll(",\"status\":");
    try O.jstr(c.out, step.status);
    try c.out.writeAll("}\n");
}

fn cmdSync(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    var entry = try E.Entry.load(c.a, w.dir);
    const r = try S.sync(c.a, &w, &entry);
    if (!o.dry_run) {
        try W.save(c.a, &w);
        if (entry) |e| try e.save(c.a);
    }
    const out = c.out;
    try out.writeAll("{\"current\":");
    if (r.current) |k| try O.jstr(out, k) else try out.writeAll("null");
    try out.print(",\"entrypoint\":{s},\"dry_run\":{s},\"changes\":[", .{ if (r.entry_found) "true" else "false", if (o.dry_run) "true" else "false" });
    for (r.changes, 0..) |ch, i| {
        if (i > 0) try out.writeByte(',');
        try out.writeAll("{\"target\":");
        try O.jstr(out, ch.target);
        try out.writeAll(",\"field\":");
        try O.jstr(out, ch.field);
        try out.writeAll(",\"from\":");
        try O.jstr(out, ch.from);
        try out.writeAll(",\"to\":");
        try O.jstr(out, ch.to);
        try out.writeByte('}');
    }
    try out.writeAll("]}\n");
}

const auto_fields = [_][]const u8{ "File", "Stato", "Avanzamento" };

fn cmdEntry(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    var entry = (try E.Entry.load(c.a, w.dir)) orelse return fail("{s}/entrypoint.md non esiste", .{w.dir});
    const sub = if (o.pos.items.len > 0) o.pos.items[0] else "get";
    if (std.mem.eql(u8, sub, "get")) {
        const fl = try entry.fields(c.a);
        if (o.format == .text) {
            try c.out.print("formato documenti: work {d}, tool {d}\n", .{ entry.formatVersion() orelse 0, F.current });
            for (fl) |f| try c.out.print("{s}: {s}\n", .{ f.label, f.value });
            return;
        }
        const wv = entry.formatVersion() orelse 0;
        try c.out.writeAll("{\"path\":");
        try O.jstr(c.out, entry.path);
        try c.out.print(",\"format\":{{\"work\":{d},\"tool\":{d}}}", .{ wv, F.current });
        if (wv < F.current) try c.out.print(",\"migrate\":\"wk migrate --from {d}\"", .{wv});
        try c.out.writeAll(",\"fields\":[");
        for (fl, 0..) |f, i| {
            if (i > 0) try c.out.writeByte(',');
            try c.out.writeAll("{\"label\":");
            try O.jstr(c.out, f.label);
            try c.out.writeAll(",\"value\":");
            try O.jstr(c.out, f.value);
            try c.out.writeByte('}');
        }
        try c.out.writeAll("]}\n");
        return;
    }
    if (std.mem.eql(u8, sub, "slim")) {
        // sposta in entrypoint-archive.md tutte le sezioni tranne 'Current task'
        var keep: std.ArrayList([]const u8) = .empty;
        var moved: std.ArrayList([]const u8) = .empty;
        var titles: std.ArrayList([]const u8) = .empty;
        var in_keep = true;
        var cur: std.ArrayList([]const u8) = .empty;
        const flush = struct {
            fn f(a: std.mem.Allocator, mv: *std.ArrayList([]const u8), cur_: *std.ArrayList([]const u8)) !void {
                try mv.appendSlice(a, cur_.items);
                cur_.clearRetainingCapacity();
            }
        }.f;
        for (entry.lines.items) |l| {
            if (std.mem.startsWith(u8, l, "## ")) {
                try flush(c.a, &moved, &cur);
                in_keep = std.ascii.eqlIgnoreCase(W.trim(l[3..]), "current task");
                if (!in_keep) try titles.append(c.a, W.trim(l[3..]));
            }
            if (in_keep) try keep.append(c.a, l) else try cur.append(c.a, l);
        }
        try flush(c.a, &moved, &cur);
        var moved_bytes: usize = 0;
        for (moved.items) |l| moved_bytes += l.len + 1;
        var before: usize = 0;
        for (entry.lines.items) |l| before += l.len + 1;
        if (!o.dry_run and moved.items.len > 0) {
            const apath = try std.fs.path.join(c.a, &.{ w.dir, "entrypoint-archive.md" });
            const old = rt.readFileAlloc(c.a, apath, 64 * 1024 * 1024) catch |e| switch (e) {
                error.FileNotFound => @as([]u8, try c.a.dupe(u8, "# Archivio dell'entrypoint\n\nSezioni spostate da `wk entry slim`: non vanno lette per riprendere il lavoro.\n")),
                else => return e,
            };
            var ab: std.ArrayList(u8) = .empty;
            try ab.appendSlice(c.a, old);
            if (old.len == 0 or old[old.len - 1] != '\n') try ab.append(c.a, '\n');
            try ab.print(c.a, "\n<!-- archiviato il {s} -->\n\n", .{try nowIso(c.a)});
            for (moved.items) |l| try ab.print(c.a, "{s}\n", .{l});
            var alines: std.ArrayList([]const u8) = .empty;
            var asp = std.mem.splitScalar(u8, std.mem.trimEnd(u8, ab.items, "\n"), '\n');
            while (asp.next()) |l| try alines.append(c.a, l);
            try W.writeFileAtomic(c.a, apath, alines.items, true);
            entry.lines = keep;
            entry.dirty = true;
            entry.locate();
            try entry.save(c.a);
        }
        var after_bytes: usize = 0;
        for (keep.items) |l| after_bytes += l.len + 1;
        try c.out.print("{{\"dry_run\":{s},\"moved_sections\":[", .{if (o.dry_run) "true" else "false"});
        for (titles.items, 0..) |t, i| {
            if (i > 0) try c.out.writeByte(',');
            try O.jstr(c.out, t);
        }
        try c.out.print("],\"bytes_before\":{d},\"bytes_after\":{d},\"archive\":\"entrypoint-archive.md\"}}\n", .{ before, if (moved.items.len > 0) after_bytes else before });
        return;
    }
    const is_set = std.mem.eql(u8, sub, "set");
    if (!is_set and !std.mem.eql(u8, sub, "unset")) return fail("sottocomando '{s}': usa get, set, unset o slim (vedi `wk entry --help`)", .{sub});
    if (o.pos.items.len < (if (is_set) @as(usize, 3) else 2)) return fail("uso: wk entry set \"Etichetta\" \"valore\"  |  wk entry unset \"Etichetta\"", .{});
    const label = W.trim(o.pos.items[1]);
    if (label.len == 0 or std.mem.indexOfAny(u8, label, ":*\r\n") != null) return fail("etichetta non valida: '{s}'", .{label});
    if (std.ascii.eqlIgnoreCase(label, "Sessione automatica")) return fail("'Sessione automatica' si gestisce con `wk auto start|status|stop`", .{});
    for (auto_fields) |af| if (std.ascii.eqlIgnoreCase(af, label)) return fail("'{s}' è gestito da `wk sync` (si aggiorna da solo)", .{af});
    var changed: bool = undefined;
    if (is_set) {
        var vb: std.ArrayList(u8) = .empty;
        for (o.pos.items[2..], 0..) |p, i| {
            if (i > 0) try vb.append(c.a, ' ');
            try vb.appendSlice(c.a, p);
        }
        const val = W.trim(vb.items);
        if (val.len == 0) return fail("valore vuoto (usa `wk entry unset`)", .{});
        try noNewline(val, "valore");
        try checkLen(label, val, max_field + 200);
        changed = entry.set(c.a, label, val, null) catch |e| switch (e) {
            error.NoSection => return fail("entrypoint.md non ha la sezione '## Current task'", .{}),
            else => return e,
        };
    } else {
        changed = try entry.unset(c.a, label);
    }
    try entry.save(c.a);
    try c.out.print("{{\"changed\":{s}}}\n", .{if (changed) "true" else "false"});
}

const step_template =
    \\# Step {s} — {s}
    \\
    \\**Fase del piano:** da definire  
    \\**Stato:** da iniziare  
    \\
    \\## Obiettivo
    \\
    \\Da definire.
    \\
    \\## Checklist
    \\
    \\## Criteri di uscita
    \\
    \\- Da definire.
    \\
    \\## Risultati e decisioni
    \\
    \\## Ripresa e passaggio di consegne
    \\
    \\- **Prossima azione:** da definire.
    \\
;

fn writeNew(a: std.mem.Allocator, path: []const u8, content: []const u8) !void {
    _ = a;
    var f = rt.createFile(path, .{ .exclusive = true }) catch |e| switch (e) {
        error.PathAlreadyExists => return,
        else => return e,
    };
    defer f.close(rt.io);
    try f.writeStreamingAll(rt.io, content);
}

fn cmdNewStep(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    var max: u64 = 0;
    for (w.steps) |s| if (W.trailingNumber(s.key)) |n| { if (n > max) max = n; };
    const num = try std.fmt.allocPrint(c.a, "{d:0>3}", .{max + 1});
    const file = try std.fmt.allocPrint(c.a, "tasks-step-{s}.md", .{num});
    const path = try std.fs.path.join(c.a, &.{ w.dir, file });
    const title = o.title orelse try std.fmt.allocPrint(c.a, "Step {s}", .{num});
    const body = try std.fmt.allocPrint(c.a, step_template, .{ num, title });
    rt.cwd().access(rt.io, path, .{}) catch {
        try writeNew(c.a, path, body);
        var w2 = try W.load(c.a, w.dir);
        if (o.phase != null or o.prereq != null) {
            const ns = &w2.steps[w2.steps.len - 1];
            if (o.phase) |t| try W.setMeta(c.a, ns, "Fase del piano", W.trim(t));
            if (o.prereq) |t| try W.setMeta(c.a, ns, "Prerequisiti", W.trim(t));
        }
        try commit(c, &w2, o);
        try c.out.print("{{\"created\":\"{s}\",\"key\":\"step-{s}\"}}\n", .{ file, num });
        return;
    };
    return fail("{s} esiste già", .{file});
}

fn cmdInit(c: Ctx, o: *const Opts) !void {
    if (o.pos.items.len != 1) return fail("uso: wk init DIR [--title T]", .{});
    const dir = o.pos.items[0];
    try rt.makePath(dir);
    {
        var d = try rt.openDir(dir, .{ .iterate = true });
        defer d.close(rt.io);
        var it = d.iterate();
        if (try it.next(rt.io) != null and !o.force) return fail("'{s}' non è vuota (usa --force: non sovrascrive i file esistenti)", .{dir});
    }
    const title = o.title orelse std.fs.path.basename(dir);
    const entry = try std.fmt.allocPrint(c.a,
        \\# {s} — entrypoint
        \\
        \\**Versione documenti:** {d}
        \\
        \\## Current task
        \\
        \\- **File:** [tasks-step-001.md — Step 001](tasks-step-001.md)
        \\- **Stato:** da iniziare
        \\- **Prossima azione:** da definire
        \\
    , .{ title, F.current });
    const plan = try std.fmt.allocPrint(c.a, "# Piano — {s}\n\n## Strategia\n\nDa definire.\n", .{title});
    try writeNew(c.a, try std.fs.path.join(c.a, &.{ dir, "entrypoint.md" }), entry);
    try writeNew(c.a, try std.fs.path.join(c.a, &.{ dir, "plan.md" }), plan);
    try writeNew(c.a, try std.fs.path.join(c.a, &.{ dir, "tasks-step-001.md" }), try std.fmt.allocPrint(c.a, step_template, .{ "001", o.first_step orelse "Primo step" }));
    try c.out.writeAll("{\"created\":");
    try O.jstr(c.out, dir);
    try c.out.writeAll(",\"files\":[\"entrypoint.md\",\"plan.md\",\"tasks-step-001.md\"]}\n");
}



// ------------------------------------------------------------ hook di Claude Code (plugin)
//
// `wk hook session-start|stop` legge da stdin il JSON dell'hook. Fuori da un progetto con un work
// (.work/…) non stampa nulla e non scrive nulla: l'hook è invisibile.

const HookIn = struct { cwd: []const u8 = "", session_id: []const u8 = "", source: []const u8 = "" };

fn hookInput(a: std.mem.Allocator) HookIn {
    const data = readStdin(a) catch return .{};
    const p = std.json.parseFromSlice(HookIn, a, data, .{ .ignore_unknown_fields = true }) catch return .{};
    return p.value;
}

/// work del progetto: risale da `start` e si ferma al primo livello che ne ha (come resolveWork, senza errori)
fn findWorks(a: std.mem.Allocator, start: []const u8) !List {
    var cur: []const u8 = rt.realpathAlloc(a, if (start.len > 0) start else ".") catch return .empty;
    while (true) {
        if (W.isWorkDir(cur)) {
            var l: List = .empty;
            try l.append(a, cur);
            return l;
        }
        const wd = try std.fs.path.join(a, &.{ cur, ".work" });
        if (dirExists(wd)) {
            const l = try worksIn(a, wd);
            if (l.items.len > 0) return l;
        }
        const parent = std.fs.path.dirname(cur) orelse break;
        if (parent.len == cur.len) break;
        cur = parent;
    }
    return .empty;
}

/// stato per sessione di Claude Code: `start=<iso>`, `completed=N`, `stalls=N`
const HookState = struct { start: []const u8 = "", completed: i64 = -1, stalls: i64 = 0 };

fn hookStatePath(a: std.mem.Allocator, sid: []const u8) ![]const u8 {
    const dir = getEnv(a, "TMPDIR") orelse getEnv(a, "TEMP") orelse getEnv(a, "TMP") orelse "/tmp";
    var b: std.ArrayList(u8) = .empty;
    for (sid) |ch| try b.append(a, if (std.ascii.isAlphanumeric(ch) or ch == '-' or ch == '_') ch else '_');
    return std.fs.path.join(a, &.{ dir, try std.fmt.allocPrint(a, "work-steps-{s}.state", .{if (b.items.len > 0) b.items else "anon"}) });
}

fn readHookState(a: std.mem.Allocator, path: []const u8) ?HookState {
    const data = rt.readFileAlloc(a, path, 4096) catch return null;
    var st: HookState = .{};
    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |l| {
        const t = W.trim(l);
        if (std.mem.startsWith(u8, t, "start=")) st.start = t[6..];
        if (std.mem.startsWith(u8, t, "completed=")) st.completed = std.fmt.parseInt(i64, t[10..], 10) catch -1;
        if (std.mem.startsWith(u8, t, "stalls=")) st.stalls = std.fmt.parseInt(i64, t[7..], 10) catch 0;
    }
    return st;
}

fn writeHookState(a: std.mem.Allocator, path: []const u8, st: HookState) void {
    const txt = std.fmt.allocPrint(a, "start={s}\ncompleted={d}\nstalls={d}\n", .{ st.start, st.completed, st.stalls }) catch return;
    var f = rt.createFile(path, .{ .truncate = true }) catch return;
    defer f.close(rt.io);
    f.writeStreamingAll(rt.io, txt) catch {};
}

fn sessionOf(a: std.mem.Allocator, dir: []const u8) ?Session {
    const e = (E.Entry.load(a, dir) catch return null) orelse return null;
    const v = e.get(session_label) orelse return null;
    return parseSession(v);
}

fn cmdHook(c: Ctx, o: *const Opts) !u8 {
    const sub = if (o.pos.items.len > 0) o.pos.items[0] else return 0;
    const inp = hookInput(c.a);
    const works = try findWorks(c.a, inp.cwd);
    if (works.items.len == 0) return 0; // non c'è un work: nessun effetto
    const sp = try hookStatePath(c.a, inp.session_id);
    var st = readHookState(c.a, sp) orelse HookState{};
    const out = c.out;

    if (std.mem.eql(u8, sub, "session-start")) {
        // l'inizio di questa conversazione serve a riconoscere le sessioni automatiche "vecchie"
        const fresh = !std.mem.eql(u8, inp.source, "compact") and !std.mem.eql(u8, inp.source, "resume");
        if (st.start.len == 0 or fresh) {
            st = .{ .start = try nowIso(c.a) };
            writeHookState(c.a, sp, st);
        }
        const self_exe: []const u8 = std.process.executablePathAlloc(rt.io, c.a) catch "wk";
        var b: std.ArrayList(u8) = .empty;
        try b.print(c.a, "Questo progetto ha dei work (", .{});
        for (works.items, 0..) |w, i| try b.print(c.a, "{s}{s}", .{ if (i > 0) ", " else "", std.fs.path.basename(w) });
        try b.print(c.a, "): si leggono e si modificano solo con la CLI `wk` (skill wk), mai a mano. Per riprendere: `wk steps` e `wk next`; non leggere entrypoint.md e plan.md come file. Se `wk` non è nel PATH il binario è {s}.", .{self_exe});
        for (works.items) |w| {
            if (sessionOf(c.a, w) == null) continue;
            const name = std.fs.path.basename(w);
            if (std.mem.eql(u8, inp.source, "compact")) {
                try b.print(c.a, " SESSIONE AUTOMATICA ATTIVA su {s}: dopo la compattazione prosegui il ciclo (`wk auto status`, poi `wk next`); regole e condizioni di stop in `wk help auto`.", .{name});
            } else {
                try b.print(c.a, " Su {s} c'è una sessione automatica registrata da una conversazione precedente: non riprenderla senza una richiesta esplicita dell'utente (`wk auto stop --force` per chiuderla).", .{name});
            }
        }
        try out.writeAll("{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":");
        try O.jstr(out, b.items);
        try out.writeAll("}}\n");
        return 0;
    }

    if (std.mem.eql(u8, sub, "stop")) {
        for (works.items) |wdir| {
            const sess = sessionOf(c.a, wdir) orelse continue;
            // solo le sessioni avviate in questa conversazione: una sessione vecchia non deve trattenere l'agente
            if (st.start.len == 0 or std.mem.order(u8, sess.started, st.start) == .lt) continue;
            const w = W.load(c.a, wdir) catch continue;
            const cn = computeCounters(&w);
            const ev = evalSession(cn, sess);
            // si blocca solo l'arresto "a lavoro disponibile"; domande all'utente, limite e fine lavoro lasciano fermarsi
            if (!ev.cont or !std.mem.eql(u8, ev.reason, "ok")) continue;
            if (ev.completed > st.completed) st.stalls = 0 else st.stalls += 1;
            st.completed = ev.completed;
            writeHookState(c.a, sp, st);
            if (st.stalls >= 3) continue; // nessun progresso dopo più richiami: non incastrare l'agente
            const msg = try std.fmt.allocPrint(c.a, "Sessione automatica attiva su {s}: `wk auto status` dà continue=true (completate {d}/{d}, disponibili {d}). Non ti fermare: chiudere uno step o un traguardo non è uno stop. Prosegui con `wk next`. Se l'utente ti ha chiesto di fermarti: `wk auto stop --force`.", .{ std.fs.path.basename(wdir), ev.completed, sess.limit, cn.avail });
            try out.writeAll("{\"decision\":\"block\",\"reason\":");
            try O.jstr(out, msg);
            try out.writeAll("}\n");
            return 0;
        }
        return 0;
    }
    return 0;
}

// ------------------------------------------------------------ classificazione e dipendenze

fn putField(a: std.mem.Allocator, it: *W.Item, key: []const u8, val: []const u8) !void {
    var fl: std.ArrayList(W.Field) = .empty;
    var replaced = false;
    for (it.fields) |f| {
        if (std.ascii.eqlIgnoreCase(f.key, key)) {
            try fl.append(a, .{ .key = f.key, .value = val });
            replaced = true;
        } else try fl.append(a, f);
    }
    if (!replaced) try fl.append(a, .{ .key = key, .value = val });
    it.fields = fl.items;
}

fn dropField(a: std.mem.Allocator, it: *W.Item, key: []const u8) !void {
    var fl: std.ArrayList(W.Field) = .empty;
    for (it.fields) |f| if (!std.ascii.eqlIgnoreCase(f.key, key)) try fl.append(a, f);
    it.fields = fl.items;
}

fn printWith(c: Ctx, w: *const W.Work, ids: []const []const u8, o: *const Opts, default_fields: []const u8) !void {
    var o2 = o.*;
    if (o2.fields == null and !o2.brief) o2.fields = default_fields;
    try printUpdated(c, w, ids, &o2);
}

fn cmdClassify(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    if (o.pos.items.len == 0) return fail("manca almeno un ID (vedi `wk classify --help`)", .{});
    const mode = o.mode orelse return fail("manca --mode isolated|integrated|unset", .{});
    if (o.reason) |r| try noNewline(r, "--reason");
    for (o.pos.items) |id| _ = try needItem(&w, id);
    for (o.pos.items) |id| {
        const r = W.findItem(&w, id).?;
        var it = W.item(&w, r).*;
        const old = O.fieldValue(it, "mode");
        if (std.mem.eql(u8, mode, "unset")) {
            try dropField(c.a, &it, "mode");
            try dropField(c.a, &it, "mode_reason");
        } else {
            const changed = old == null or !std.ascii.eqlIgnoreCase(old.?, mode);
            try putField(c.a, &it, "mode", mode);
            if (o.reason) |rs| {
                try putField(c.a, &it, "mode_reason", W.trim(rs));
            } else if (changed and O.fieldValue(it, "mode_reason") != null) {
                try dropField(c.a, &it, "mode_reason");
                warn("{s}: motivo precedente rimosso perché la classificazione è cambiata; indica il nuovo con --reason.", .{id});
            }
        }
        try W.commitItem(c.a, &w, r, it);
    }
    try W.save(c.a, &w);
    try printWith(c, &w, o.pos.items, o, "id,mode,mode_reason");
}

fn cmdDep(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    if (o.pos.items.len < 2) return fail("uso: wk dep add|rm|set ID [DEP...] (vedi `wk dep --help`)", .{});
    const sub = o.pos.items[0];
    const is_add = std.mem.eql(u8, sub, "add");
    const is_rm = std.mem.eql(u8, sub, "rm");
    const is_set = std.mem.eql(u8, sub, "set");
    if (!is_add and !is_rm and !is_set) return fail("sottocomando '{s}': usa add, rm o set", .{sub});
    const id = o.pos.items[1];
    const r = try needItem(&w, id);
    const args = o.pos.items[2..];
    if ((is_add or is_rm) and args.len == 0) return fail("indica almeno un ID di dipendenza", .{});
    if (o.reason) |rs| try noNewline(rs, "--reason");

    var it = W.item(&w, r).*;
    var cur: List = .empty;
    if (!is_set) try cur.appendSlice(c.a, it.deps);

    if (is_rm) {
        var keep: List = .empty;
        for (cur.items) |d| {
            var drop = false;
            for (args) |x| if (std.mem.eql(u8, x, d)) {
                drop = true;
            };
            if (!drop) try keep.append(c.a, d);
        }
        cur = keep;
    } else {
        for (args) |d| {
            const dr = W.findItem(&w, d) orelse return fail("dipendenza '{s}' non trovata", .{d});
            if (std.mem.eql(u8, d, id)) return fail("una voce non può dipendere da se stessa ('{s}')", .{id});
            if (try G.reaches(c.a, &w, d, id)) return fail("ciclo: '{s}' dipende già, anche indirettamente, da '{s}'. Vedi `wk deps {s} --up`.", .{ d, id, d });
            var dup = false;
            for (cur.items) |x| if (std.mem.eql(u8, x, d)) {
                dup = true;
            };
            if (!dup) try cur.append(c.a, d);
            if (it.done and !W.item(&w, dr).done) warn("{s} è completata ma la dipendenza {s} è aperta.", .{ id, d });
        }
    }
    it.deps = cur.items;
    if (cur.items.len == 0) {
        try dropField(c.a, &it, "deps_reason");
    } else if (o.reason) |rs| {
        try putField(c.a, &it, "deps_reason", W.trim(rs));
    }
    try W.commitItem(c.a, &w, r, it);
    try W.save(c.a, &w);
    try printWith(c, &w, &.{id}, o, "id,deps,blocked_by");
}

fn cmdDeps(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    if (o.up and o.down) return fail("usa solo uno tra --up e --down", .{});
    var root: ?W.ItemRef = null;
    if (o.pos.items.len > 0) root = try needItem(&w, o.pos.items[0]);
    const up = if (o.up) true else if (o.down) false else root != null;
    const nodes = try G.walk(c.a, &w, root, up, o.depth, o.open);
    const out = c.out;
    if (o.format != .json) {
        for (nodes) |n| {
            const it = W.item(&w, n.ref).*;
            if (o.format == .ids) {
                try out.print("{s}\n", .{it.id});
                continue;
            }
            for (0..n.depth) |_| try out.writeAll("  ");
            try O.itemText(out, &w, it, .{ .brief = true });
            try out.writeByte('\n');
        }
        return;
    }
    try out.writeAll("{\"root\":");
    if (root) |r| try O.jstr(out, W.item(&w, r).id) else try out.writeAll("null");
    try out.print(",\"direction\":\"{s}\",\"count\":{d},\"nodes\":[", .{ if (up) "up" else "down", nodes.len });
    for (nodes, 0..) |n, i| {
        const it = W.item(&w, n.ref).*;
        if (i > 0) try out.writeByte(',');
        try out.writeAll("{\"id\":");
        try O.jstr(out, it.id);
        try out.print(",\"done\":{s},\"label\":", .{if (it.done) "true" else "false"});
        try O.jstr(out, it.label);
        if (O.fieldValue(it, "mode")) |m| {
            try out.writeAll(",\"mode\":");
            try O.jstr(out, m);
        }
        try out.print(",\"depth\":{d},\"parent\":", .{n.depth});
        if (n.parent) |p| try O.jstr(out, p) else try out.writeAll("null");
        try out.writeByte('}');
    }
    try out.writeAll("]}\n");
}

fn cmdWaves(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    const wv = try G.waves(c.a, &w);
    const steps = try resolveSteps(c.a, &w, o);
    var v = try viewOf(c.a, o);
    if (o.fields == null and !o.brief) v.fields = &.{ "id", "label", "mode" };
    const out = c.out;
    if (o.format == .json) try out.writeAll("{\"waves\":[");
    var first = true;
    for (wv.waves, 0..) |wave, wi| {
        var shown: std.ArrayList(W.ItemRef) = .empty;
        for (wave) |r| if (passes(c.a, &w, W.item(&w, r).*, o, steps, true)) try shown.append(c.a, r);
        if (shown.items.len == 0) continue;
        if (o.format == .json) {
            if (!first) try out.writeByte(',');
            try out.print("{{\"wave\":{d},\"items\":[", .{wi + 1});
            for (shown.items, 0..) |r, i| {
                if (i > 0) try out.writeByte(',');
                try O.itemJson(out, &w, W.item(&w, r).*, v);
            }
            try out.writeAll("]}");
        } else {
            if (o.format == .text) try out.print("ondata {d}\n", .{wi + 1});
            for (shown.items) |r| {
                const it = W.item(&w, r).*;
                if (o.format == .ids) try out.print("{s}\n", .{it.id}) else {
                    try out.writeAll("  ");
                    try O.itemText(out, &w, it, .{ .brief = true });
                    if (O.fieldValue(it, "mode")) |m| try out.print("  [{s}]", .{m});
                    try out.writeByte('\n');
                }
            }
        }
        first = false;
    }
    if (o.format == .json) {
        try out.writeAll("],\"unscheduled\":[");
        for (wv.rest, 0..) |r, i| {
            if (i > 0) try out.writeByte(',');
            try O.jstr(out, W.item(&w, r).id);
        }
        try out.writeAll("]}\n");
    } else if (wv.rest.len > 0) try out.print("non pianificabili (cicli): {d}\n", .{wv.rest.len});
}

// ------------------------------------------------------------ sezioni e metadati degli step

const Doc = struct {
    lines: std.ArrayList([]const u8) = .empty,
    final_newline: bool = true,
    step: ?usize = null,
    path: []const u8 = "",
    entry: bool = false,
};

fn splitInto(a: std.mem.Allocator, doc: *Doc, data: []const u8) !void {
    doc.final_newline = data.len == 0 or data[data.len - 1] == '\n';
    const body = if (data.len > 0 and doc.final_newline) data[0 .. data.len - 1] else data;
    if (data.len == 0) return;
    var sp = std.mem.splitScalar(u8, body, '\n');
    while (sp.next()) |l| try doc.lines.append(a, l);
}

fn openDoc(a: std.mem.Allocator, w: *const W.Work, target: []const u8) !Doc {
    var doc: Doc = .{};
    const named: ?[]const u8 = if (std.ascii.eqlIgnoreCase(target, "plan")) "plan.md" else if (std.ascii.eqlIgnoreCase(target, "entrypoint") or std.ascii.eqlIgnoreCase(target, "entry")) "entrypoint.md" else null;
    if (named) |fname| {
        doc.path = try std.fs.path.join(a, &.{ w.dir, fname });
        doc.entry = std.mem.eql(u8, fname, "entrypoint.md");
        const data = rt.readFileAlloc(a, doc.path, 16 * 1024 * 1024) catch |e| switch (e) {
            error.FileNotFound => return fail("{s} non esiste", .{doc.path}),
            else => return e,
        };
        try splitInto(a, &doc, data);
        return doc;
    }
    const si = W.findStep(w, target) orelse return fail("'{s}' non è uno step (vedi `wk steps`) né `plan` / `entrypoint`", .{target});
    doc.step = si;
    doc.lines = w.steps[si].lines;
    return doc;
}

fn readStdin(a: std.mem.Allocator) ![]const u8 {
    var buf: [4096]u8 = undefined;
    var rd = rt.File.stdin().readerStreaming(rt.io, &buf);
    return rd.interface.allocRemaining(a, .limited(4 * 1024 * 1024));
}

fn cmdSection(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    if (o.pos.items.len < 2) return fail("uso: wk section ls|get|set TARGET [\"Titolo\" [testo|-]] (vedi `wk section --help`)", .{});
    const sub = o.pos.items[0];
    const target = o.pos.items[1];
    var doc = try openDoc(c.a, &w, target);
    const out = c.out;

    if (std.mem.eql(u8, sub, "ls")) {
        const ts = try Sec.titles(c.a, doc.lines.items);
        if (o.format != .json) {
            for (ts) |t| try out.print("{s}\n", .{t});
            return;
        }
        try out.writeAll("{\"target\":");
        try O.jstr(out, target);
        try out.writeAll(",\"sections\":[");
        for (ts, 0..) |t, i| {
            if (i > 0) try out.writeByte(',');
            try O.jstr(out, t);
        }
        try out.writeAll("]}\n");
        return;
    }
    if (o.pos.items.len < 3) return fail("manca il titolo della sezione (vedi `wk section ls {s}`)", .{target});
    const title = W.trim(o.pos.items[2]);

    if (std.mem.eql(u8, sub, "get")) {
        const sp = Sec.find(doc.lines.items, title) orelse return fail("sezione '{s}' non trovata in {s} (vedi `wk section ls {s}`)", .{ title, target, target });
        const b = Sec.body(doc.lines.items, sp);
        if (o.format != .json) {
            for (b) |l| try out.print("{s}\n", .{l});
            return;
        }
        var buf: std.ArrayList(u8) = .empty;
        for (b, 0..) |l, i| {
            if (i > 0) try buf.append(c.a, '\n');
            try buf.appendSlice(c.a, l);
        }
        try out.writeAll("{\"title\":");
        try O.jstr(out, doc.lines.items[sp.start][3..]);
        try out.writeAll(",\"body\":");
        try O.jstr(out, buf.items);
        try out.writeAll("}\n");
        return;
    }
    if (!std.mem.eql(u8, sub, "set")) return fail("sottocomando '{s}': usa ls, get o set", .{sub});
    if (std.ascii.startsWithIgnoreCase(title, "checklist")) return fail("la checklist non si scrive come testo: usa add, check, edit, set, tag…", .{});
    if (doc.entry and std.ascii.eqlIgnoreCase(title, "current task")) return fail("'Current task' si gestisce con `wk entry set` e `wk sync`", .{});
    if (o.pos.items.len < 4) return fail("manca il testo (o `-` per leggerlo da stdin)", .{});
    var text: []const u8 = undefined;
    if (o.pos.items.len == 4 and std.mem.eql(u8, o.pos.items[3], "-")) {
        text = try readStdin(c.a);
    } else {
        var b: std.ArrayList(u8) = .empty;
        for (o.pos.items[3..], 0..) |p, i| {
            if (i > 0) try b.append(c.a, ' ');
            try b.appendSlice(c.a, p);
        }
        text = b.items;
    }
    if (W.trim(text).len == 0) return fail("testo vuoto", .{});
    if (std.mem.indexOf(u8, text, "\n## ") != null or std.mem.startsWith(u8, text, "## ")) return fail("il testo contiene intestazioni '## ': crea sezioni separate con più `wk section set`", .{});
    const nl = try Sec.replace(c.a, doc.lines.items, title, text);
    if (doc.step) |si| {
        const step = &w.steps[si];
        var al: std.ArrayList([]const u8) = .empty;
        try al.appendSlice(c.a, nl);
        step.lines = al;
        step.dirty = true;
        try W.parseStep(c.a, step);
        try W.save(c.a, &w);
    } else {
        try W.writeFileAtomic(c.a, doc.path, nl, doc.final_newline);
    }
    try out.writeAll("{\"changed\":true}\n");
}

fn cmdStepSet(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    if (o.pos.items.len != 1) return fail("uso: wk step-set STEP [--title T] [--phase F] [--prereq P]", .{});
    const si = W.findStep(&w, o.pos.items[0]) orelse return fail("step '{s}' non trovato (vedi `wk steps`)", .{o.pos.items[0]});
    if (o.title == null and o.phase == null and o.prereq == null) return fail("indica almeno uno tra --title, --phase, --prereq", .{});
    const step = &w.steps[si];
    if (o.title) |t| {
        try noNewline(t, "--title");
        try W.setTitle(c.a, step, W.trim(t));
    }
    if (o.phase) |t| {
        try noNewline(t, "--phase");
        try W.setMeta(c.a, step, "Fase del piano", W.trim(t));
    }
    if (o.prereq) |t| {
        try noNewline(t, "--prereq");
        try W.setMeta(c.a, step, "Prerequisiti", W.trim(t));
    }
    try commit(c, &w, o);
    try c.out.writeAll("{\"step\":");
    try O.jstr(c.out, step.key);
    try c.out.writeAll(",\"title\":");
    try O.jstr(c.out, step.title);
    try c.out.writeAll("}\n");
}


// ------------------------------------------------------------ versione documenti e migrazioni

fn cmdVersion(c: Ctx, o: *const Opts) !void {
    if (o.format == .text) {
        try c.out.print("wk {s} ({s}) · formato documenti {d}\n", .{ BO.version, BO.commit, F.current });
        for (F.migrations) |m| try c.out.print("  {d} → {d}: {s}\n", .{ m.from, m.to, m.summary });
        return;
    }
    try c.out.print("{{\"tool\":\"{s}\",\"commit\":\"{s}\",\"format\":{d},\"migrations\":[", .{ BO.version, BO.commit, F.current });
    for (F.migrations, 0..) |m, i| {
        if (i > 0) try c.out.writeByte(',');
        try c.out.print("{{\"from\":{d},\"to\":{d},\"summary\":", .{ m.from, m.to });
        try O.jstr(c.out, m.summary);
        try c.out.writeByte('}');
    }
    try c.out.writeAll("]}\n");
}

fn cmdMigrate(c: Ctx, o: *const Opts) !void {
    var w = try loadWorkRaw(c.a, o);
    var entry = (try E.Entry.load(c.a, w.dir)) orelse return fail("manca {s}/entrypoint.md: la versione dei documenti si dichiara lì", .{w.dir});
    const actual = entry.formatVersion() orelse 0;
    const from = o.from orelse return fail("indica --from N con la versione letta dall'entrypoint (`wk entry get` → format.work; qui è {d})", .{actual});
    if (from != actual) return fail("--from {d} non corrisponde: l'entrypoint dichiara la versione {d}", .{ from, actual });
    if (actual > F.current) return fail("il work usa il formato {d}, ma questo wk arriva alla {d}: aggiorna wk", .{ actual, F.current });
    const out = c.out;
    if (actual == F.current) {
        try out.print("{{\"changed\":false,\"format\":{d}}}\n", .{actual});
        return;
    }
    try out.print("{{\"from\":{d},\"to\":{d},\"dry_run\":{s},\"applied\":[", .{ actual, F.current, if (o.dry_run) "true" else "false" });
    var v = actual;
    var first = true;
    while (v < F.current) {
        const m = F.find(v) orelse return fail("nessuna migrazione dalla versione {d}", .{v});
        const rep = try F.apply(c.a, &w, &entry, m, o.dry_run);
        if (!first) try out.writeByte(',');
        first = false;
        try out.print("{{\"from\":{d},\"to\":{d},\"summary\":", .{ rep.from, rep.to });
        try O.jstr(out, rep.summary);
        try out.print(",\"assigned_ids\":{d},\"sync_changes\":{d}}}", .{ rep.assigned_ids, rep.sync_changes });
        v = m.to;
    }
    try out.writeAll("],\"next\":\"wk validate\"}\n");
    if (!o.dry_run) {
        try W.save(c.a, &w);
        try entry.save(c.a);
    }
}


// ------------------------------------------------------------ automazione e deleghe

fn joinArgs(a: std.mem.Allocator, items: []const []const u8) ![]const u8 {
    var b: std.ArrayList(u8) = .empty;
    for (items, 0..) |p, i| {
        if (i > 0) try b.append(a, ' ');
        try b.appendSlice(a, p);
    }
    return b.items;
}

fn splitOptions(a: std.mem.Allocator, v: ?[]const u8) !List {
    var l: List = .empty;
    if (v) |x| {
        var sp = std.mem.splitSequence(u8, x, " | ");
        while (sp.next()) |t| if (W.trim(t).len > 0) try l.append(a, W.trim(t));
    }
    return l;
}

fn cmdHold(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    if (o.pos.items.len < 2) return fail("uso: wk hold ID \"domanda\" [--option X]… [--default X] (vedi `wk hold --help`)", .{});
    const id = o.pos.items[0];
    const r = try needItem(&w, id);
    var it = W.item(&w, r).*;
    if (it.done) return fail("{s} è già completata", .{id});
    const q = W.trim(try joinArgs(c.a, o.pos.items[1..]));
    if (q.len == 0) return fail("domanda vuota", .{});
    try noNewline(q, "domanda");
    for (o.options.items) |op| {
        try noNewline(op, "--option");
        if (W.trim(op).len == 0) return fail("--option vuota", .{});
        if (std.mem.indexOf(u8, op, " | ") != null) return fail("--option non può contenere ' | '", .{});
    }
    if (o.options.items.len == 1) return fail("indica almeno due --option (oppure nessuna per una risposta libera)", .{});
    try checkLen("domanda", q, max_question);
    try putField(c.a, &it, "hold", q);
    if (o.options.items.len > 0) {
        var b: std.ArrayList(u8) = .empty;
        for (o.options.items, 0..) |op, k| try b.print(c.a, "{s}{s}", .{ if (k > 0) " | " else "", W.trim(op) });
        try putField(c.a, &it, "hold_options", b.items);
    } else try dropField(c.a, &it, "hold_options");
    if (o.default_answer) |d| {
        try noNewline(d, "--default");
        try putField(c.a, &it, "hold_default", W.trim(d));
    } else try dropField(c.a, &it, "hold_default");
    // una nuova domanda sostituisce l'eventuale risposta precedente
    try dropField(c.a, &it, "answer");
    try dropField(c.a, &it, "asked");
    try dropField(c.a, &it, "answered_at");
    try dropField(c.a, &it, "claimed_by");
    try W.commitItem(c.a, &w, r, it);
    try W.save(c.a, &w);
    try printWith(c, &w, &.{id}, o, "id,hold,hold_options,hold_default");
}

/// Registra la risposta a una voce in attesa (non salva: lo fa il chiamante).
fn resolveItem(a: std.mem.Allocator, w: *const W.Work, id: []const u8, ans: []const u8) !void {
    const r = W.findItem(w, id).?;
    var it = W.item(w, r).*;
    const q = O.fieldValue(it, "hold").?;
    try putField(a, &it, "asked", q);
    try putField(a, &it, "answer", ans);
    try putField(a, &it, "answered_at", try nowIso(a));
    try dropField(a, &it, "hold");
    try dropField(a, &it, "hold_options");
    try dropField(a, &it, "hold_default");
    try W.commitItem(a, w, r, it);
}

fn cmdResolve(c: Ctx, o: *const Opts) !void {
    var w = try loadWork(c.a, o);
    if (o.pos.items.len < 2) return fail("uso: wk resolve ID \"risposta\"", .{});
    const id = o.pos.items[0];
    const r = try needItem(&w, id);
    const it = W.item(&w, r).*;
    if (O.fieldValue(it, "hold") == null) return fail("{s} non è in attesa di risposta (vedi `wk questions`)", .{id});
    const ans = W.trim(try joinArgs(c.a, o.pos.items[1..]));
    if (ans.len == 0) return fail("risposta vuota", .{});
    try noNewline(ans, "risposta");
    try resolveItem(c.a, &w, id, ans);
    try W.save(c.a, &w);
    try printWith(c, &w, &.{id}, o, "id,asked,answer");
}

fn cmdQuestions(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    var o2 = o.*;
    o2.held = true;
    const refs = try collect(c.a, &w, &o2, false);
    const out = c.out;
    if (o.format != .json) {
        for (refs) |r| {
            const it = W.item(&w, r).*;
            if (o.format == .ids) {
                try out.print("{s}\n", .{it.id});
                continue;
            }
            try out.print("{s}  {s}\n   ? {s}\n", .{ it.id, it.label, O.fieldValue(it, "hold").? });
            const opts = try splitOptions(c.a, O.fieldValue(it, "hold_options"));
            for (opts.items, 0..) |op, k| try out.print("     {d}) {s}\n", .{ k + 1, op });
            if (O.fieldValue(it, "hold_default")) |d| try out.print("     proposta: {s}\n", .{d});
        }
        return;
    }
    try out.print("{{\"count\":{d},\"questions\":[", .{refs.len});
    for (refs, 0..) |r, i| {
        const it = W.item(&w, r).*;
        if (i > 0) try out.writeByte(',');
        try out.writeAll("{\"id\":");
        try O.jstr(out, it.id);
        try out.writeAll(",\"step\":");
        try O.jstr(out, w.steps[it.step].key);
        try out.writeAll(",\"label\":");
        try O.jstr(out, it.label);
        try out.writeAll(",\"question\":");
        try O.jstr(out, O.fieldValue(it, "hold").?);
        try out.writeAll(",\"options\":[");
        const opts = try splitOptions(c.a, O.fieldValue(it, "hold_options"));
        for (opts.items, 0..) |op, k| {
            if (k > 0) try out.writeByte(',');
            try O.jstr(out, op);
        }
        try out.writeByte(']');
        if (O.fieldValue(it, "hold_default")) |d| {
            try out.writeAll(",\"default\":");
            try O.jstr(out, d);
        }
        try out.writeByte('}');
    }
    try out.writeAll("]}\n");
}

fn unlockWork() void {
    if (g_lock_dir) |*d| {
        d.close(rt.io);
        g_lock_dir = null;
    }
}

fn allDigits(t: []const u8) bool {
    if (t.len == 0) return false;
    for (t) |ch| if (!std.ascii.isDigit(ch)) return false;
    return true;
}

/// wk reply: risposte alle domande in attesa. Con argomenti ID "risposta"… registra (per gli agenti);
/// senza argomenti è interattivo (per l'utente, richiede un terminale), una domanda alla volta.
fn cmdReply(c: Ctx, o: *const Opts) !void {
    const dir = try resolveWork(c.a, o);
    const out = c.out;

    if (o.pos.items.len > 0) {
        if (o.pos.items.len % 2 != 0) return fail("uso: wk reply ID \"risposta\" [ID \"risposta\"…] (oppure senza argomenti, in un terminale, per rispondere una alla volta)", .{});
        try lockWork(dir);
        defer unlockWork();
        var w = try W.load(c.a, dir);
        var k: usize = 0;
        while (k < o.pos.items.len) : (k += 2) {
            const id = o.pos.items[k];
            const ans = W.trim(o.pos.items[k + 1]);
            const r = try needItem(&w, id);
            const it = W.item(&w, r).*;
            if (O.fieldValue(it, "hold") == null) {
                if (O.fieldValue(it, "answer")) |prev| return fail("{s} non è in attesa: ha già la risposta \"{s}\" (nessuna modifica fatta)", .{ id, prev });
                return fail("{s} non è in attesa di risposta (vedi `wk questions`)", .{id});
            }
            if (ans.len == 0) return fail("risposta vuota per {s}", .{id});
            try noNewline(ans, "risposta");
        }
        k = 0;
        while (k < o.pos.items.len) : (k += 2) try resolveItem(c.a, &w, o.pos.items[k], W.trim(o.pos.items[k + 1]));
        try W.save(c.a, &w);
        try out.writeAll("{\"answered\":[");
        k = 0;
        while (k < o.pos.items.len) : (k += 2) {
            if (k > 0) try out.writeByte(',');
            try O.jstr(out, o.pos.items[k]);
        }
        try out.writeAll("]}\n");
        return;
    }

    const stdin = rt.File.stdin();
    if (!(stdin.isTty(rt.io) catch false)) return fail("`wk reply` senza risposte è interattivo e richiede un terminale: è pensato per l'utente. Un agente deve usare `wk questions` per leggere le domande e `wk reply ID \"risposta\" …` per registrare le risposte.", .{});

    const w0 = try W.load(c.a, dir);
    var ids: List = .empty;
    for (w0.steps) |st| for (st.items) |it| {
        if (it.done or O.fieldValue(it, "hold") == null) continue;
        if (o.id) |only| if (!std.mem.eql(u8, only, it.id)) continue;
        try ids.append(c.a, it.id);
    };
    if (ids.items.len == 0) {
        try out.writeAll(if (o.id != null) "Nessuna domanda in attesa per quell'ID.\n" else "Nessuna domanda in attesa.\n");
        return;
    }
    var ibuf: [4096]u8 = undefined;
    var rd = stdin.readerStreaming(rt.io, &ibuf);
    var answered: usize = 0;
    var skipped: usize = 0;
    try out.print("{d} domand{s} in attesa. Niente credenziali né dati personali nelle risposte.\n", .{ ids.items.len, if (ids.items.len == 1) "a" else "e" });
    for (ids.items, 0..) |id, n| {
        const w = try W.load(c.a, dir);
        const r = W.findItem(&w, id) orelse continue;
        const it = W.item(&w, r).*;
        const q = O.fieldValue(it, "hold") orelse {
            try out.print("\n[{d}/{d}] {s}: già risposta altrove, salto.\n", .{ n + 1, ids.items.len, id });
            continue;
        };
        const opts = try splitOptions(c.a, O.fieldValue(it, "hold_options"));
        const def = O.fieldValue(it, "hold_default");
        try out.print("\n[{d}/{d}] {s} · {s}\n{s}\n? {s}\n", .{ n + 1, ids.items.len, id, w.steps[it.step].key, it.label, q });
        for (opts.items, 0..) |op, k| try out.print("  {d}) {s}{s}\n", .{ k + 1, op, if (def != null and std.mem.eql(u8, def.?, op)) "  (proposta)" else "" });
        if (def != null and opts.items.len == 0) try out.print("  proposta: {s}\n", .{def.?});
        try out.print("Risposta [{s}{s}invio = salta, q = esci]: ", .{ if (opts.items.len > 0) "numero o testo, " else "testo, ", if (def != null) "d = proposta, " else "" });
        try out.flush();
        const line = rd.interface.takeDelimiterInclusive('\n') catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };
        const in = std.mem.trim(u8, line, " \t\r\n");
        if (in.len == 0) {
            skipped += 1;
            continue;
        }
        if (std.mem.eql(u8, in, "q")) break;
        var ans: []const u8 = in;
        if (std.mem.eql(u8, in, "d") and def != null) {
            ans = def.?;
        } else if (opts.items.len > 0 and allDigits(in)) {
            const num = std.fmt.parseInt(usize, in, 10) catch 0;
            if (num >= 1 and num <= opts.items.len) ans = opts.items[num - 1];
        }
        {
            try lockWork(dir);
            defer unlockWork();
            var w2 = try W.load(c.a, dir);
            const r2 = W.findItem(&w2, id) orelse continue;
            if (O.fieldValue(W.item(&w2, r2).*, "hold") == null) {
                try out.writeAll("  (nel frattempo ha già una risposta: non modifico)\n");
                continue;
            }
            try resolveItem(c.a, &w2, id, ans);
            try W.save(c.a, &w2);
        }
        answered += 1;
        try out.print("  ✓ registrata: {s}\n", .{ans});
    }
    try out.print("\nRegistrate {d}, saltate {d}.\n", .{ answered, skipped });
}

fn cmdClaim(c: Ctx, o: *const Opts, claim: bool) !void {
    var w = try loadWork(c.a, o);
    if (o.pos.items.len == 0) return fail("manca almeno un ID (vedi `wk {s} --help`)", .{if (claim) "claim" else "unclaim"});
    const by = W.trim(o.by orelse "agent");
    if (by.len == 0) return fail("--by vuoto", .{});
    try noNewline(by, "--by");
    for (o.pos.items) |id| {
        const r = try needItem(&w, id);
        if (!claim) continue;
        const it = W.item(&w, r).*;
        if (it.done) return fail("{s} è già completata", .{id});
        if (O.fieldValue(it, "hold") != null) return fail("{s} è in attesa di risposta (vedi `wk questions`)", .{id});
        const od = try G.openDeps(c.a, &w, it);
        if (od.len > 0) return fail("{s} ha dipendenze aperte: {s}", .{ id, try joinTags(c.a, od) });
        if (O.fieldValue(it, "claimed_by")) |cur| {
            if (!std.ascii.eqlIgnoreCase(cur, by)) return fail("{s} è già in carico a '{s}'", .{ id, cur });
        }
    }
    for (o.pos.items) |id| {
        const r = W.findItem(&w, id).?;
        var it = W.item(&w, r).*;
        if (claim) try putField(c.a, &it, "claimed_by", by) else try dropField(c.a, &it, "claimed_by");
        try W.commitItem(c.a, &w, r, it);
    }
    try W.save(c.a, &w);
    try printWith(c, &w, o.pos.items, o, "id,claimed_by");
}

fn cmdBrief(c: Ctx, o: *const Opts) !void {
    const w = try loadWork(c.a, o);
    if (o.pos.items.len == 0) return fail("manca almeno un ID (vedi `wk brief --help`)", .{});
    for (o.pos.items) |id| _ = try needItem(&w, id);
    const out = c.out;
    for (o.pos.items, 0..) |id, n| {
        const r = W.findItem(&w, id).?;
        const it = W.item(&w, r).*;
        const step = w.steps[it.step];
        if (n > 0) try out.writeAll("\n---\n\n");
        try out.print("# Delega {s} — {s}\n\n", .{ it.id, it.label });
        try out.print("Work: {s}  (usa sempre `wk -w {s} …`)\nStep: {s} — {s}\n", .{ w.dir, w.dir, step.key, step.title });
        const mode = O.fieldValue(it, "mode");
        try out.print("Classificazione: {s}", .{mode orelse "non classificata"});
        if (O.fieldValue(it, "mode_reason")) |mr| try out.print(" — {s}", .{mr});
        try out.writeByte('\n');
        if (it.tags.len > 0) try out.print("Tag: {s}\n", .{try joinTags(c.a, it.tags)});
        for (it.fields) |f| {
            if (std.ascii.eqlIgnoreCase(f.key, "mode") or std.ascii.eqlIgnoreCase(f.key, "mode_reason") or std.ascii.eqlIgnoreCase(f.key, "claimed_by")) continue;
            try out.print("{s}: {s}\n", .{ f.key, f.value });
        }
        for (it.notes) |nt| try out.print("Nota: {s}\n", .{nt});
        if (it.deps.len > 0) {
            try out.writeAll("\nDipendenze dirette (da cui parte il lavoro):\n");
            for (it.deps) |d| {
                const dr = W.findItem(&w, d) orelse {
                    try out.print("  - {s} (voce non trovata)\n", .{d});
                    continue;
                };
                const di = W.item(&w, dr).*;
                try out.print("  - {s} [{c}] {s}", .{ d, @as(u8, if (di.done) 'x' else ' '), di.label });
                if (O.fieldValue(di, "result")) |res| try out.print(" — esito: {s}", .{res});
                try out.writeByte('\n');
            }
        }
        const deps_on = try G.dependents(c.a, &w, it.id);
        if (deps_on.len > 0) {
            try out.writeAll("\nCompletandola sblocchi: ");
            for (deps_on, 0..) |dr, i| try out.print("{s}{s}", .{ if (i > 0) ", " else "", W.item(&w, dr).id });
            try out.writeByte('\n');
        }
        try out.print(
            \\
            \\## Regole
            \\- Lavori SOLO su questa voce ({s}). Non modificare altre voci né l'entrypoint.
            \\- Non fare domande all'utente: se serve una decisione o un'autorizzazione che non hai,
            \\  `wk -w {s} hold {s} "domanda"` e fermati.
            \\- Se emerge una dipendenza: `wk -w {s} dep add {s} DEP --reason "…"`; se serve il contesto
            \\  complessivo: `wk -w {s} classify {s} --mode integrated --reason "…"`. In entrambi i casi fermati e riporta.
            \\- Completa solo se hai verificato il risultato:
            \\  `wk -w {s} check {s} --result "esito breve e verificabile"`.
            \\- Risposta finale: cosa hai fatto, come l'hai verificato, file toccati, cosa deve sapere l'agente principale.
            \\
            \\## Contesto fornito dall'agente principale
            \\(da completare prima di avviare il sottoagente)
            \\
        , .{ id, w.dir, id, w.dir, id, w.dir, id, w.dir, id });
    }
}


// ------------------------------------------------------------ sessione automatica

const Counters = struct { open: usize = 0, done: usize = 0, avail: usize = 0, blocked: usize = 0, held: usize = 0, claimed: usize = 0, delegable: usize = 0, answered: usize = 0 };

fn computeCounters(w: *const W.Work) Counters {
    var c: Counters = .{};
    for (w.steps) |s| for (s.items) |it| {
        if (it.done) {
            c.done += 1;
            continue;
        }
        c.open += 1;
        const cn = G.counts(w, it);
        const blk = cn.total - cn.done > 0;
        const held = O.fieldValue(it, "hold") != null;
        const claimed = O.fieldValue(it, "claimed_by") != null;
        if (blk) c.blocked += 1;
        if (held) c.held += 1;
        if (claimed) c.claimed += 1;
        if (!held and O.fieldValue(it, "answer") != null) c.answered += 1;
        if (!blk and !held and !claimed) {
            c.avail += 1;
            if (O.fieldValue(it, "mode")) |m| if (std.ascii.eqlIgnoreCase(m, "isolated")) {
                c.delegable += 1;
            };
        }
    };
    return c;
}

const session_label = "Sessione automatica";
const Session = struct { started: []const u8, baseline: i64, limit: i64, wait_min: i64 = 0, used_s: i64 = 0, delegate: bool = false };

/// `avviata 2026-11-04T12:30:00Z; baseline 47; limite 100; stop a 147; attesa 30; usata 120`
fn parseSession(v: []const u8) ?Session {
    var s: Session = .{ .started = "", .baseline = -1, .limit = -1 };
    var it = std.mem.splitScalar(u8, v, ';');
    while (it.next()) |part| {
        const t = W.trim(part);
        if (std.mem.startsWith(u8, t, "avviata ")) {
            s.started = W.trim(t["avviata ".len..]);
        } else if (std.mem.startsWith(u8, t, "baseline ")) {
            s.baseline = std.fmt.parseInt(i64, W.trim(t["baseline ".len..]), 10) catch return null;
        } else if (std.mem.startsWith(u8, t, "limite ")) {
            s.limit = std.fmt.parseInt(i64, W.trim(t["limite ".len..]), 10) catch return null;
        } else if (std.mem.startsWith(u8, t, "attesa ")) {
            s.wait_min = std.fmt.parseInt(i64, W.trim(t["attesa ".len..]), 10) catch 0;
        } else if (std.mem.eql(u8, t, "deleghe")) {
            s.delegate = true;
        } else if (std.mem.startsWith(u8, t, "usata ")) {
            s.used_s = std.fmt.parseInt(i64, W.trim(t["usata ".len..]), 10) catch 0;
        }
    }
    if (s.baseline < 0 or s.limit < 0) return null;
    return s;
}

fn fmtSession(a: std.mem.Allocator, s: Session) ![]const u8 {
    return std.fmt.allocPrint(a, "avviata {s}; baseline {d}; limite {d}; stop a {d}; attesa {d}; usata {d}{s}", .{ s.started, s.baseline, s.limit, s.baseline + s.limit, s.wait_min, s.used_s, if (s.delegate) "; deleghe" else "" });
}

fn nowIso(a: std.mem.Allocator) ![]const u8 {
    const secs: u64 = @intCast(@divFloor(rt.nowMs(), 1000));
    const es = std.time.epoch.EpochSeconds{ .secs = secs };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    return std.fmt.allocPrint(a, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{ yd.year, md.month.numeric(), @as(u32, md.day_index) + 1, ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute() });
}

const Eval = struct { cont: bool, reason: []const u8, hint: []const u8, completed: i64, wait_left_s: i64 };

fn evalSession(cn: Counters, sess: Session) Eval {
    const completed: i64 = @as(i64, @intCast(cn.done)) - sess.baseline;
    const left = sess.wait_min * 60 - sess.used_s;
    var reason: []const u8 = "ok";
    if (completed >= sess.limit) {
        reason = "limit_reached";
    } else if (cn.avail == 0) {
        reason = if (cn.held > 0) (if (left > 0) "waiting_for_answers" else "ask_user") else "nothing_available";
    }
    const cont = std.mem.eql(u8, reason, "ok") or std.mem.eql(u8, reason, "waiting_for_answers") or std.mem.eql(u8, reason, "ask_user");
    const hint: []const u8 = if (std.mem.eql(u8, reason, "ok"))
        (if (sess.delegate and cn.delegable > 0) "DELEGA ORA: ci sono voci isolated sbloccate (`wk list --delegable`): `wk claim ID --by subN`, `wk brief ID`, avvia i sottoagenti in background (max come da \"Politica deleghe\") e nel frattempo lavora le voci integrated; esiti: `wk check` dopo la tua revisione" else if (sess.delegate and cn.claimed > 0 and cn.avail == 0) "voci in carico ai sottoagenti: attendi gli esiti, rivedili e `wk check`" else if (cn.answered > 0) "ci sono risposte dell'utente da riprendere: `wk next` le restituisce per prime" else "prosegui con `wk next`: chiudere uno step o un traguardo non è uno stop")
    else if (std.mem.eql(u8, reason, "waiting_for_answers"))
        "nulla da fare finché l'utente non risponde dalla dashboard: `wk auto wait --timeout 120` (poi di nuovo `wk auto status`)"
    else if (std.mem.eql(u8, reason, "ask_user"))
        "non resta altro da fare: presenta ORA le domande in chat con lo strumento nativo (`wk questions`), registra con `wk reply ID \"risposta\" …` e riprendi (vedi `wk help auto`)"
    else if (std.mem.eql(u8, reason, "limit_reached"))
        "scrivi il resoconto e chiudi con `wk auto stop`"
    else if (cn.held > 0)
        "wk questions"
    else if (cn.claimed > 0)
        "attendi i sottoagenti (wk list --claimed)"
    else if (cn.blocked > 0)
        "wk list --blocked"
    else
        "";
    return .{ .cont = cont, .reason = reason, .hint = hint, .completed = completed, .wait_left_s = if (left > 0) left else 0 };
}

fn answeredIds(a: std.mem.Allocator, w: *const W.Work) ![]const []const u8 {
    var l: List = .empty;
    for (w.steps) |st| for (st.items) |it| {
        if (!it.done and O.fieldValue(it, "hold") == null and O.fieldValue(it, "answer") != null) try l.append(a, it.id);
    };
    return l.items;
}

fn printStatus(c: Ctx, o: *const Opts, w: *const W.Work, cn: Counters, sess: Session, ev: Eval, waited_s: ?i64) !void {
    const out = c.out;
    if (o.format == .text) {
        try out.print("{s} ({s}): completate {d}/{d}, disponibili {d}, bloccate {d}, in attesa {d}, in carico {d}, risposte da riprendere {d}{s}{s}\n", .{ if (ev.cont) "continua" else "stop", ev.reason, ev.completed, sess.limit, cn.avail, cn.blocked, cn.held, cn.claimed, cn.answered, if (ev.hint.len > 0) " — " else "", ev.hint });
        return;
    }
    try out.print("{{\"active\":true,\"continue\":{s},\"reason\":\"{s}\",\"completed\":{d},\"limit\":{d},\"remaining\":{d},\"available\":{d},\"blocked\":{d},\"held\":{d},\"claimed\":{d},\"delegate\":{s},\"delegable\":{d},\"answered\":{d},\"answered_ids\":[", .{ if (ev.cont) "true" else "false", ev.reason, ev.completed, sess.limit, sess.limit - ev.completed, cn.avail, cn.blocked, cn.held, cn.claimed, if (sess.delegate) "true" else "false", cn.delegable, cn.answered });
    const ids = try answeredIds(c.a, w);
    for (ids[0..@min(10, ids.len)], 0..) |id, i| {
        if (i > 0) try out.writeByte(',');
        try O.jstr(out, id);
    }
    try out.print("],\"wait_left_s\":{d},\"started\":\"{s}\"", .{ ev.wait_left_s, sess.started });
    if (waited_s) |ws| try out.print(",\"waited_s\":{d}", .{ws});
    try out.writeAll(",\"hint\":");
    try O.jstr(out, ev.hint);
    try out.writeAll("}\n");
}

/// Attende (a polling sui file) che una voce diventi disponibile, entro --timeout e il budget di attesa della sessione.
fn cmdAutoWait(c: Ctx, o: *const Opts) !u8 {
    const dir = try resolveWork(c.a, o);
    const timeout_s: i64 = @min(@as(i64, o.timeout orelse 60), 3600);
    const start_ms = rt.nowMs();
    var budget_left: i64 = 0;
    {
        const a0 = c.a;
        const e0 = (try E.Entry.load(a0, dir)) orelse return fail("serve {s}/entrypoint.md", .{dir});
        const sess0 = (if (e0.get(session_label)) |v| parseSession(v) else null) orelse return fail("nessuna sessione automatica attiva (`wk auto start --limit N --wait MINUTI`)", .{});
        if (sess0.wait_min == 0) return fail("la sessione non prevede attese dalla dashboard: se non resta altro da fare, presenta le domande in chat (`wk auto status`, `wk help auto`)", .{});
        budget_left = sess0.wait_min * 60 - sess0.used_s;
        if (budget_left <= 0) return fail("budget di attesa esaurito ({d} minuti): non attendere oltre, presenta le domande in chat (`wk auto status`, `wk help auto`)", .{sess0.wait_min});
    }
    const cap = @min(timeout_s, budget_left);
    while (true) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const w = W.load(arena.allocator(), dir) catch break;
        const cn = computeCounters(&w);
        const elapsed = @divFloor(rt.nowMs() - start_ms, 1000);
        if (cn.avail > 0 or elapsed >= cap) break;
        const left_ms: u64 = @intCast(@max(0, cap * 1000 - (rt.nowMs() - start_ms)));
        rt.sleepMs(@min(left_ms, 1000));
    }
    const waited = @divFloor(rt.nowMs() - start_ms, 1000);
    // aggiorna il tempo di attesa usato, sotto lock e sui dati freschi
    try lockWork(dir);
    defer unlockWork();
    const w = try W.load(c.a, dir);
    var entry = (try E.Entry.load(c.a, dir)).?;
    var sess = parseSession(entry.get(session_label) orelse "") orelse return fail("sessione non leggibile", .{});
    sess.used_s += waited;
    _ = try entry.set(c.a, session_label, try fmtSession(c.a, sess), "Avanzamento");
    try entry.save(c.a);
    const cn = computeCounters(&w);
    const ev = evalSession(cn, sess);
    try printStatus(c, o, &w, cn, sess, ev, waited);
    return if (o.exit_code and !ev.cont) 3 else 0;
}

fn cmdAuto(c: Ctx, o: *const Opts) !u8 {
    const sub = if (o.pos.items.len > 0) o.pos.items[0] else "status";
    if (std.mem.eql(u8, sub, "wait")) return cmdAutoWait(c, o);
    const is_start = std.mem.eql(u8, sub, "start");
    const is_stop = std.mem.eql(u8, sub, "stop");
    if (!is_start and !is_stop and !std.mem.eql(u8, sub, "status")) return fail("sottocomando '{s}': usa start, status, wait o stop (vedi `wk help auto`)", .{sub});
    const w = try loadWork(c.a, o);
    var entry = (try E.Entry.load(c.a, w.dir)) orelse return fail("serve {s}/entrypoint.md: la sessione si registra lì", .{w.dir});
    const cn = computeCounters(&w);
    const raw = entry.get(session_label);
    const existing = if (raw) |v| parseSession(v) else null;
    const out = c.out;

    if (is_start) {
        if (raw != null and !o.force) {
            if (existing) |ex| return fail("c'è già una sessione registrata (avviata {s}, baseline {d}, limite {d}). Non riprenderla senza una richiesta esplicita dell'utente: `wk auto status` per vederla, `wk auto stop` per chiuderla, `--force` per ricominciare.", .{ ex.started, ex.baseline, ex.limit });
            return fail("il campo '{s}' esiste ma non è leggibile: usa --force per riscriverlo o `wk auto stop` per toglierlo", .{session_label});
        }
        const limit = o.limit orelse return fail("indica --limit N: quante voci completare in questa sessione (se l'utente non l'ha detto, chiediglielo prima di iniziare)", .{});
        if (limit == 0) return fail("--limit deve essere maggiore di zero", .{});
        const started = try nowIso(c.a);
        const sess: Session = .{ .started = started, .baseline = @intCast(cn.done), .limit = @intCast(limit), .wait_min = o.wait_min orelse 0, .used_s = 0, .delegate = o.delegate };
        _ = entry.set(c.a, session_label, try fmtSession(c.a, sess), "Avanzamento") catch |e| switch (e) {
            error.NoSection => return fail("entrypoint.md non ha la sezione '## Current task'", .{}),
            else => return e,
        };
        try entry.save(c.a);
        try out.print("{{\"active\":true,\"started\":\"{s}\",\"baseline\":{d},\"limit\":{d},\"stop_at\":{d},\"wait_min\":{d},\"delegate\":{s},\"available\":{d},\"delegable\":{d}}}\n", .{ started, cn.done, limit, cn.done + limit, sess.wait_min, if (sess.delegate) "true" else "false", cn.avail, cn.delegable });
        return 0;
    }

    if (is_stop) {
        if (raw == null) {
            try out.writeAll("{\"stopped\":false}\n");
            return 0;
        }
        const completed: i64 = if (existing) |ex| @as(i64, @intCast(cn.done)) - ex.baseline else 0;
        if (existing) |ex| {
            const ev = evalSession(cn, ex);
            if (ev.cont and !o.force) return fail("stop rifiutato: nessuna condizione di stop (reason \"{s}\", completate {d}/{d}, disponibili {d}). Completare uno step o chiudere un traguardo NON è uno stop: continua con `wk next`. `--force` solo se l'utente ti ha chiesto di fermarti, ha rimandato le domande o c'è un errore bloccante che non sai aggirare.", .{ ev.reason, ev.completed, ex.limit, cn.avail });
        }
        _ = try entry.unset(c.a, session_label);
        try entry.save(c.a);
        try out.print("{{\"stopped\":true,\"completed\":{d},\"started\":\"{s}\"}}\n", .{ completed, if (existing) |ex| ex.started else "" });
        return 0;
    }

    const sess = existing orelse {
        if (o.format == .text) {
            try out.writeAll("nessuna sessione automatica attiva (avviala con: wk auto start --limit N)\n");
        } else {
            try out.print("{{\"active\":false,\"continue\":false,\"reason\":\"{s}\",\"hint\":\"wk auto start --limit N\"}}\n", .{if (raw != null) "unreadable_session" else "no_session"});
        }
        return if (o.exit_code) 3 else 0;
    };
    const ev = evalSession(cn, sess);
    try printStatus(c, o, &w, cn, sess, ev, null);
    return if (o.exit_code and !ev.cont) 3 else 0;
}

fn helpFor(cmd: []const u8) ?[]const u8 {
    const m = std.StaticStringMap([]const u8).initComptime(.{
        .{ "list", H.cmd_list },       .{ "get", H.cmd_get },         .{ "next", H.cmd_next },
        .{ "steps", H.cmd_steps },     .{ "tags", H.cmd_tags }, .{ "keys", H.cmd_keys }, .{ "classify", H.cmd_classify }, .{ "hold", H.cmd_hold }, .{ "resolve", H.cmd_hold }, .{ "questions", H.cmd_hold }, .{ "reply", H.cmd_reply }, .{ "claim", H.cmd_claim }, .{ "unclaim", H.cmd_claim }, .{ "brief", H.cmd_brief }, .{ "auto", H.auto }, .{ "version", H.cmd_version }, .{ "migrate", H.cmd_migrate }, .{ "dep", H.cmd_dep }, .{ "deps", H.cmd_deps }, .{ "waves", H.cmd_waves }, .{ "section", H.cmd_section }, .{ "plan", H.cmd_plan }, .{ "hook", H.cmd_hook }, .{ "step-set", H.cmd_step_set }, .{ "delegation", H.delegation }, .{ "output", H.output },       .{ "add", H.cmd_add },
        .{ "check", H.cmd_check },     .{ "uncheck", H.cmd_check },   .{ "edit", H.cmd_edit },
        .{ "set", H.cmd_set },         .{ "unset", H.cmd_set },       .{ "tag", H.cmd_tag },
        .{ "rm", H.cmd_rm },           .{ "assign-ids", H.cmd_assign }, .{ "validate", H.cmd_validate },
        .{ "new-step", H.cmd_new_step }, .{ "sync", H.cmd_sync }, .{ "step-status", H.cmd_step_status }, .{ "entry", H.cmd_entry }, .{ "init", H.cmd_init },     .{ "format", H.format },
        .{ "filters", H.filters },
    });
    return m.get(cmd);
}

fn run(c: Ctx, args: []const []const u8) !u8 {
    if (args.len < 2) {
        try c.out.writeAll(H.main);
        return 0;
    }
    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
        if (args.len >= 3) {
            if (helpFor(args[2])) |t| {
                try c.out.writeAll(t);
                return 0;
            }
            return fail("nessun aiuto per '{s}'", .{args[2]});
        }
        try c.out.writeAll(H.main);
        return 0;
    }
    if (std.mem.eql(u8, cmd, "--version")) {
        try c.out.print("wk {s} ({s}) · formato documenti {d}\n", .{ BO.version, BO.commit, F.current });
        return 0;
    }
    const o = try parseOpts(c.a, cmd, args[2..]);
    g_lock = needsLock(cmd, &o);
    if (o.help) {
        try c.out.writeAll(helpFor(cmd) orelse H.main);
        if (std.mem.eql(u8, cmd, "list") or std.mem.eql(u8, cmd, "next")) try c.out.writeAll("\n" ++ H.filters);
        return 0;
    }
    const eq = std.mem.eql;
    if (eq(u8, cmd, "steps")) try cmdSteps(c, &o)
    else if (eq(u8, cmd, "list")) try cmdList(c, &o, false)
    else if (eq(u8, cmd, "next")) try cmdList(c, &o, true)
    else if (eq(u8, cmd, "get")) try cmdGet(c, &o)
    else if (eq(u8, cmd, "tags")) try cmdTags(c, &o)
    else if (eq(u8, cmd, "keys")) try cmdKeys(c, &o)
    else if (eq(u8, cmd, "add")) try cmdAdd(c, &o)
    else if (eq(u8, cmd, "check")) try setDone(c, &o, true, "check")
    else if (eq(u8, cmd, "uncheck")) try setDone(c, &o, false, "uncheck")
    else if (eq(u8, cmd, "edit")) try cmdEdit(c, &o)
    else if (eq(u8, cmd, "set")) try cmdSet(c, &o)
    else if (eq(u8, cmd, "unset")) try cmdUnset(c, &o)
    else if (eq(u8, cmd, "tag")) try cmdTag(c, &o)
    else if (eq(u8, cmd, "rm")) try cmdRm(c, &o)
    else if (eq(u8, cmd, "assign-ids")) try cmdAssign(c, &o)
    else if (eq(u8, cmd, "validate")) return cmdValidate(c, &o)
    else if (eq(u8, cmd, "auto")) return cmdAuto(c, &o)
    else if (eq(u8, cmd, "new-step")) try cmdNewStep(c, &o)
    else if (eq(u8, cmd, "sync")) try cmdSync(c, &o)
    else if (eq(u8, cmd, "classify")) try cmdClassify(c, &o)
    else if (eq(u8, cmd, "hold")) try cmdHold(c, &o)
    else if (eq(u8, cmd, "resolve")) try cmdResolve(c, &o)
    else if (eq(u8, cmd, "questions")) try cmdQuestions(c, &o)
    else if (eq(u8, cmd, "reply")) try cmdReply(c, &o)
    else if (eq(u8, cmd, "claim")) try cmdClaim(c, &o, true)
    else if (eq(u8, cmd, "unclaim")) try cmdClaim(c, &o, false)
    else if (eq(u8, cmd, "brief")) try cmdBrief(c, &o)
    else if (eq(u8, cmd, "version")) try cmdVersion(c, &o)
    else if (eq(u8, cmd, "migrate")) try cmdMigrate(c, &o)
    else if (eq(u8, cmd, "dep")) try cmdDep(c, &o)
    else if (eq(u8, cmd, "deps")) try cmdDeps(c, &o)
    else if (eq(u8, cmd, "waves")) try cmdWaves(c, &o)
    else if (eq(u8, cmd, "section")) try cmdSection(c, &o)
    else if (eq(u8, cmd, "plan")) {
        var o2 = o;
        var pl: List = .empty;
        try pl.append(c.a, if (o.pos.items.len == 0) "ls" else "get");
        try pl.append(c.a, "plan");
        try pl.appendSlice(c.a, o.pos.items);
        o2.pos = pl;
        try cmdSection(c, &o2);
    }
    else if (eq(u8, cmd, "step-set")) try cmdStepSet(c, &o)
    else if (eq(u8, cmd, "step-status")) try cmdStepStatus(c, &o)
    else if (eq(u8, cmd, "entry")) try cmdEntry(c, &o)
    else if (eq(u8, cmd, "init")) try cmdInit(c, &o)
    else if (eq(u8, cmd, "hook")) return cmdHook(c, &o) catch 0
    else return fail("comando sconosciuto '{s}'. Prova `wk help`", .{cmd});
    return 0;
}

pub fn main(init: std.process.Init) !void {
    rt.io = init.io;
    g_env = init.environ_map;
    const a = init.arena.allocator();
    g_a = a;
    const raw_args = try init.minimal.args.toSlice(a);
    const args = try a.alloc([]const u8, raw_args.len);
    for (raw_args, 0..) |x, i| args[i] = x;

    var obuf: [16384]u8 = undefined;
    var ow = rt.File.stdout().writer(rt.io, &obuf);
    var ebuf: [1024]u8 = undefined;
    var ew = rt.File.stderr().writer(rt.io, &ebuf);

    const code: u8 = run(.{ .a = a, .out = &ow.interface }, args) catch |e| blk: {
        ow.interface.flush() catch {};
        if (e == error.User) {
            ew.interface.print("error: {s}\n", .{g_msg}) catch {};
        } else {
            ew.interface.print("errore interno: {s}\n", .{@errorName(e)}) catch {};
        }
        break :blk 1;
    };
    ow.interface.flush() catch {};
    for (g_warns.items) |m| ew.interface.print("avviso: {s}\n", .{m}) catch {};
    ew.interface.flush() catch {};
    std.process.exit(code);
}

test {
    _ = W;
    _ = E;
    _ = S;
    _ = @import("graph.zig");
    _ = F;
    _ = @import("section.zig");
}
