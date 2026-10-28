/**
 * The school's logo, shown on the loading screen and the MPIN screens.
 * The teacher can insert their own picture from Settings → School Logo;
 * until then the bundled school seal is used.
 */
import { Image, StyleSheet, View, type ImageStyle, type StyleProp } from 'react-native';

import { useStore } from '../lib/store';

export function SchoolLogo({
  size,
  style,
  circle = false,
}: {
  size: number;
  style?: StyleProp<ImageStyle>;
  circle?: boolean;
}) {
  const custom = useStore((s) => s.schoolLogoUri);
  const image = (
    <Image
      source={custom ? { uri: custom } : require('../../assets/school-logo.png')}
      resizeMode="contain"
      style={[{ width: size, height: size }, style]}
    />
  );
  if (!circle) return image;
  return <View style={[styles.circle, { width: size, height: size, borderRadius: size / 2 }]}>{image}</View>;
}

const styles = StyleSheet.create({
  circle: {
    overflow: 'hidden',
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
