/** TIS ClassTrack brand theme, taken from the approved mockups. */

export const colors = {
  navy: '#0A3A8C',
  navyDark: '#082E6E',
  blue: '#2563EB',
  blueSoft: '#5B8DEF',
  ice: '#EAF2FD',
  iceDeep: '#D7E7FB',
  bg: '#F4F8FF',
  card: '#FFFFFF',
  border: '#DCE7F7',
  text: '#0B2E6E',
  textSoft: '#5A6E96',
  textFaint: '#93A3C4',
  gold: '#F2B01E',
  green: '#1B7F4B',
  red: '#C0392B',
  amber: '#B26A00',
  white: '#FFFFFF',
};

export const fonts = {
  regular: 'Poppins_400Regular',
  medium: 'Poppins_500Medium',
  semibold: 'Poppins_600SemiBold',
  bold: 'Poppins_700Bold',
  extrabold: 'Poppins_800ExtraBold',
  script: 'Caveat_600SemiBold',
  scriptBold: 'Caveat_700Bold',
};

export const radius = {
  sm: 10,
  md: 14,
  lg: 18,
  xl: 26,
  pill: 999,
};

export const spacing = (n: number) => n * 4;

export const shadow = {
  card: {
    shadowColor: '#0A3A8C',
    shadowOpacity: 0.08,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 6 },
    elevation: 3,
  },
  soft: {
    shadowColor: '#0A3A8C',
    shadowOpacity: 0.06,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 3 },
    elevation: 2,
  },
};
