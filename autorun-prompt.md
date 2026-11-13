Automatic mode on work `.work/my-work`, with delegation. Limit: 100 items.

<!--
The request must explicitly enable automatic mode and specify the work, whether delegation is allowed, and an item limit. The agent sets --delegate when delegation is requested.

The skill and `wk help auto` define execution, stop conditions, and reporting. Authorization and delegation policy belong in the entrypoint:
  wk entry set "Delegation policy" "At most 3 agents in parallel, model …"

While other work is available, the agent parks questions and continues. Questions appear in the dashboard, where the user can answer them. When only questions remain, the agent presents them in chat using its native question tool, records answers, and resumes. If the user defers them, it stops and reports them.

Variants:
- Dashboard answers first: … Limit: 100 items. Wait up to 30 minutes for dashboard answers before asking in chat.
- Without delegation: Automatic mode on work `.work/my-work`. Limit: 100 items.
- Priorities: … Start with step 2 and leave step 8 until last.
- Initial trial: … Limit: 5 items. Review results before increasing the limit.
-->
