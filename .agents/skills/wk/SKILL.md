---
name: wk
description: Use `wk` to create, read, and update checklist works in `.work/<name>/`. Use `wk-brief` first for vague goals. Resume work, manage items, delegation, dependencies, tags, keys, and entrypoints through the CLI.
---

# wk

Always read and modify work Markdown through `wk`.

- Binary: `wk` on PATH, otherwise `cli/zig-out/bin/wk` (build: `cd cli && zig build -Doptimize=ReleaseSafe`). Commands and formats: `wk help`, `wk help <command|format|filters>`.
- Create works following `wk help init`. Follow document migration warnings with `wk migrate --from N`.
- Specify `-w DIR` when multiple works exist.
- Resume with `wk steps` and `wk next`. Read plans by section with `wk plan` and `wk plan "Title"`, only as needed. Do not read entrypoint.md or plan.md directly. Use `wk entry slim` if validation reports an oversized entrypoint.
- Inspect existing keys and tags before writing (`wk steps`, `wk keys`, `wk tags`). Reuse their names; review new-key/new-tag warnings and correct synonyms.
- Minimize reads with filters, `--count`, `--brief`, `--fields`, and `--limit` (see `wk help output`). Read abbreviated fields in full only when necessary.
- Writes return `{"ok":true,"updated":[…]}`. Avoid rereading; `--full` is available when needed. Keep outcomes short and reference repository files for details. Do not duplicate code, commits, or documents in fields.
- Delegate with `wk waves --mode isolated` / `wk list --delegable`; pass the ID and required context. If a dependency or need for wider context emerges, use `wk dep add` / `wk classify --mode integrated --reason …`, then stop and report. See `wk help delegation`.
- `--needs` and `--needed-by` are direct only; use `wk deps ID --up|--down` for transitive dependencies. Unknown IDs are ignored in scheduling: repair validation findings with `wk dep rm|set`.
- Automatic mode requires an explicit request and item limit. Ask for a missing limit, then `wk auto start --limit N [--delegate] [--wait MINUTES]`. Use `--delegate` only when requested. Read `wk help auto` in full. After each item, run `wk auto status` and continue while `continue` is true. Finish each started item with verified `wk check --result` or `wk hold ID "Question"` when input is missing.
- While other work is available, park questions and continue; use `--option` / `--default` when appropriate. Dashboard answers are signaled by status/next; inspect `wk get ID --fields id,asked,answer`.
- On `ask_user`, immediately present pending questions through your native question tool, using `wk questions` for options and suggestions. Without that tool, write questions in full. Record answers with `wk reply ID "Answer"` and resume. User deferral is a stop. `waiting_for_answers` means user-requested dashboard waiting (`wk auto wait`).
- Do not resume recorded sessions without an explicit request. Report the stop reason and unresolved questions in full, including IDs, item labels, options, and suggested answers, then `wk auto stop`. It refuses while `continue` is true; completing a step or milestone is not a stop. Use `--force` when the user asks to stop or defers questions. Agents must not invoke interactive `wk reply` without arguments.
- Deferral is the user's choice. Record `wk defer ID --note "What we are waiting for"`; preserve the question. Never offer “Defer” or “Not yet” as an answer/default. List deferred questions with `wk questions --deferred`, report them without asking again.
- Follow the entrypoint's “Delegation policy” for parallel work: list, claim, brief, then review outcomes. Subagents work only on assigned items, do not ask the user directly, and use hold/dep/classify when blocked. Do not assign shared files concurrently. Respect authorization and limits. Automatic mode does not persist without an explicit request. Never edit work files manually while agents operate.
- Check only completed and verified work. Search for duplicates before adding items, and connect new dependencies promptly, especially when splitting an item that blocks others.
- Before stopping, update “Next action” and changed blockers/context through `wk entry set`.
- Keep secrets, credentials, and personal data out of labels, keys, and entrypoints.
- On failure, read the error and `wk help <command>`; never bypass the CLI by editing work files.
