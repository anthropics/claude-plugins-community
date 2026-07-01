---
name: acul-screen-generator
description: >
  Use when building or customizing Auth0 Universal Login screens with full UI control — creating branded login, signup, or MFA screens using the ACUL React or Vanilla JS SDK. Use this even if the user says "custom login page", "style my Auth0 login", or "build my own Universal Login UI" without mentioning ACUL directly. Does not cover basic branding (colors/logo only) — use auth0-branding for that.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  openclaw:
    emoji: "🔐"
    homepage: https://github.com/auth0/agent-skills
---

# ACUL Screen Generator

Generates production-ready, fully themed Auth0 ACUL screen components. Follows a strict 8-phase workflow (Phases 0–7): CLI authentication → intent detection → project setup → screen requirements → tech stack and design → theme extraction → structured code generation → dev mode wiring.

## Reference Hierarchy

Always resolve the correct reference for a screen using this priority order:

```
1. auth0-acul-samples  (31 React screens, 3 React-JS screens)
   → Complete modular implementation: index.tsx + components/ + hooks/ + locales/
   → React:    https://github.com/auth0-samples/auth0-acul-samples/tree/main/react/src/screens/<screen-name>
   → React-JS: https://github.com/auth0-samples/auth0-acul-samples/tree/main/react-js/src/screens/<screen-name>

2. SDK examples  (68 React, 71 JS — all screens)
   → Code snippets showing SDK imports, hooks, and action functions
   → React: https://github.com/auth0/universal-login/blob/master/packages/auth0-acul-react/examples/<screen-name>.md
   → JS:    https://github.com/auth0/universal-login/blob/master/packages/auth0-acul-js/examples/<screen-name>.md

3. assets/react-templates/ or assets/js-templates/
   → Structural component pattern only — never use their hooks/actions for other screens
```

For which screens are in auth0-acul-samples → read `references/screen-catalog.md`.

---

## auth0-acul-samples Architecture

When a screen is available in auth0-acul-samples, generate code using this modular pattern — not a monolithic component.

**Directory structure per screen:**
```
<screen-name>/
├── index.tsx                        thin entry: wires manager hook + applies theme + renders layout
├── components/
│   ├── Header.tsx                   logo, title, subtitle from screen.texts
│   ├── <ScreenName>Form.tsx         form fields, submit, captcha, passkey button
│   ├── Footer.tsx                   signup link, forgot password, back link
│   └── AlternativeLogins.tsx        social login buttons (if screen has social)
├── hooks/
│   └── use<ScreenName>Manager.ts    wraps SDK hooks, exposes clean handlers + feature flags
└── locales/
    └── en.json                      fallback text strings
```

**index.tsx pattern:**
```tsx
import { ULThemeCard, ULThemePageLayout } from '@/components'
import { applyAuth0Theme } from '@/utils/theme/themeEngine'
import Header from './components/Header'
import <ScreenName>Form from './components/<ScreenName>Form'
import Footer from './components/Footer'
import { use<ScreenName>Manager } from './hooks/use<ScreenName>Manager'

export const <ScreenName>Screen = () => {
  const { sdkInstance, texts, locales } = use<ScreenName>Manager()
  applyAuth0Theme(sdkInstance)
  document.title = texts?.pageTitle ?? locales.pageTitle

  return (
    <ULThemePageLayout>
      <ULThemeCard>
        <Header texts={texts} />
        <AlternativeLogins alignment="top" />    {/* conditional */}
        <<ScreenName>Form />
        <Footer texts={texts} links={links} />
        <AlternativeLogins alignment="bottom" />  {/* conditional */}
      </ULThemeCard>
    </ULThemePageLayout>
  )
}
```

**hooks/use\<ScreenName\>Manager.ts pattern:**
```ts
import { useLoginId, useScreen, useTransaction } from '@auth0/auth0-acul-react/<screen-name>'
import { executeSafely } from '@/utils/helpers/executeSafely'
import locales from '../locales/en.json'

export const use<ScreenName>Manager = () => {
  const sdkInstance = useLoginId()       // screen-specific SDK hook
  const screen = useScreen()
  const { alternateConnections } = useTransaction()

  const handleSubmit = async (data) => executeSafely(() => login(data))
  const handleFederatedLogin = async (conn) => executeSafely(() => federatedLogin({ connection: conn }))

  return {
    sdkInstance,
    texts: screen.texts,
    locales,
    alternateConnections,
    handleSubmit,
    handleFederatedLogin,
    isPasskeyEnabled: screen.isPasskeyEnabled,
    isCaptchaAvailable: screen.isCaptchaAvailable,
  }
}
```

When a screen is **not** in auth0-acul-samples, fall back to a single-file component based on the SDK example.

## Prerequisites

- Auth0 CLI installed: `brew install auth0`
- Custom domain configured on the Auth0 tenant (hard ACUL requirement)
- Node.js 18+

---

## Phase 0: CLI Authentication & Tenant Check

```bash
auth0 login
auth0 acul config list --rendering-mode advanced
```

If `auth0 acul config list` returns an error about custom domain: stop and inform the customer they must configure a custom domain on their tenant before ACUL is available.

For full CLI flag reference → read `references/cli-commands.md`.

---

## Phase 1: Intent Detection

Ask the customer which mode they need:

- **A) Build from scratch** — new project, select screens, full setup
- **B) Add a screen** — existing project, add one or more new screens
- **C) Modify a screen** — existing project, change an existing screen's code or styling

This choice gates Phases 2A / 2B / 2C.

---

## Phase 2A: Scratch — Project Init

Gather: app name, framework (`react` or `js`), initial screen list.

```bash
auth0 acul init <app_name> -t react -s login-id,login-password,signup
auth0 acul config generate <screen-name>    # repeat per screen
```

Verify `acul_config.json` is created in the project directory. Proceed to Phase 3.

---

## Phase 2B: Add Screen — CLI + Reference Fetch

1. Verify `acul_config.json` exists in the project directory.
   - If missing → stop. Instruct customer to run `auth0 acul init` first.

2. Run:
   ```bash
   auth0 acul screen add <screen-name> -d <project-dir>
   ```
   If CLI errors or screen is not recognised → continue to step 3.

3. **Always resolve the reference using the hierarchy** (regardless of CLI success or failure):

   **Step 3a — Check auth0-acul-samples first:**
   - Read `references/screen-catalog.md` to check if the screen has a `✅` in the Samples column
   - If yes → fetch the screen directory from:
     - React: `https://github.com/auth0-samples/auth0-acul-samples/tree/main/react/src/screens/<screen-name>`
     - React-JS: `https://github.com/auth0-samples/auth0-acul-samples/tree/main/react-js/src/screens/<screen-name>`
   - Fetch `index.tsx` and the `hooks/use<ScreenName>Manager.ts` file to understand the full implementation
   - Use the samples architecture (modular: index + components + hooks + locales)

   **Step 3b — If not in samples, fetch SDK example:**
   - React: `https://github.com/auth0/universal-login/blob/master/packages/auth0-acul-react/examples/<screen-name>.md`
   - JS: `https://github.com/auth0/universal-login/blob/master/packages/auth0-acul-js/examples/<screen-name>.md`
   - Parse for: exact import path, hook pattern (generic vs screen-specific), action functions and payload shapes
   - Use a single-file component (no modular split needed)

   This step is mandatory. The 68+ ACUL screens use fundamentally different hook patterns — wrong pattern = broken code.

   For all screen names and which are in samples → read `references/screen-catalog.md`.

---

## Phase 2C: Modify Screen — Fetch Current State

1. Verify `acul_config.json` exists.

2. Fetch current rendering configuration:
   ```bash
   auth0 acul config get <screen-name> -f <screen-name>.json
   auth0 acul config list --rendering-mode advanced
   ```

3. Read the existing screen file from the customer's codebase.

4. **Always resolve the reference using the same hierarchy as Phase 2B** (samples first, SDK example second). Even when modifying an existing file, the reference confirms whether the current code uses the correct hook pattern, action functions, and component structure before making changes.

---

## Phase 3: Screen Requirements

Gather from the customer:

- **Screen type** — for full list of available screens → read `references/screen-catalog.md`
- **Components needed:**
  - Social providers: Google, GitHub, Apple, Microsoft, Facebook
  - Form fields: email, username, phone, password, confirm-password
  - MFA type (if applicable): OTP, SMS, push, WebAuthn
  - Optional extras: captcha, passkey button, remember-me, terms checkbox
- **For modify mode:** what specifically to change (layout, colors, add/remove a component)

---

## Phase 4: Tech Stack Detection

Confirm or detect:

- **Framework:** React (`@auth0/auth0-acul-react`) or JS (`@auth0/auth0-acul-js`)
- **Styling library:** Tailwind CSS / CSS Modules / styled-components / plain CSS
- **Existing theme file?** Check for `tailwind.config.ts`, `styles/tokens.css`, `theme/index.ts`

Load the appropriate SDK reference:
- React → read `references/acul-react-sdk.md`
- JS → read `references/acul-js-sdk.md`

For social button implementation → read `references/social-providers.md`.

---

## Phase 5: Theme Extraction & Scope

### Design input — detect which the customer has provided:

**Option A — Image or mockup (jpeg / png / screenshot):**
Analyze the image and extract:
- Primary, secondary, accent colors (as hex)
- Background and card/surface colors
- Font family and weights
- Border radius style (sharp / slight / rounded / pill)
- Spacing rhythm (compact / normal / spacious)
- Layout type: centered card / full-bleed / split-panel / floating card

**Option B — Brand colors only (no image):**
Derive the full token set from the provided hex values:
```
primary        → button bg, links, focus ring
primary-hover  → primary darkened ~10%
primary-text   → white if primary is dark, else #111827
background     → page background
surface        → card/panel background
text-primary   → headings (#111827 light / #F1F5F9 dark)
text-secondary → labels, placeholders
border         → input borders
error          → #EF4444 (unless specified)
success        → #22C55E (unless specified)
```

### Theme scope — ask the customer:

- **Single screen:** apply tokens inline to just this component's styles
- **All screens:** generate a shared theme file first, then apply consistently across every screen

For theme file patterns per styling library → read `references/theming-patterns.md`.

**Theme file to generate per styling library (all-screens scope):**

| Styling library | Template to use | Output file |
|----------------|-----------------|-------------|
| Tailwind | `assets/theme-templates/tailwind.config.ts` | `tailwind.config.ts` |
| CSS Modules | `assets/theme-templates/tokens.css` | `styles/tokens.css` |
| styled-components | `assets/theme-templates/theme-provider.ts` | `theme/index.ts` |
| Plain CSS | `assets/theme-templates/globals.css` | `styles/globals.css` |

Replace all `{{TOKEN}}` placeholders with extracted token values.

---

## Phase 6: Structured Code Generation

Generation approach depends on whether the screen is in auth0-acul-samples.

### Path A — Screen is in auth0-acul-samples (modular architecture)

Generate the full directory structure using the samples pattern (see "auth0-acul-samples Architecture" above):

```
<screen-name>/
├── index.tsx
├── components/
│   ├── Header.tsx
│   ├── <ScreenName>Form.tsx
│   ├── Footer.tsx
│   └── AlternativeLogins.tsx       (only if screen has social login)
├── hooks/
│   └── use<ScreenName>Manager.ts
└── locales/
    └── en.json
```

- `index.tsx` — thin: calls `use<ScreenName>Manager()`, calls `applyAuth0Theme()`, renders `ULThemePageLayout` → `ULThemeCard` → sub-components
- `use<ScreenName>Manager.ts` — wraps SDK hooks from the samples reference, exposes typed handlers and feature flags
- Form component — uses react-hook-form, reads from manager hook, no direct SDK calls
- Header/Footer — stateless, receive texts as props
- `en.json` — fallback strings matching keys used in `screen.texts.*`

Apply design tokens from Phase 5 to the layout components and form component styling.

### Path B — Screen is NOT in auth0-acul-samples (single-file component)

Generate a single `<screen-name>.tsx` (React) or `<screen-name>.js` (JS) using the structure from `assets/react-templates/` or `assets/js-templates/` as a pattern, with hooks and actions sourced entirely from the SDK example fetched in Phase 2.

JSX structure order:
```
Outer layout wrapper → Card/panel → Logo slot → Title (screen.texts) →
Error banner (conditional) → Form fields → Captcha (conditional) →
Submit button → Passkey button (conditional) → Social divider + buttons
(conditional on alternateConnections) → Footer links
```

### Validation before outputting any code

- SDK import path exactly matches the screen name (e.g., `@auth0/auth0-acul-react/mfa-otp-challenge`)
- Hook pattern (generic `useScreen()` vs screen-specific hook) sourced from the reference, not assumed
- Action function names and payload shapes sourced from the reference
- Error state uses SDK source (`hasErrors` / `getErrors()`) — never local-only error state
- No hardcoded UI strings — use `screen.texts.*` with locale fallback
- `applyAuth0Theme()` called in index.tsx for Path A screens

**All-screens scope:** repeat Path A or Path B (whichever applies per screen) for every screen in the project, all importing from the shared theme file. Consistent component structure within each path.

---

## Phase 7: Dev Mode Wiring

Provide the customer with ready-to-run commands:

```bash
# Local preview — no tenant connection needed
auth0 acul dev -p 3000 -d <project-dir>

# Connected mode — syncs assets to tenant (stage/dev only)
auth0 acul dev --connected -s <screen-name> -d <project-dir>
```

⚠️ Always include this warning when connected mode is suggested:
> Connected mode updates your Auth0 tenant in real time. Only use this on a stage or development tenant — never on production.

---

## Reference Files

| File | Load when |
|------|-----------|
| `references/acul-react-sdk.md` | Framework is React |
| `references/acul-js-sdk.md` | Framework is JS / Vanilla |
| `references/screen-catalog.md` | Selecting screen type or triggering CLI fallback |
| `references/social-providers.md` | Social login buttons are needed |
| `references/theming-patterns.md` | Generating or applying a shared theme file |
| `references/cli-commands.md` | Need full CLI flag details |

## Asset Templates

| File | Use when |
|------|----------|
| `assets/theme-templates/tailwind.config.ts` | Tailwind, all-screens scope |
| `assets/theme-templates/tokens.css` | CSS Modules, all-screens scope |
| `assets/theme-templates/theme-provider.ts` | styled-components |
| `assets/theme-templates/globals.css` | Plain CSS, all-screens scope |
| `assets/react-templates/<screen>.tsx` | React component boilerplate base |
| `assets/js-templates/<screen>.js` | JS component boilerplate base |
