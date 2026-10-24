/** Shared visual tokens for the app. Kept deliberately small. */

export const colors = {
  bg: '#F4F6FB',
  surface: '#FFFFFF',
  surfaceAlt: '#EEF1F8',
  border: '#DDE2ED',
  text: '#12172A',
  textMuted: '#616B84',
  primary: '#2F5BEA',
  primarySoft: '#E6ECFE',
  success: '#137A4B',
  successSoft: '#DFF4E9',
  warning: '#9A6200',
  warningSoft: '#FDF0D5',
  danger: '#C0362C',
  dangerSoft: '#FBE5E3',
  overlay: 'rgba(15, 20, 40, 0.45)',
} as const;

export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 } as const;

export const radius = { sm: 8, md: 12, lg: 18, pill: 999 } as const;

export type Tone = 'neutral' | 'primary' | 'success' | 'warning' | 'danger';

export const toneColors: Record<Tone, { fg: string; bg: string }> = {
  neutral: { fg: colors.textMuted, bg: colors.surfaceAlt },
  primary: { fg: colors.primary, bg: colors.primarySoft },
  success: { fg: colors.success, bg: colors.successSoft },
  warning: { fg: colors.warning, bg: colors.warningSoft },
  danger: { fg: colors.danger, bg: colors.dangerSoft },
};