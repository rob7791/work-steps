---
name: wk-brief
description: Interview the user to define new or vague work before creating it. Clarify goals, ambiguities, constraints, and decisions through focused questions, then create the work with `wk`. Do not propose solutions or implement. Use `wk` to resume existing work.
---

# wk-brief

Define what needs to be done before the work exists.

- Do not implement features, write code, or modify project files during the interview.
- Stay at the level of goals and planning. Avoid concrete solutions and implementation details.
- Explore only as needed for orientation, at most README.md and AGENTS.md.
- Understand the desired outcome, identify missing constraints and open decisions, and distinguish confirmed requirements from assumptions.
- Ask a few focused questions at a time through the CLI's native question tool (AskUserQuestion in Claude Code), only when answers change the plan.

Once the goal is clear:

1. Summarize goals, constraints, assumptions, remaining decisions, and broad step order. Ask for confirmation to create the work.
2. On confirmation, read the `wk` skill and `wk help init`. Create the work using `wk init`, `wk new-step`, `wk section set`, and `wk add`. Record goals, constraints, and assumptions in plan/step sections. The work must stand alone without the transcript.
3. Turn every open decision into an item with `wk hold ID "Question" [--option …]` so the user can answer or defer it in the dashboard.
4. Run `wk validate`.
5. Report completion of the brief, the work path, and step count. Suggest `/clear` or a new session followed by “Resume work `.work/name`”; the work holds the context.

Execute items after creation only if requested by the user.
