# Work Steps

Work Steps gives coding agents a step-based checklist they can read and update through the `wk` CLI. A local dashboard shows progress and lets you answer or defer questions. A **work** is a named, persistent plan organized into steps and checklist items. It lives in `.work/<name>/` with `entrypoint.md`, `plan.md`, and `tasks-step-*.md`. Edit it through `wk`, not by changing those Markdown files directly.

## Get started

Install the Claude Code plugin, which includes the skills, CLI binary, and hooks:

    /plugin marketplace add rob7791/work-steps
    /plugin install work-steps@work-steps

For Codex, Antigravity, or use without the plugin, see [Agents](#agents). To run `wk` manually, put it on your PATH. Platform builds are available in Releases, or build with `scripts/build.sh`.

Ask your agent to create or resume a work:

- “Plan a work to migrate X to Y.” The `wk-brief` skill clarifies the goal and open decisions, then creates the work. You can then clear the conversation: the work preserves the context needed to resume.
- “Resume the work in `.work/my-work`.”

For autonomous execution, request a bounded run:

    Automatic mode on `.work/my-work`, with delegation. Limit: 100 items.

“With delegation” allows independent items to go to subagents. The limit is the requested number of items to complete before stopping, unless another documented stop condition occurs. See [autorun-prompt.md](autorun-prompt.md) for variants and `wk help auto` for the full agent procedure. The agent puts items requiring your decision on hold and continues with other work. You can answer their questions in the dashboard or choose Defer to postpone a decision. Deferred questions leave the answer queue, remain visible under Deferred, and keep dependent items blocked.

Start the dashboard separately:

    node server.mjs        # or npm start → http://localhost:4317

Node 18 or newer is required. The server has no dependencies and listens on localhost. Under ⚙ Paths, add a .work folder, an individual work folder, or a repository root. Configuration is stored in `~/.config/work-steps/config.json`. Answers are recorded through `wk` (`bin/wk`, `WK_BIN`, or `wk` on PATH). Set `PORT` to change the port.

## Agents

The `wk` skill is in `.agents/skills/wk/` for Codex and Antigravity CLI; `.claude/skills/wk` links to it for Claude Code. `AGENTS.md` contains shared instructions. To use `wk` in another project, copy the skill directory and the “Works” instructions from `AGENTS.md`; add the Claude skill link if needed.

## Claude Code plugin

The plugin bundles the skills, a `bin/wk` launcher, and `SessionStart` and `Stop` hooks. The launcher selects a binary for Linux, macOS, or Windows on x86_64 or aarch64; without a bundled binary it uses `cli/zig-out/bin/wk` when available. Build releases with `scripts/build.sh [target…]` using Zig 0.17.x from a clean Git tree.

The hooks run only in projects with a work. `SessionStart` points the agent to `wk` and reminds it of active automatic sessions after compaction; a session from an earlier conversation requires an explicit request to resume. `Stop` keeps an active automatic run going when work is available; user questions, reaching the limit, completion, an explicit forced stop, and repeated stalls allow it to stop. Test the plugin with `claude --plugin-dir ~/workspace/step-harness` and `claude plugin validate .`.

On Windows, the binary builds but concurrent writes by multiple subagents are not locked.

## License

MIT. See [LICENSE](LICENSE).
