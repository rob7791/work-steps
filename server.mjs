#!/usr/bin/env node
// Work Steps — viewer di avanzamento per work con checklist markdown. Zero dipendenze.
import http from 'node:http';
import fs from 'node:fs/promises';
import { existsSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFile } from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 4317);
const OLD_CONFIG = path.join(os.homedir(), '.config', 'step-harness', 'config.json'); // nome precedente del progetto
const NEW_CONFIG = path.join(os.homedir(), '.config', 'work-steps', 'config.json');
const CONFIG = process.env.WORK_STEPS_CONFIG || process.env.STEP_HARNESS_CONFIG
  || (existsSync(NEW_CONFIG) || !existsSync(OLD_CONFIG) ? NEW_CONFIG : OLD_CONFIG);
const expand = p => p.replace(/^~(?=$|\/)/, os.homedir());

// ---------- config ----------
async function loadConfig() {
  try { return JSON.parse(await fs.readFile(CONFIG, 'utf8')); }
  catch { return { paths: [] }; } // nessun percorso predefinito: si configura da UI (⚙ Percorsi)
}
async function saveConfig(cfg) {
  await fs.mkdir(path.dirname(CONFIG), { recursive: true });
  await fs.writeFile(CONFIG, JSON.stringify(cfg, null, 2));
}

// ---------- parsing ----------
const exists = p => fs.stat(p).then(() => true, () => false);
const isDir = p => fs.stat(p).then(s => s.isDirectory(), () => false);

async function isWork(dir) {
  try {
    const names = await fs.readdir(dir);
    return names.includes('entrypoint.md') || names.some(n => /^tasks-.*\.md$/.test(n));
  } catch { return false; }
}

async function findWorks(root) {
  root = path.resolve(expand(root));
  if (!(await isDir(root))) return { root, missing: true, works: [] };
  const found = [];
  const scan = async base => {
    if (await isWork(base)) { found.push(base); return; }
    let ents = [];
    try { ents = await fs.readdir(base, { withFileTypes: true }); } catch {}
    for (const e of ents) if (e.isDirectory() && !e.name.startsWith('node_modules') && (!e.name.startsWith('.') || e.name === '.work'))
      if (base === root || e.name === '.work' || await isWork(path.join(base, e.name))) await scan(path.join(base, e.name));
  };
  await scan(root);
  if (!found.length && await isDir(path.join(root, '.work'))) await scan(path.join(root, '.work'));
  return { root, works: found };
}

const stripMd = s => s.replace(/\*\*|__|`/g, '').replace(/\[([^\]]+)\]\([^)]*\)/g, '$1').trim();

function parseMeta(lines) {
  const meta = {};
  for (const l of lines) {
    const m = l.match(/^\*\*(.+?):\*\*\s*(.*?)\s*$/);
    if (m) meta[m[1].toLowerCase()] = m[2].replace(/\\\s*$/, '').trim(); // `\` finale = a capo markdown
  }
  return meta;
}

// Divide il file in: titolo, meta, gruppi di checklist, note (resto).
function parseTaskFile(text, file) {
  const lines = text.split('\n');
  const title = stripMd((lines.find(l => /^#\s/.test(l)) || '# ' + file).replace(/^#\s+/, ''));
  const meta = parseMeta(lines.slice(0, 12));
  let section = null, group = null, inFence = false;
  const groups = [], notes = [];
  let cur = null, noteBuf = null;
  const flushNote = () => { if (noteBuf && noteBuf.body.join('\n').trim()) notes.push({ title: noteBuf.title, body: noteBuf.body.join('\n').trim() }); noteBuf = null; };
  const isChecklist = s => /^checklist/i.test(s || '');
  const ensureGroup = name => { if (!groups.length || groups[groups.length - 1].name !== name) groups.push({ name, items: [] }); return groups[groups.length - 1]; };

  for (const line of lines) {
    if (/^```/.test(line)) inFence = !inFence;
    const h = !inFence && line.match(/^(#{2,4})\s+(.*)$/);
    if (h) {
      if (h[1] === '##') { flushNote(); section = h[2].trim(); group = null; cur = null; if (!isChecklist(section)) noteBuf = { title: section, body: [] }; }
      else if (isChecklist(section)) { group = stripMd(h[2]); cur = null; }
      else if (noteBuf) noteBuf.body.push(line);
      continue;
    }
    if (isChecklist(section)) {
      const m = line.match(/^(\s*)[-*]\s+\[([ xX~-])\]\s+(.*)$/);
      if (m) {
        const g = ensureGroup(group || '');
        let text = m[3].trim(), id = '';
        const im = text.match(/^([A-Za-z0-9_-]{1,32}) \| (.*)$/);
        if (im) { id = im[1]; text = im[2]; }
        cur = { id, text, done: /x/i.test(m[2]), skipped: /[~-]/.test(m[2]), note: [], tags: [], deps: [], fields: [], level: m[1].length >= 2 ? 1 : 0 };
        g.items.push(cur);
      } else if (cur && line.trim()) {
        const kv = line.trim().match(/^-\s+([A-Za-z0-9_-]+):\s*(.*)$/);
        if (kv && /^tags$/i.test(kv[1])) cur.tags.push(...kv[2].split(',').map(t => t.trim()).filter(Boolean));
        else if (kv && /^deps$/i.test(kv[1])) cur.deps.push(...kv[2].split(',').map(t => t.trim()).filter(Boolean));
        else if (kv) cur.fields.push({ key: kv[1], value: kv[2] });
        else cur.note.push(line.trim());
      }
      else if (!line.trim()) { /* keep cur until next item */ }
    } else if (noteBuf) noteBuf.body.push(line);
  }
  flushNote();
  const items = groups.flatMap(g => g.items);
  const done = items.filter(i => i.done).length;
  items.forEach(i => { i.note = i.note.join('\n'); });
  return { file, title, meta, groups, notes, total: items.length, done };
}

// Entrypoint: "Current task" e "Note" in evidenza.
function parseEntrypoint(text) {
  const out = { title: '', current: null, notes: '' };
  const t = text.match(/^#\s+(.*)$/m); if (t) out.title = stripMd(t[1]);
  const sec = name => {
    const re = new RegExp(`^##\\s+${name}\\s*$`, 'im'); const m = re.exec(text); if (!m) return null;
    const rest = text.slice(m.index + m[0].length); const n = rest.search(/^##\s/m);
    return (n < 0 ? rest : rest.slice(0, n)).trim();
  };
  const cur = sec('Current task');
  if (cur) {
    const fields = [];
    for (const l of cur.split('\n')) { const m = l.match(/^-\s+\*\*(.+?):\*\*\s*(.*)$/); if (m) fields.push({ label: m[1], value: m[2] }); }
    out.current = { fields, raw: cur };
  }
  out.notes = sec('Note') || '';
  return out;
}

async function loadWork(dir) {
  const names = (await fs.readdir(dir)).sort();
  const read = n => fs.readFile(path.join(dir, n), 'utf8');
  const steps = [];
  for (const n of names.filter(n => /^tasks-.*\.md$/.test(n))) {
    const text = await read(n);
    const st = parseTaskFile(text, n);
    st.mtime = (await fs.stat(path.join(dir, n))).mtimeMs;
    steps.push(st);
  }
  const entry = names.includes('entrypoint.md') ? parseEntrypoint(await read('entrypoint.md')) : null;
  const total = steps.reduce((a, s) => a + s.total, 0), done = steps.reduce((a, s) => a + s.done, 0);
  const mtime = Math.max(0, ...steps.map(s => s.mtime));
  const currentFile = entry?.current?.fields?.find(f => /file/i.test(f.label))?.value.match(/\(([^)]+\.md)\)/)?.[1];
  const docs = { plan: names.includes('plan.md'), entrypoint: names.includes('entrypoint.md') };
  return { id: dir, name: path.basename(dir), dir, title: (entry?.title || path.basename(dir)).replace(/\s*[—-]\s*entrypoint$/i, ''), entry, steps, total, done, mtime, currentFile, docs };
}

// ---------- http ----------
const json = (res, code, body) => { res.writeHead(code, { 'content-type': 'application/json' }); res.end(JSON.stringify(body)); };
const readBody = req => new Promise(r => { let b = ''; req.on('data', d => { b += d; if (b.length > 200000) req.destroy(); }); req.on('end', () => { try { r(JSON.parse(b || '{}')); } catch { r({}); } }); });

// Le risposte si registrano sempre tramite `wk reply` (lock, validazione, formato): mai scrivendo i file da qui.
const wkCandidates = () => [process.env.WK_BIN, 'wk', path.join(here, 'cli', 'zig-out', 'bin', 'wk')].filter(Boolean);
const runWk = args => new Promise(resolve => {
  const c = wkCandidates();
  const next = i => {
    if (i >= c.length) return resolve({ ok: false, error: 'wk non trovato: mettilo nel PATH o imposta WK_BIN' });
    execFile(c[i], args, { timeout: 15000 }, (err, stdout, stderr) => {
      if (err && err.code === 'ENOENT') return next(i + 1);
      if (err) return resolve({ ok: false, error: (stderr || err.message).replace(/^error:\s*/, '').trim() });
      resolve({ ok: true, out: stdout });
    });
  };
  next(0);
});

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  try {
    // difesa DNS-rebinding/CSRF: solo localhost
    const host = (req.headers.host || '').split(':')[0];
    if (!['localhost', '127.0.0.1', '[::1]'].includes(host)) return json(res, 403, { error: 'host' });

    if (url.pathname === '/api/config' && req.method === 'GET') return json(res, 200, await loadConfig());
    if (url.pathname === '/api/config' && req.method === 'PUT') {
      if (req.headers.origin && new URL(req.headers.origin).host !== req.headers.host) return json(res, 403, { error: 'origin' });
      const b = await readBody(req);
      const paths = [...new Set((b.paths || []).map(p => String(p).trim()).filter(Boolean))];
      await saveConfig({ paths }); return json(res, 200, { paths });
    }
    if (url.pathname === '/api/works') {
      const cfg = await loadConfig(); const roots = [];
      for (const p of cfg.paths) {
        const r = await findWorks(p);
        roots.push({ path: p, missing: !!r.missing, works: await Promise.all(r.works.map(loadWork)) });
      }
      return json(res, 200, { roots });
    }
    if (url.pathname === '/api/doc') { // plan.md / entrypoint.md di un work configurato (sola lettura)
      const file = url.searchParams.get('file'), dir = path.resolve(url.searchParams.get('work') || '');
      if (!['plan', 'entrypoint'].includes(file)) return json(res, 400, { error: 'file non ammesso' });
      let known = false;
      for (const p of (await loadConfig()).paths) if ((await findWorks(p)).works.includes(dir)) { known = true; break; }
      if (!known) return json(res, 404, { error: 'work non configurato' });
      const full = path.join(dir, file + '.md');
      return json(res, 200, { file: file + '.md', text: await fs.readFile(full, 'utf8'), mtime: (await fs.stat(full)).mtimeMs });
    }
    if (url.pathname === '/api/answer' && req.method === 'POST') {
      if (req.headers.origin && new URL(req.headers.origin).host !== req.headers.host) return json(res, 403, { error: 'origin' });
      const b = await readBody(req);
      const dir = path.resolve(String(b.work || '')), id = String(b.id || '');
      const answer = String(b.answer || '').replace(/\s*\r?\n\s*/g, ' ').trim();
      if (!/^[A-Za-z0-9_-]{1,32}$/.test(id)) return json(res, 400, { error: 'id non valido' });
      if (!answer || answer.length > 2000) return json(res, 400, { error: 'risposta vuota o troppo lunga' });
      let known = false;
      for (const p of (await loadConfig()).paths) if ((await findWorks(p)).works.includes(dir)) { known = true; break; }
      if (!known) return json(res, 404, { error: 'work non configurato' });
      const r = await runWk(['reply', '-w', dir, '--', id, answer]);
      return json(res, r.ok ? 200 : 409, r.ok ? { ok: true } : { error: r.error });
    }
    if (url.pathname === '/api/ls') { // browser cartelle per la configurazione
      const dir = path.resolve(expand(url.searchParams.get('path') || '~'));
      const ents = await fs.readdir(dir, { withFileTypes: true });
      const dirs = ents.filter(e => e.isDirectory()).map(e => e.name).sort((a, b) => a.localeCompare(b));
      return json(res, 200, { dir, parent: path.dirname(dir), dirs, isWork: await isWork(dir) });
    }
    // static
    let f = url.pathname === '/' ? '/index.html' : url.pathname;
    const full = path.join(here, 'public', path.normalize(f).replace(/^(\.\.[/\\])+/, ''));
    if (!full.startsWith(path.join(here, 'public'))) return json(res, 403, {});
    const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css' };
    const buf = await fs.readFile(full);
    res.writeHead(200, { 'content-type': types[path.extname(full)] || 'application/octet-stream' });
    res.end(buf);
  } catch (e) {
    if (res.headersSent) return res.end();
    json(res, e.code === 'ENOENT' || e.code === 'EISDIR' ? 404 : 500, { error: String(e.message || e) });
  }
});
server.listen(PORT, '127.0.0.1', () => console.log(`Work Steps → http://localhost:${PORT}  (config: ${CONFIG})`));
