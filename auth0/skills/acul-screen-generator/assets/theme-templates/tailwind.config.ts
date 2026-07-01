import type { Config } from 'tailwindcss'

// ACUL Screen Generator — Tailwind theme template
// Replace token values with extracted design tokens from Phase 5

const tokens = {
  primary:        '{{COLOR_PRIMARY}}',        // e.g., '#4F46E5'
  primaryHover:   '{{COLOR_PRIMARY_HOVER}}',  // e.g., '#4338CA'
  primaryText:    '{{COLOR_PRIMARY_TEXT}}',   // e.g., '#FFFFFF'
  background:     '{{COLOR_BACKGROUND}}',     // e.g., '#F9FAFB'
  surface:        '{{COLOR_SURFACE}}',        // e.g., '#FFFFFF'
  textPrimary:    '{{COLOR_TEXT_PRIMARY}}',   // e.g., '#111827'
  textSecondary:  '{{COLOR_TEXT_SECONDARY}}', // e.g., '#6B7280'
  border:         '{{COLOR_BORDER}}',         // e.g., '#E5E7EB'
  error:          '{{COLOR_ERROR}}',          // e.g., '#EF4444'
  success:        '{{COLOR_SUCCESS}}',        // e.g., '#22C55E'
  radiusCard:     '{{RADIUS_CARD}}',          // e.g., '12px'
  radiusInput:    '{{RADIUS_INPUT}}',         // e.g., '8px'
  radiusBtn:      '{{RADIUS_BTN}}',           // e.g., '8px'
}

export default {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          primary:       tokens.primary,
          'primary-hover': tokens.primaryHover,
          'primary-text':  tokens.primaryText,
          background:    tokens.background,
          surface:       tokens.surface,
          'text-primary':    tokens.textPrimary,
          'text-secondary':  tokens.textSecondary,
          border:        tokens.border,
          error:         tokens.error,
          success:       tokens.success,
        },
      },
      borderRadius: {
        card:  tokens.radiusCard,
        input: tokens.radiusInput,
        btn:   tokens.radiusBtn,
      },
      boxShadow: {
        card: '0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)',
      },
      fontFamily: {
        sans: ['{{FONT_FAMILY}}', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
} satisfies Config
