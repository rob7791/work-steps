//! English CLI help, including agent workflows.
pub const main =
    \\wk — manage step-based checklist works through the CLI.
    \\
    \\USAGE
    \\  wk <command> [arguments] [options]
    \\  wk help <command|format|filters|output|delegation|auto>
    \\
    \\READ
    \\  steps        Progress, counters, existing keys and tags
    \\  list         List, filter, and sort items
    \\  get ID       Read an item
    \\  next         Next available open item
    \\  tags / keys  Existing tags and custom keys
    \\  reply        Answer pending questions (interactive for humans)
    \\  questions    Pending questions, options, and suggestions
    \\  deps / waves Dependency tree and execution waves
    \\  validate     Check document structure and data
    \\
    \\WRITE
    \\  add / edit / rm            Create, rename, or delete items
    \\  check / uncheck            Complete or reopen items
    \\  set / unset / tag          Update custom fields and tags
    \\  hold / resolve             Ask a question or record an answer
    \\  defer / undefer            Record or undo user deferral
    \\  claim / unclaim / brief    Track ownership and prepare delegation
    \\  classify / dep             Manage delegation modes and dependencies
    \\  plan / section             Read and update prose sections
    \\  step-set / step-status     Update step metadata or status
    \\  new-step / init            Create steps or works
    \\  sync / entry               Synchronize progress or update prose fields
    \\  assign-ids / migrate       Assign missing IDs or migrate document formats
    \\  auto                       Bounded automatic execution
    \\  version / hook             Version information and plugin hooks
    \\
    \\GLOBAL OPTIONS
    \\  -w, --work DIR        Work directory; default: $WK_WORK, then search upward
    \\                        for .work/<name>. Multiple works require --work.
    \\  --format json|text|ids Default json (compact); ids prints one ID per line.
    \\  --brief               Only id, done, label.
    \\  --full                Unabridged values; writes also return updated items.
    \\  --fields a,b,c        Select built-in or custom fields; missing fields are null.
    \\  --no-sync             Skip automatic synchronization on supported writes.
    \\  -h, --help            Command help.
    \\
    \\Inspect existing keys/tags with `wk steps` before writing. Read minimally: `wk help output`.
    \\Writes normally return {"ok":true,"updated":[ID…]}; add always returns the created item.
    \\Exit codes: 0 success, 1 usage/data error, 2 validation findings.
    \\
    \\  wk next --tag backend --sort priority
    \\  wk list --open --step 2 --where owner=sam --brief
    \\  wk check k3f9 --result "Verified"
    \\
;

pub const format =
    \\DOCUMENT FORMAT
    \\
    \\A work is a directory with tasks-*.md files (one per step), optionally entrypoint.md and plan.md.
    \\The CLI updates checklist items inside `## Checklist` and explicit metadata/prose targets.
    \\
    \\    # Step 001 — Baseline
    \\    **Status:** in progress
    \\
    \\    ## Checklist
    \\
    \\    - [x] k3f9 | Collect the PHP version
    \\      - tags: infra, php
    \\      - owner: sam
    \\      - priority: 1
    \\    - [ ] p0qz | Confirm the starting branch
    \\
    \\Items use `- [ ]` / `- [x]` followed by `ID | label`. IDs are unique within a work,
    \\[A-Za-z0-9_-]{1,32}; generated IDs have four characters. Labels are free text.
    \\Two-space-indented `- key: value` entries are custom fields. `tags` is comma-separated.
    \\Other indented lines are preserved as notes. `### Title` defines a checklist group.
    \\Reserved keys: id, label, done, step, line, notes, group, fields.
    \\
    \\Step metadata: **Status:**, **Plan phase:**, **Prerequisites:**.
    \\Statuses: not started, in progress, blocked, completed.
    \\Entrypoint document version: `**Document version:** N` before the first section.
    \\Missing version means 0 (legacy experimental format). It is independent of tool version.
    \\See `wk version` and `wk help migrate`.
    \\Current task derived fields: File, Status, Progress. Other prose labels are free-form.
    \\
;

pub const filters =
    \\FILTERS (list, next, tags, keys, and supported commands)
    \\
    \\  --step S          Step: 2, 002, step-002, or tasks-step-002.md; repeatable.
    \\  --open | --done   Open or completed items.
    \\  --tag t[,t2]      Require all tags; repeatable, case-insensitive.
    \\  --any-tag a,b     Require at least one tag.
    \\  --has KEY         Require a nonempty field; repeatable.
    \\  --where k=v       Case-insensitive equality; k!=v differs, k~v contains.
    \\                    Custom fields or label, id, group, tags.
    \\  --match TEXT      Match text in label or ID.
    \\  --sort KEY        Sort built-in/custom field; numeric for numeric values.
    \\                    Missing values sort last.
    \\  --desc            Descending order.
    \\  --limit N         At most N items; total is counted before this limit.
    \\  --mode isolated|integrated|unset
    \\  --ready | --blocked | --delegable
    \\  --no-deps | --has-deps
    \\  --deps all-done|some-done|none-done
    \\  --needs ID        Items directly depending on ID.
    \\  --needed-by ID    Direct dependencies of ID.
    \\  --held            Waiting for an answer.
    \\  --claimed | --unclaimed | --claimed-by NAME
    \\
    \\See `wk help delegation` and `wk help auto`.
    \\
;

pub const cmd_list =
    \\wk list [filters] [--count] [--brief] [--fields ...] [--format json|text|ids]
    \\
    \\List items in document order, or --sort order.
    \\JSON: {"total":N,"count":M,"items":[…]}. Step titles: `wk steps`.
    \\  wk list --open --tag urgent --sort priority --brief
    \\  wk list --step 3 --where owner~sam --fields id,label,owner
    \\
;

pub const cmd_get =
    \\wk get ID [--brief] [--fields ...] [--full]
    \\
    \\Return {"item":{…}}. Values over 300 characters are abbreviated by default.
    \\Use --fields KEY for a complete selected field, or --full for all values.
    \\Unknown ID: exit 1.
    \\
;

pub const cmd_next =
    \\wk next [filters] [--brief] [--fields ...] [--any]
    \\
    \\First matching open item, skipping open dependencies, held items, and claims.
    \\--any includes those items; --sort changes selection order. Answered items take priority.
    \\If none: {"item":null,"reason":"no_open_items|nothing_available","open","blocked","held","claimed","hint"}.
    \\
;

pub const cmd_steps =
    \\wk steps
    \\
    \\Work/step progress and counters: done, total, open, available, blocked, held, claimed,
    \\delegable, answered; existing keys and tags; step key, file, title, status, done, total.
    \\Available means open with no open dependencies, hold, or claim. Delegable also requires isolated mode.
    \\
;

pub const cmd_tags =
    \\wk tags [filters]
    \\
    \\Tags in use, sorted by frequency: {"tags":[{"tag","count","open"}]}.
    \\
;

pub const cmd_add =
    \\wk add --step S "Label" [--tag a,b] [--set k=v]... [--id ID] [--after ID] [--checked]
    \\
    \\Append an item, or insert after --after ID. Generate an ID unless supplied.
    \\Always return the created item. In a work with a dependency graph, connect new items
    \\with `wk dep add` when warned: new items have no dependencies or dependents.
    \\
;

pub const cmd_check =
    \\wk check ID [ID...] [--result "Outcome"]
    \\wk uncheck ID [ID...]
    \\
    \\Complete or reopen items. --result is a concise, verifiable outcome stored in result.
    \\Completion clears claims and pending holds. Check only completed and verified work.
    \\Writes return updated IDs; --full also returns items.
    \\
;

pub const cmd_edit =
    \\wk edit ID --label "New label"
    \\
    \\Change the label while preserving ID. Use tag and set for tags and fields.
    \\
;

pub const cmd_set =
    \\wk set ID key=value [key=value ...]
    \\wk unset ID key [key ...]
    \\
    \\Set/remove custom fields. tags=a,b replaces all tags. Values must be nonempty, single-line,
    \\and at most 400 characters by default. Summarize outcomes and reference repository files
    \\for details. --long bypasses the limit when necessary. Reserved keys: `wk help format`.
    \\
;

pub const cmd_tag =
    \\wk tag ID +tag1 +tag2 -tag3
    \\
    \\Add tags with + or no prefix; remove with -.
    \\
;

pub const cmd_rm =
    \\wk rm ID [ID...] [--force]
    \\
    \\Delete items and their child lines. JSON: {"removed":[ID…]}.
    \\If other items depend on an item, remove those dependencies first or use --force.
    \\
;

pub const cmd_assign =
    \\wk assign-ids [--step S] [--dry-run]
    \\
    \\Assign missing IDs: `- [ ] text` becomes `- [ ] k3f9 | text`. Idempotent.
    \\JSON: {"assigned":N,"dry_run":bool}.
    \\
;

pub const cmd_validate =
    \\wk validate
    \\
    \\Check missing/duplicate IDs, empty labels, titles, statuses, checklists, modes,
    \\unknown dependencies, self-dependencies, and cycles. Warn about unclassified open items,
    \\large fields, entrypoint.md over 4 KB, and plan.md over 16 KB.
    \\JSON: {"ok":bool,"issues":[…]}; exit 2 for findings.
    \\
;

pub const cmd_new_step =
    \\wk new-step [--title "Title"] [--phase "Phase"] [--prereq "Prerequisites"]
    \\
    \\Create the next tasks-step-NNN.md using the standard template and return its filename.
    \\
;

pub const cmd_init =
    \\wk init DIR [--title "Work title"] [--first-step "First step title"] [--force]
    \\
    \\Create entrypoint.md, plan.md, and tasks-step-001.md. Refuse nonempty directories unless
    \\--force is supplied; existing files are preserved.
    \\
    \\Recommended sequence:
    \\  1. wk init DIR --title "…" --first-step "…"
    \\  2. wk new-step --title "…" --phase "…" --prereq "…"    once per additional step
    \\  3. wk section set STEP "Goal" "…"                    prose sections
    \\     wk section set plan "Strategy" -                  plan text from stdin
    \\  4. wk add --step N "…" --tag … --set key=value
    \\  5. wk classify / wk dep add                           modes and dependencies
    \\  6. wk entry set "Next action" "…"
    \\  7. wk validate
    \\
    \\One ## Checklist per step, one field per line. Tool metadata: Status, Plan phase,
    \\Prerequisites; Current task File/Status/Progress are derived. Other sections are free-form.
    \\Statuses: not started, in progress, blocked, completed.
    \\
;

pub const cmd_sync =
    \\wk sync [--dry-run]
    \\
    \\Synchronize derived fields (also done by check/uncheck/add/rm/new-step):
    \\- Step Status becomes in progress when the first item completes, completed when all
    \\  complete, and in progress again when an item reopens. Unfinished blocked steps stay blocked.
    \\- Current task File points to the first step with open items; Status and Progress follow it.
    \\  Missing Progress is inserted after Status.
    \\Prose fields are preserved; update them with `wk entry set`.
    \\JSON: {"current","entrypoint","dry_run","changes":[{"target","field","from","to"}]}.
    \\
;

pub const cmd_entry =
    \\wk entry [get]
    \\wk entry set "Label" value...
    \\wk entry unset "Label"
    \\wk entry slim [--dry-run]
    \\
    \\Read Current task fields and format versions, set/create a prose field, remove a field,
    \\or archive sections other than Current task in entrypoint-archive.md.
    \\Keep the entrypoint minimal. Resume with steps/next; do not read the archive.
    \\slim preserves archived text; --dry-run reports sizes without writing.
    \\File, Status, Progress, and Automatic session are managed by sync/auto.
    \\Values are single-line; unrelated content is preserved.
    \\  wk entry set "Next action" "Finish checkout tests"
    \\  wk entry set "Blockers" "Missing ERP fixtures"
    \\
;

pub const cmd_step_status =
    \\wk step-status STEP "not started|in progress|blocked|completed"
    \\
    \\Set step Status and synchronize the entrypoint. blocked is always an explicit choice.
    \\Sync reopens completed steps with open items; --no-sync prevents synchronization.
    \\  wk step-status 3 blocked
    \\
;

pub const cmd_keys =
    \\wk keys [filters]
    \\
    \\Custom keys in use, counts, distinct values, and up to eight frequent values.
    \\Reuse existing names and values. set/add warn about new keys/tags and normalize casing.
    \\
;

pub const output =
    \\READ MINIMALLY
    \\
    \\  wk steps                         Overview, existing keys and tags
    \\  wk list --count [filters]         Only {"total":N}
    \\  wk list --brief                   id, done, label
    \\  wk list --fields id,label,owner   Selected built-in/custom fields
    \\  wk list --format ids              One ID per line
    \\  wk list --limit 10 --sort KEY     First N by a criterion
    \\  wk next --brief                   Next item, without tags/fields
    \\  wk get ID --fields evidence       One complete field
    \\  wk plan / wk plan "Title"         Plans by section
    \\
    \\Resume through steps/next. Filter before reading; total is counted before --limit,
    \\so total > count means more results exist. Read full items only when about to act.
    \\Writes normally return only updated IDs; use --full when updated item data is necessary.
    \\
;

pub const cmd_classify =
    \\wk classify ID [ID...] --mode isolated|integrated|unset [--reason "Reason"]
    \\
    \\isolated: executable by a subagent with bounded context.
    \\integrated: requires the wider work context.
    \\unset: remove classification.
    \\Stored as mode/mode_reason. Changing mode without --reason removes the old reason.
    \\Reclassify immediately when an item proves unsuitable for isolated execution.
    \\
;

pub const cmd_dep =
    \\wk dep add ID DEP [DEP...] [--reason "Reason"]
    \\wk dep rm ID DEP [DEP...]
    \\wk dep set ID [DEP...]
    \\
    \\ID depends on DEP, including across steps. set replaces all dependencies; no DEP clears them.
    \\Reject unknown IDs, self-dependencies, and cycles. Open dependencies make an item blocked.
    \\Record newly discovered dependencies promptly.
    \\
;

pub const cmd_deps =
    \\wk deps [ID] [--up|--down] [--depth N] [--open] [--format json|text|ids]
    \\
    \\Dependency tree as a preorder flat list with depth and parent.
    \\--up shows prerequisites (default with ID); --down shows dependents/impact
    \\(default without ID). Without ID, show the connected graph. --depth limits depth;
    \\--open skips completed branches.
    \\JSON: {"root","direction","count","nodes":[{"id","done","label","mode"?,"depth","parent"}]}.
    \\  wk deps k3f9 --up --depth 1 --open
    \\  wk deps p0qz --down
    \\
;

pub const cmd_waves =
    \\wk waves [filters] [--format json|text|ids]
    \\
    \\Execution waves for open items: wave 1 can run now, wave 2 after wave 1, etc.
    \\Filters restrict displayed items; calculation uses all open items.
    \\JSON: {"waves":[{"wave":1,"items":[…]}],"unscheduled":[IDs in cycles]}.
    \\  wk waves --mode isolated
    \\
;

pub const cmd_hook =
    \\wk hook session-start | stop
    \\
    \\Plugin-only command; reads hook JSON from stdin. Outside a work project it has no effect.
    \\session-start provides work/CLI context and reminds the agent of active sessions after
    \\compaction. Sessions from earlier conversations require explicit user authorization.
    \\stop prevents stopping only when an automatic session started in this conversation has
    \\reason ok. Questions, limits, completion, and three reminders without progress allow stopping.
    \\Conversation state: $TMPDIR/work-steps-<session_id>.state.
    \\
;

pub const cmd_plan =
    \\wk plan
    \\wk plan "Title"
    \\
    \\List section titles, then read only the section required by the current item.
    \\Equivalent to `wk section ls plan` / `wk section get plan "Title"`.
    \\
;

pub const cmd_section =
    \\wk section ls TARGET
    \\wk section get TARGET "Title"
    \\wk section set TARGET "Title" text...
    \\
    \\TARGET is a step (1, step-001), plan, or entrypoint. Operates on ## sections.
    \\set replaces a section body or appends a new section; unrelated content is preserved.
    \\Pass - to read stdin. Use item commands for Checklist and entry/sync for Current task.
    \\  wk section set 1 "Goal" "Establish a verifiable baseline"
    \\  wk section set plan "Strategy" - < strategy.md
    \\
;

pub const cmd_step_set =
    \\wk step-set STEP [--title "Title"] [--phase "Phase"] [--prereq "Prerequisites"]
    \\
    \\Change title while preserving the Step NNN prefix; update Plan phase / Prerequisites.
    \\Missing metadata is inserted after Status. Also supported by new-step;
    \\init accepts --first-step for the initial title.
    \\
;

pub const delegation =
    \\DELEGATION AND DEPENDENCIES
    \\
    \\Fields: mode (isolated|integrated), mode_reason, deps (comma-separated IDs).
    \\Missing mode means unclassified. Computed states:
    \\  ready: open, no open dependencies (--ready)
    \\  blocked: open, at least one open dependency (--blocked)
    \\  delegable: ready + isolated, no hold or claim (--delegable)
    \\
    \\Filters: --ready --blocked --delegable --no-deps --has-deps
    \\  --deps all-done|some-done|none-done
    \\  --needs ID / --needed-by ID (direct dependents / prerequisites)
    \\  --mode isolated|integrated|unset
    \\next skips blocked, held, and claimed items; --any includes them.
    \\Use deps --up/--down for transitive relationships. Unknown dependency IDs are ignored
    \\by scheduling: validate detects them; repair with dep rm/set. Assign missing IDs first.
    \\
    \\Main agent: inspect waves/list, choose independent items, provide context, and delegate.
    \\Subagent: get ID, work, check --result. On a new dependency: dep add and report.
    \\If wider context is needed: classify --mode integrated --reason "…", then stop and report.
    \\Main agent resumes reclassified work with list --mode integrated --open.
    \\See `wk help auto` for parallel execution and review.
    \\
;

pub const cmd_version =
    \\wk version [--format text]
    \\
    \\Tool version, source commit, document format, and known migrations:
    \\{"tool","commit","format","migrations":[{"from","to","summary"}]}.
    \\`wk --version` prints version, commit (with -dirty for uncommitted source changes),
    \\and document format so you can identify the binary in use.
    \\
;

pub const cmd_migrate =
    \\wk migrate --from N [--dry-run]
    \\
    \\Migrate from the version declared in the entrypoint (`wk entry get` → format.work)
    \\to the tool's document format. Missing declaration means 0 (legacy experimental format).
    \\Refuse mismatched --from values and documents newer than the tool. Apply known migrations
    \\in sequence and update the entrypoint version. Already current: {"changed":false}.
    \\Inspect --dry-run first; validate afterward.
    \\  wk entry get
    \\  wk migrate --from 0 --dry-run
    \\  wk migrate --from 0
    \\
;

pub const cmd_hold =
    \\wk hold ID "Question" [--option X --option Y …] [--default X]
    \\wk resolve ID "Answer"
    \\wk questions [filters]
    \\wk questions --deferred
    \\wk defer ID [--note "What we are waiting for"]
    \\wk undefer ID
    \\
    \\Hold an item requiring missing information, a decision, or authorization. Ask a self-contained
    \\question explaining what is needed and why it blocks progress. While other work exists,
    \\park it and continue; the user can answer through the dashboard or reply. If only questions
    \\remain, present them in chat (auto status: ask_user).
    \\Options require at least two choices; --default marks a suggested answer for user acceptance.
    \\Resolution records asked, answer, answered_at and makes the item available again.
    \\
    \\Deferral belongs to the user. Record it with defer and preserve the question text.
    \\Deferred questions leave the answer queue and block their items/dependents. Do not ask again;
    \\report them through questions --deferred (including note and blocks). Other work continues.
    \\Never offer Defer, Not yet, or Later as an option/default: hold rejects deferral choices.
    \\Holding a deferred item again creates a new pending question; answering or checking clears deferral.
    \\
;

pub const cmd_reply =
    \\wk reply
    \\wk reply --id ID
    \\wk reply ID "Answer" [ID "Answer" …]
    \\
    \\Without positional answers, interactive for humans in a terminal: shows each question,
    \\options, and suggestion. Enter text or an option number, d for suggestion, Enter to skip,
    \\q to quit. Answers save immediately.
    \\Agents must read questions and record explicit user answers through the positional form.
    \\A batch with an invalid answer makes no changes. Use -- before IDs if an answer starts with -.
    \\Dashboard answers may arrive concurrently.
    \\
;

pub const cmd_claim =
    \\wk claim ID [ID...] [--by NAME]
    \\wk unclaim ID [ID...]
    \\
    \\Claim items with claimed_by (default agent) so next/delegable skip them.
    \\Reject completed, held, dependency-blocked, or differently claimed items.
    \\check and hold release claims automatically.
    \\  wk list --delegable --limit 3 --format ids
    \\  wk claim k3f9 p0qz --by sub1
    \\
;

pub const cmd_brief =
    \\wk brief ID [ID...]
    \\
    \\Print a delegation brief as text (not JSON): item, mode/reason, fields, direct dependency results,
    \\unlocked items, subagent rules, and a Main agent context section to complete before launch.
    \\Does not claim the item: use claim.
    \\
;

pub const auto =
    \\AUTOMATIC MODE AND PARALLEL DELEGATION
    \\
    \\Read this guide in full. Automatic mode requires an EXPLICIT user request and an item limit.
    \\It runs items continuously within entrypoint authorization, without per-item confirmation.
    \\While work is available, park missing decisions with hold and continue. The user may answer
    \\in the dashboard or with reply. When only answers are missing, present questions in chat
    \\immediately (ask_user). Optional --wait allows dashboard answers first. The agent executes
    \\the loop; the CLI evaluates stop conditions.
    \\
    \\COMMANDS
    \\  wk auto start --limit N [--delegate] [--wait MINUTES]
    \\    Record Automatic session in Current task. --delegate only if requested by the user.
    \\    --wait defaults to 0: ask in chat as soon as no other work remains.
    \\  wk auto status
    \\    continue, reason, completed, limit, available, held, deferred, delegate, delegable,
    \\    answered, answered_ids, wait_left_s, hint.
    \\    Reasons: ok, waiting_for_answers, ask_user, only_deferred, nothing_available, limit_reached.
    \\  wk auto wait --timeout SECONDS
    \\    Poll dashboard answers (default 60 seconds), consuming the --wait budget.
    \\  wk auto stop
    \\    Close the session. Refuse while continue is true; --force only for a user-requested
    \\    stop, user-deferred questions, or an unavoidable blocking error.
    \\  wk steps / wk next
    \\    Counters and next available item; answered items take priority.
    \\  wk hold ID "Question" [--option …] [--default …]
    \\  wk questions / wk reply ID "Answer"…
    \\  wk claim ID --by NAME / wk unclaim ID / wk brief ID
    \\  wk check ID --result "Outcome and verification"
    \\
    \\Completed means current completed count minus the starting count. Reopening an item lowers
    \\it; a subagent completion counts once. A recorded session belongs to a prior conversation
    \\unless explicitly resumed by the user. Inspect with entry get; ask whether to resume or close
    \\it before taking over.
    \\
    \\MAIN AGENT LOOP
    \\  0. Ask for a missing limit, then start with the requested delegation/wait options.
    \\  1. Inspect entry get and steps for authorization, Delegation policy, and counters.
    \\  2. next → work the item. Every started item ends in verified check --result, or hold
    \\     describing the missing decision, permission, data, or environment. Insufficient
    \\     verification alone is not a stop: continue until verifiable, or hold if input is missing.
    \\     An action outside Current authorization must be held. Use self-contained questions,
    \\     options, and suggestions when useful. Do not ask in chat while other work remains.
    \\  3. Run auto status after EVERY item. While continue is true, repeat step 2.
    \\     waiting_for_answers: auto wait --timeout 120, then status again.
    \\     ask_user: follow QUESTIONS IN CHAT below.
    \\     Inspect asked/answer before resuming answered items:
    \\       wk get ID --fields id,asked,answer
    \\  4. Periodically update entry set "Next action" "…" for resumption.
    \\
    \\QUESTIONS IN CHAT (ask_user)
    \\Read questions and present them NOW through the native question tool. Without one, write
    \\numbered questions in full with ID, item, options, and suggested answer, then await the user.
    \\Batch within tool limits. Reuse supplied options/default. If choices are required but absent,
    \\provide plausible choices and allow free text. Deferral remains a separate user decision;
    \\never store it as an answer option/default.
    \\Record all answers with one `wk reply ID "Answer" ID "Answer" …` call (use -- before IDs
    \\when an answer begins with -). If a dashboard answer arrived meanwhile, refresh questions
    \\and continue. Resume status/next after recording answers.
    \\If the user defers, record `wk defer ID --note "What we are waiting for"` and preserve the
    \\question. Do not ask it again. If the user neither answers nor defers, report that input is
    \\missing rather than repeating questions.
    \\
    \\STOP CONDITIONS
    \\- auto status returns continue=false with only_deferred, nothing_available, or limit_reached.
    \\- An unavoidable blocking environment/tool error.
    \\waiting_for_answers and ask_user require waiting within budget or asking in chat; they are
    \\not completion. A partial result, finishing a step/milestone, conversation length, or feeling
    \\that enough has been done is not a stop while items remain below the requested limit.
    \\Only_deferred means report deferred questions and blocked counts without asking again.
    \\If the user asks to stop, immediately auto stop --force and report steps.
    \\
    \\BEFORE THE FINAL REPORT
    \\Always run auto status. If continue is true, keep working or handle pending answers.
    \\Report the stop reason first, then completed items and verification, delegation/reclassification,
    \\CLI warnings, and steps. Include unanswered/deferred questions IN FULL with IDs, item labels,
    \\options, and suggestions (questions --format text), not just topics.
    \\Close with auto stop; use --force for explicit user stops or deferral when required.
    \\
    \\PARALLEL DELEGATION
    \\Follow Current task's Delegation policy (entry set "Delegation policy" "…"). If absent,
    \\use at most 2–3 subagents and the smallest adequate model within the host's rules.
    \\  1. list --delegable --limit N; verify no shared files or decisions; claim --by subN.
    \\  2. brief ID; complete Main agent context; launch the subagent in the background.
    \\  3. Work the next item that requires the main agent's context while subagents run.
    \\  4. Review each result (get ID --fields id,result). If insufficient, uncheck and rework,
    \\     or hold for missing input. Recalculate steps and repeat.
    \\Subagents work only assigned items: get, work, check --result. New dependency: dep add;
    \\wider context: classify --mode integrated; missing decision: hold. Then stop and report.
    \\
    \\LIMITS AND RISKS
    \\Directory locks protect concurrent work writes on supported platforms; do not edit files
    \\manually while agents operate. The tool does not prevent source-file collisions: choose
    \\independent items. Review every delegated outcome before relying on it. Authorization,
    \\hold, and user limits bound long runs. Do not use secrets or act on real environments without
    \\authorization. Automatic mode must be requested each session. The CLI maintains data and
    \\scheduling; the agent must follow these behavioral rules.
    \\
;
