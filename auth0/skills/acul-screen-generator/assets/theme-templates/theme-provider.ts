// ACUL Screen Generator — styled-components ThemeProvider template
// Replace {{TOKEN}} placeholders with extracted design tokens from Phase 5

export const theme = {
  colors: {
    primary:          '{{COLOR_PRIMARY}}',         // e.g., '#4F46E5'
    primaryHover:     '{{COLOR_PRIMARY_HOVER}}',   // e.g., '#4338CA'
    primaryText:      '{{COLOR_PRIMARY_TEXT}}',    // e.g., '#FFFFFF'
    background:       '{{COLOR_BACKGROUND}}',      // e.g., '#F9FAFB'
    surface:          '{{COLOR_SURFACE}}',         // e.g., '#FFFFFF'
    textPrimary:      '{{COLOR_TEXT_PRIMARY}}',    // e.g., '#111827'
    textSecondary:    '{{COLOR_TEXT_SECONDARY}}',  // e.g., '#6B7280'
    textPlaceholder:  '{{COLOR_TEXT_PLACEHOLDER}}',// e.g., '#9CA3AF'
    border:           '{{COLOR_BORDER}}',          // e.g., '#E5E7EB'
    error:            '{{COLOR_ERROR}}',           // e.g., '#EF4444'
    errorBg:          '{{COLOR_ERROR_BG}}',        // e.g., '#FEF2F2'
    success:          '{{COLOR_SUCCESS}}',         // e.g., '#22C55E'
  },
  typography: {
    fontFamily:     "'{{FONT_FAMILY}}', ui-sans-serif, system-ui, sans-serif",
    fontSizeHeading:'{{FONT_SIZE_HEADING}}',        // e.g., '1.5rem'
    fontSizeBody:   '{{FONT_SIZE_BODY}}',           // e.g., '0.875rem'
    fontWeightBold: '{{FONT_WEIGHT_HEADING}}',      // e.g., '700'
  },
  radii: {
    card:   '{{RADIUS_CARD}}',   // e.g., '12px'
    input:  '{{RADIUS_INPUT}}',  // e.g., '8px'
    btn:    '{{RADIUS_BTN}}',    // e.g., '8px'
    full:   '9999px',
  },
  spacing: {
    cardPadding: '{{SPACE_CARD_PADDING}}',  // e.g., '32px'
    formGap:     '{{SPACE_FORM_GAP}}',      // e.g., '16px'
  },
  shadows: {
    card:       '0 1px 3px rgba(0,0,0,0.10), 0 1px 2px rgba(0,0,0,0.06)',
    inputFocus: '0 0 0 3px {{COLOR_PRIMARY_FOCUS_RING}}',
  },
} as const

export type Theme = typeof theme

// Usage in app entry point:
// import { ThemeProvider } from 'styled-components'
// import { theme } from './theme'
// <ThemeProvider theme={theme}><App /></ThemeProvider>

// Usage in styled component:
// const Button = styled.button`
//   background: ${({ theme }) => theme.colors.primary};
//   border-radius: ${({ theme }) => theme.radii.btn};
// `
