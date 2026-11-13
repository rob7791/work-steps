# wk — checklist work CLI

A dependency-free Zig 0.17.1 CLI for reading and updating works through compact JSON output, filters, and sorting. Errors go to stderr with exit code 1; validation findings use exit code 2.

    cd cli
    zig build -Doptimize=ReleaseSafe
    zig build test
    wk help
    wk help format
    wk help filters

A checklist item inside `## Checklist` looks like this:

    - [x] k3f9 | Free-form label
      - tags: infra, php
      - owner: sam

Use `wk` to update work documents. The CLI preserves unrelated lines. `wk assign-ids -w DIR` assigns missing item IDs.

## Progress synchronization

`check`, `uncheck`, `add`, `rm`, and `new-step` synchronize derived fields unless `--no-sync` is set. Step `**Status:**` values are `not started`, `in progress`, `blocked`, and `completed`. Completing the first item starts a step; completing all items completes it; reopening an item reopens the step. A blocked step is preserved while unfinished.

The entrypoint's `## Current task` contains derived **File**, **Status**, and **Progress** fields. Prose fields such as **Next action**, **Blockers**, and **Context** are updated explicitly:

    wk entry set "Next action" "Verify the implementation"
    wk sync --dry-run

## Dependencies and delegation

Items can declare `mode: isolated|integrated`, `mode_reason`, and `deps: ID, ID`. Isolated items can be delegated with bounded context; integrated items require the wider context. Dependencies determine readiness.

    wk classify ID --mode isolated --reason "Independent change"
    wk dep add ID DEP
    wk deps ID --up
    wk waves --mode isolated
    wk list --ready
    wk list --blocked
    wk list --delegable

`wk next` skips blocked items. See `wk help delegation` for the delegation procedure.

## Keep context small

Resume with `wk steps` and `wk next`. Read plans by section with `wk plan` and `wk plan "Section"`. `wk entry slim` moves extra entrypoint sections to `entrypoint-archive.md`.

Values over 300 characters are abbreviated by default, except answers, held questions, and answer options; use `--fields KEY` or `--full` for complete values. Writes normally return only `{"ok":true,"updated":[ID…]}`. `--full` also returns updated items; `add` always returns the new item.

Default write limits are 400 characters per field, 240 per label, and 700 per question. `--long` bypasses these limits. Validation warns about large documents and fields.

## Create and maintain a work

Use `wk init`, `wk new-step --phase --prereq`, `wk step-set`, `wk section ls|get|set`, and `wk validate`. See `wk help init`.

Document format versions are independent of the CLI version. The entrypoint declares `**Document version:** N`; a missing version is interpreted as 0. `wk version` lists supported migrations. Older formats produce a warning; newer formats are rejected. Inspect with `wk entry get`, then use `wk migrate --from N --dry-run` before applying a supported migration. Migration implementations live in `src/format.zig`.

## Automatic execution and questions

Automatic mode requires an explicit user request and an item limit. See `wk help auto`. `wk hold ID "Question" --option … --default …` parks an item while other work continues. Answers from the dashboard are recorded through `wk reply`, including its validation and lock. Agents use `wk reply ID "Answer"`; interactive `wk reply` is for humans.

`wk auto status` and `wk steps` expose answered items. When only unanswered questions remain, `ask_user` means present them in chat, record the answers, and resume. Optional `wk auto start --wait MINUTES` and `wk auto wait` allow dashboard answers first.

Only the user can defer a question. Record this with `wk defer ID --note "What we are waiting for"`; use `wk undefer ID` to return it to the queue. `wk questions --deferred` lists deferred questions and blocked dependents. `only_deferred` is a stop condition. Deferral is not an answer and must not be offered as an answer option.

`wk claim/unclaim` tracks ownership, `wk brief` provides delegation context, and `wk check --result` records verified results. Work directory locks protect concurrent writes on supported platforms.
