# Theming Patterns for ACUL Screens

---

## Design Token Derivation

When only brand colors are provided (no image), derive the full token set:

```
Input: primary color (e.g., #4F46E5)

Derived tokens:
  --color-primary          = input hex
  --color-primary-hover    = primary darkened ~10%  (hsl lightness -10)
  --color-primary-text     = white if primary is dark, else #111827

  --color-background       = #FFFFFF (light) or #0F172A (dark, if brand is dark)
  --color-surface          = #F9FAFB (light) or #1E293B (dark)
  --color-surface-raised   = #FFFFFF (light) or #293548 (dark)

  --color-text-primary     = #111827 (light) or #F1F5F9 (dark)
  --color-text-secondary   = #6B7280 (light) or #94A3B8 (dark)
  --color-text-placeholder = #9CA3AF

  --color-border           = #E5E7EB (light) or #334155 (dark)
  --color-border-focus     = primary color

  --color-error            = #EF4444
  --color-error-bg         = #FEF2F2
  --color-success          = #22C55E
  --color-success-bg       = #F0FDF4

  --radius-sm              = 4px
  --radius-md              = 8px
  --radius-lg              = 12px
  --radius-full            = 9999px

  --shadow-card            = 0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)
  --shadow-input-focus     = 0 0 0 3px <primary at 20% opacity>
```

---

## Image/Mockup Analysis

When a screenshot or design mockup is provided, extract:

1. **Colors** — sample from key areas:
   - Page background color
   - Card/panel background
   - Primary button color
   - Input border color
   - Text colors (heading, body, placeholder)
   - Error state color

2. **Typography** — identify:
   - Font family (match to Google Fonts or system font stack if custom)
   - Heading size and weight
   - Body text size
   - Button text style

3. **Spatial rhythm** — measure approximate:
   - Card padding (compact ~16px / normal ~24px / spacious ~32px)
   - Input height (small ~36px / medium ~40px / large ~48px)
   - Button border radius (sharp 0px / slight 4px / rounded 8px / pill 9999px)

4. **Layout type:**
   - Centered card (card centered on solid background)
   - Full-bleed (edge-to-edge, no visible card)
   - Split panel (image/brand on left, form on right)
   - Floating card (card with shadow on gradient/image background)

---

## Theme File Patterns by Styling Library

### Tailwind CSS — `tailwind.config.ts`

Use `assets/theme-templates/tailwind.config.ts` as base.

Key pattern:
```typescript
theme: {
  extend: {
    colors: {
      brand: {
        primary: tokens.primary,
        'primary-hover': tokens.primaryHover,
        surface: tokens.surface,
        background: tokens.background,
        error: tokens.error,
      }
    },
    borderRadius: {
      card: tokens.radiusLg,
      input: tokens.radiusMd,
      btn: tokens.radiusMd,
    }
  }
}
```

Usage in components: `bg-brand-primary`, `hover:bg-brand-primary-hover`, `rounded-card`.

### CSS Modules — `styles/tokens.css`

Use `assets/theme-templates/tokens.css` as base.

Pattern: define all tokens as `:root` CSS custom properties.
```css
:root {
  --color-primary: #4F46E5;
  --color-primary-hover: #4338CA;
  /* ... */
}
```

Usage: `background: var(--color-primary)`.

### styled-components — `theme/index.ts`

Use `assets/theme-templates/theme-provider.ts` as base.

Pattern:
```typescript
export const theme = {
  colors: { primary: '#4F46E5', ... },
  radii: { card: '12px', ... }
}

// Wrap app
<ThemeProvider theme={theme}><App /></ThemeProvider>
```

Usage in styled components: `background: ${({ theme }) => theme.colors.primary}`.

### Plain CSS — `styles/globals.css`

Use `assets/theme-templates/globals.css` as base. Same as CSS Modules pattern but applied globally.

---

## Single Screen vs All Screens

### Single screen (inline)
Apply tokens directly in the component's style file. No shared theme file.
```css
/* LoginId.module.css */
.card { background: #FFFFFF; border-radius: 12px; }
.submitBtn { background: #4F46E5; }
```

### All screens (shared theme file)
1. Generate the shared theme file first (`tailwind.config.ts` / `tokens.css` / etc.)
2. All screen components import from that single source of truth
3. Consistency is enforced — changing one variable updates all screens

**File to generate per styling library:**

| Library | File to create | Import in components |
|---------|---------------|----------------------|
| Tailwind | `tailwind.config.ts` | Classes only (no import needed) |
| CSS Modules | `styles/tokens.css` | `@import '../styles/tokens.css'` |
| styled-components | `theme/index.ts` | `import { theme } from '../theme'` |
| Plain CSS | `styles/globals.css` | Import once in entry point |
