# HTML Dashboard Template Notes

Reference for the standalone HTML output produced by the tres-recon-gaps skill.

## Visual design spec

**Theme:** Dark financial dashboard
- Background: `#0d0f12`
- Surface cards: `#13161b`
- Secondary surface: `#1a1e25`
- Borders: `rgba(255,255,255,0.07)` (default), `rgba(255,255,255,0.12)` (hover)
- Text primary: `#e8eaed`
- Text muted: `#8a919e`
- Text dim: `#555d6b`

**Accent colors (semantic):**
- Positive gap / INFLOW: `#4f8ef7` (blue)
- Negative gap / OUTFLOW: `#f7614f` (red)
- Auto-fill / purple actions: `#9d7fea`
- Pending warning: `#f5a623` (amber)
- Success toast: `#3ecf8e` (green)

**Typography:**
- Display / headings: `Syne` (Google Fonts) — weight 600-700
- Body / UI: `DM Sans` — weight 300-500
- Numbers / addresses / mono: `IBM Plex Mono` — weight 400-500

All three fonts loaded from Google Fonts. Fallback to system-ui if unavailable.

## Page structure

```
<sticky header>           logo + refresh timestamp badge
<main>
  <page title row>        "Reconciliation Gaps" + subtitle
  <summary cards>         5 metric cards in a grid
  <toolbar>               search input + 3 selects + item count pill
  <asset groups>          collapsible group blocks
    <group header>        avatar circle + name + platform list + net fiat + chevron
    <table>               8 columns (see column spec below)
</main>
<plug modal overlay>
<auto-fill modal overlay>
<toast>                   bottom-right notification
```

## Column spec (table)

| # | Header | Width | Alignment | Notes |
|---|--------|-------|-----------|-------|
| 1 | Wallet | 180px | left | name on top, short address below (clickable → copy) |
| 2 | Platform | 150px | left | badge pill with border |
| 3 | Fiat gap (USD) | 130px | right | blue/red color, signed |
| 4 | Token gap | 140px | right | blue/red color, signed |
| 5 | On-chain bal. | 140px | right | dim color, no sign |
| 6 | Calculated bal. | 140px | right | dim color, no sign |
| 7 | Pending txs | 110px | center | amber badge if > 0, else "—" |
| 8 | Actions | 190px | right | two copy-prompt buttons side by side |

Min-width on table: 900px (allows horizontal scroll on narrow viewports).

## Group header spec

```
[avatar] [name]           [N rows] [net fiat gap]  [▼]
         [platforms list]
```

- Avatar: 36×36px rounded rectangle, purple tint, 2-letter initials from asset symbol
- Net fiat gap: colored blue/red based on sign
- Chevron: rotates 180° when open, click entire header to toggle
- Groups start **open** by default

## Action buttons (per row)

Each row has two buttons in the Actions column:

- **↳ Plug** (blue outline) — copies a ready-to-paste prompt for a one-time plug
- **⟳ Auto-fill** (purple outline) — copies a ready-to-paste prompt for a gap-fill rule

On click, the button copies the prompt to clipboard, briefly shows **"✓ Copied"**, and a toast appears at the bottom-right:

> **Prompt copied — paste it in the Claude chat to resolve this gap.**

### Prompt formats

**Plug prompt (one-liner):**
```
Please plug the reconciliation gap for wallet "<name>" (<short-address>), asset <symbol> on <platform>. Direction: <INFLOW/OUTFLOW>, amount: <amount> (<$fiat>).
```

**Auto-fill prompt (one-liner):**
```
Please create an auto gap-fill rule for wallet "<name>" (<short-address>), asset <symbol> on <platform>, with a daily interval.
```

Both prompts are fully self-contained — the user pastes one into the Claude chat and Claude handles the rest.

## Behavior notes

- ESC key closes any open modal
- Clicking outside the modal (on the overlay) closes it
- Address cells: clicking copies address to clipboard + shows toast
- Filters: search (text), direction (All/Positive/Negative), platform (all platforms auto-populated)
- All filters update the "X items" count pill in real time
- Refresh timestamp in header shows time the page was loaded

## No in-browser API calls

The HTML file makes **no HTTP requests**. It is a pure display interface.

All mutations are executed by Claude after the user copies a prompt from the dashboard and pastes it into the chat. Claude already has an authenticated MCP session — no credentials are needed in the browser.
