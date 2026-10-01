# html-plan

Get a plan you can read in a minute and answer in place.

```
/html-plan add send later to the composer
```

Produces one HTML page. The plan is a tree of claims:

| Level | Answers | Shown as |
|---|---|---|
| Goal | Why? | your own words |
| 1 | What can someone now do or see? | a UI mockup or a state machine |
| 2 | How does that work? | a call stack, a schema or a snippet |
| 3 | Where? | the code |

Closed, the tree is the summary. Open it one level at a time, or press **Needs you** to jump to the decisions. Pick options, edit a schema, comment on any claim or line, then press **Respond** and paste the one answer back to Claude.

Needs `node` to pack the page into a single file. No other dependencies.

See `skills/html-plan/examples/scheduled-send.html` for a full plan.
