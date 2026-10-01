# Blocks

Every block's **source text goes in `<script type="text/plain">…</script>` as its first child**. Inside it `<`, `>` and generics are safe. Without it the first stray `<` cuts the block short, and pack reports an error.

One convention runs through the line-based blocks: start a line with **`+`** for added or proposed, **`-`** for removed, **`~`** for changed.

Everything the reader can see is a comment target: claims, code lines, call rows, arrows, `data-ref` elements and pins in mockups, quotes, notes, list items. You write nothing for that.

## `doc-plan` and `doc-claim`

| Attribute | On | Does |
|---|---|---|
| `open="0…3"` or `open="needs"` | `doc-plan` | how far the tree starts open. Default `1`: behaviours open, hows closed. `needs` opens only the paths to decisions |
| `aux="shared"` / `aux="scope"` | `doc-claim` | the two unnumbered last branches |
| `at="path:line"` | level-3 `doc-claim` | a tap on the call row with the same `@ path:line` opens this claim. With no `<p>`, the file name becomes the claim |
| `kind="…"` | `doc-claim` | overrides the chip on the row (normally read from the exhibit: screen, states, calls, schema, code) |
| `id` | `doc-claim` | for links: `<a href="#id">`. A link into a closed claim opens the way to it |

The first child of a claim is a `<p>` with the claim; `<code>` and `<b>` are fine inside it. Then one exhibit. Then, if needed, a `doc-ask` or a `doc-note`. Then child claims.

The reader gets: numbered claims; **open to What › How › Where › Code**; **Needs you**; a count of decisions on every closed parent; parents that stay pinned while scrolling; a comment button on every claim.

## `doc-mock` — real HTML in a frame, scaled to fit

```html
<doc-mock frame="none" w="440"><template>
<div class="ui">
  <div class="ft"><span class="btn pri">Send</span><span class="btn" data-ref="later">Send later ▾</span></div>
</div></template>
  <doc-pin ref="later" title="New button">Send is unchanged.</doc-pin>
</doc-mock>

<doc-mock frame="terminal" title="postbox" w="470"><template><span class="dim">></span> postbox send --at "mon 8:00"
<span class="g">✓</span> Scheduled for <b>Mon 8:00</b></template></doc-mock>
```

- `frame="none|browser|phone|desktop|terminal"`. `w` is the width you design at. The mock renders at that width in a shadow root and scales down to the column. `h` clips the height. `url` and `title` fill the chrome. `label` sits above, `caption` below.
- **Draw the smallest region that makes the point**: one card, one menu, one row, at `w` ≤ 480 with `frame="none"`. It then stays readable on a phone. A full window is an overview only; add `thumbnail` to say you mean it.
- Write real markup with inline styles or a `<style>` in the template. Several mocks of one app share CSS through one page-level `<style data-mock-shared>…</style>`.
- The terminal frame is a dark mono surface with helpers: `<b>`, `.dim .g .r .y .b .m .o .inv .box`. Keep it to `w` ≤ 480, about 55 columns.
- `data-ref="name"` makes an element a comment target. `<doc-pin ref="name" title="…">` puts a numbered pin on its corner (`anchor="tr|tl|br|bl|r|l|c"`, `offset="dx,dy"`). `at="x%,y%"` places a pin with no element. The `title` is the point, in a few words; the body is optional. Give two pins on neighbours different anchors.
- **A behaviour whose output is text** (a CLI, a log, a generated file) is a `frame="terminal"` mock, or a `doc-code` of the output.
- `doc-shot src="before.png"` is the same for a screenshot. Use screenshots for UI that exists and mocks for UI that does not.

## `doc-machine` — a lifecycle, with the screen for each state

```html
<doc-machine name="msg" caption="Dashed green is proposed.">
<script type="text/plain">
machine msg initial scheduled
state scheduled   # Saved. Waiting for its time.
state sending     # The worker holds it.
state sent      final   # Moved to Sent.
state failed      # Kept, with the error.
state cancelled final   # Back in Drafts.

| scheduled | sending | sent |
| cancelled | failed  | .    |

scheduled -due->    sending   : at send_at
sending   -ok->     sent      : 250
sending   -fail->   failed    : error
scheduled -cancel-> cancelled : Cancel
failed    -cancel-> cancelled : Cancel
+ failed  -retry->  sending   : retry ×3
</script>
  <div data-state="scheduled"><doc-mock …>…</doc-mock></div>     <!-- the screen while in that state -->
  <div data-state="failed"><doc-mock …>…</doc-mock></div>
</doc-machine>
```

- `state id [final]  # one short sentence`. `from -event-> to : label`. An arrow shows its label, or the event name if it has none, so keep labels to a key, a code or two words.
- **The `| a | b | . |` rows place the states**, like ASCII art. Put the main path on the top row and the ways out below it. Without a grid the layout is automatic and labels overlap once arrows cross.
- The reader sees the diagram, one line about the current state, and that state's screen. A tap on a state moves there. Arrows out of it light up.
- `+` and `-` work on arrows only. Use `+` for an arrow that hangs on a decision. If the whole machine is new, mark nothing.
- Pack refuses states that cannot be reached and dead ends that are not `final`. Keep it to 8 states.
- The state is published like an answer: `<div data-if="msg=failed">…</div>` shows only in that state.

## `doc-calls` — what changes, as call trees

```html
<doc-calls title="Scheduling" caption="Tap the second call to open its code.">
<script type="text/plain">
~ <Composer/>                                  @ web/src/composer/Composer.tsx:41
+   <**SendLaterMenu**/>                       @ web/src/composer/SendLaterMenu.tsx:12
+     POST /api/scheduled                      @ web/src/api/scheduled.ts:9
-   legacyQueue(message)                       @ web/src/composer/queue.ts:30   -- no longer used
?   trackScheduled()                           @ web/src/metrics.ts:14          -- proposed; strike it if not wanted
    saveDraft()                                @ web/src/drafts.ts:22
</script>
</doc-calls>
```

- One call per line. Column 0 is the mark: `+` new call, `-` removed, `~` changed entrypoint, `?` proposed (drawn dashed), a space for context. An entrypoint's text starts at column 2, marked or not. Each level adds 2 spaces.
- `**bold**` marks a **new symbol**. A `+` row without bold is a new call to something that exists.
- End a line with `@ path:line` and, if needed, `-- one clause`. A blank line starts a new entrypoint.
- A tap on a row opens the code there. Pack embeds ±6 lines when it can find the file (`--root <repo>`, `ref="<sha>"`), so always write `@ path:line`. Files that do not exist yet open nothing. For a new function in a file that exists, cite the line it goes after. Either way, give the important one a level-3 claim with a sketch; a tap then opens that claim as well.
- The reader can **strike** or comment on any marked row: the two buttons show on hover, or after a tap. A struck row takes its subtree with it, and the response lists it. `files` adds a pane of files touched. `<template for="symbol">…</template>` hangs any block off a row.
- Keep one tree under about 15 rows in a plan.

## `doc-schema` — a data shape, as text in its own language

```html
<doc-schema id="table" lang="sql" diff title="scheduled_messages" caption="Green is proposed. Red goes away.">
<script type="text/plain">
 CREATE TABLE scheduled_messages (
   id       uuid PRIMARY KEY,
-  state    text NOT NULL,
+  status   text NOT NULL CHECK (status IN ('scheduled','sent','failed')),
   send_at  timestamptz NOT NULL
 );
</script>
</doc-schema>
```

- `lang` is required: `ts`, `sql`, `proto`, `json`, `py`, `graphql`, whatever the project states the shape in. In untyped code, write a JSDoc typedef or an object literal with a comment per key (`lang="js"`). `title` names it. Give it an `id` so edits survive a reload.
- If the shape exists, cite it: `src="path" lines="a-b"` fills the block from the file.
- `diff` marks a change: `+`, `-`, and a leading space on every other line.
- Notes are comments in that language, a clause long. Show the 5 to 10 members that matter, then `// … 14 more`.
- The reader can comment on a line and press **Edit**. An edit comes back as a diff.

## `doc-code` — a slice of code, with pins

```html
<doc-code src="server/src/mail/send.ts" lines="20-34" hl="27">
  <doc-pin line="27" tone="warn" title="Throws on a refused address">The worker must catch this.</doc-pin>
</doc-code>

<doc-code title="limits.ts · sketch" lang="ts">
<script type="text/plain">
export async function assertUnderLimit(userId: string) {
  if (await store.countScheduled(userId) >= 50) throw new LimitError(50)
}
</script>
</doc-code>
```

- **Code that exists:** `src` + `lines="a-b"` (`lines="40"` is one line). Pack reads the file under `--root`, and stamps the commit if that is a git checkout. `ref="<sha|branch>"` reads it from git.
- **Code that does not exist:** paste a sketch and say “sketch” in `title`. `lang` sets the highlighting. `start="38"` sets the first line number.
- **A change to code that exists:** add `diff` and `file="path"`, and paste unified-diff lines. `start="N"` or an `@@ -a,b +c,d @@` header numbers the gutter. One file per block. Never cut lines out of the middle of a hunk. A diff is a proposal already, so it needs no “sketch”.
- `doc-pin line="N"` uses the number shown in the gutter (`old="N"` for a removed line). `tone="info|warn|risk|ok"`. A pin says what the line is, in a clause.
- 10 to 25 lines. `hl="4-5,9"` highlights. `wrap` soft-wraps long lines. `caption` adds a line under the header. `collapsed` starts it closed.

## `doc-ask` — a decision

```html
<doc-ask id="retry">
  <p>Should a failed send retry on its own?</p>
  <label><input type="radio" name="retry" value="3" checked> Yes, 3 times, 5 minutes apart</label>
  <label><input type="radio" name="retry" value="no"> No <small>the user presses “Try again”</small></label>
</doc-ask>
<div data-if="retry=no"><doc-note tone="warn">Then claim 4 fires on the first failure.</doc-note></div>
```

- It is a form. Radios pick one; checkboxes with one `name` pick several; `<textarea name>` and `<input type=text name>` take text; `<input type=range name min max value>` is a scale; `<ol class="rank" data-name="x"><li data-value="a">` is drag to rank. `<div class="opts-row">` lays short options side by side.
- The first `<p>` is the question, 15 words at most.
- **`checked` is your recommendation.** It gets a “suggested” tag, and “I changed nothing” is then a full answer. Never leave a radio group without one.
- Control names must be unique on the page.
- `data-if="name=value"` (`!=`, `~` contains, `&&`) on any element shows it only under that answer. Use it for consequences.

## `doc-quote` — who asked, in their words

```html
<details class="thread"><summary>Why · 2 requests</summary>
  <doc-quote via="prompt" from="the user">add send later to the composer… it must never go out early</doc-quote>
  <doc-quote via="github" from="dana" at="2026-03-02" href="https://…">…</doc-quote>
</details>
```

`via="prompt|slack|github|doc|email|meeting|transcript"`. Quote, do not paraphrase. Trim with `…`.

## `doc-note`

`<doc-note tone="info|warn|risk|ok|idea"><strong>Risk</strong> One or two sentences.</doc-note>`. Use it under an exhibit for a risk the reader should weigh.

## Also in the runtime

Reach for these only when nothing above fits.

```html
<doc-flow caption="Two stores feed one function.">       <!-- parts and how they connect; ≤ 12 nodes, 2–3 columns -->
<script type="text/plain">
api  = API / routes.ts
db   = scheduled_messages [db]
+ wk = Worker / worker.ts [green]
| api | db |
| .   | wk |
api -> db : insert
wk -> db : claim
</script>
</doc-flow>

<doc-tree caption="One new folder.">                       <!-- which files exist -->
<script type="text/plain">
server/src/
  + scheduled/     # all new
  ~ mail/send.ts   # called, not changed
</script>
</doc-tree>

<doc-draft id="copy" label="The failure notice">            <!-- long text the reader should edit; comes back as a diff -->
<script type="text/plain">
We tried 3 times. It is in Scheduled.
</script>
</doc-draft>
```

For a few steps in order, use plain cards: `<div class="cols"><div class="card"><h4>1 · Reader</h4><p>…</p></div>…</div>`.

## pack.mjs

```
node runtime/pack.mjs plan.html [--root <repo>]… [-o out.html] [--lint-only] [--artifact] [--quiet]
```

- Lints every block with the same parsers the browser uses, and the shape of the tree.
- Fills `src=` blocks and call-row excerpts from `--root` (or from git with `ref=`). With several `--root`s it looks in each in order, then beside the page. It reads nothing outside those folders, refuses files that look like they hold a secret, and ends by listing every file whose code is now inside the page. Check that list before you publish or share.
- Inlines the runtime and local images. Writes `plan.packed.html`.
- `--artifact` also writes `plan.artifact.html`, the page without its own `<html>` and `<body>`, for a host that adds them.
- Errors stop the write. Warnings are budgets for words and phone width: fix them or accept them knowingly.
