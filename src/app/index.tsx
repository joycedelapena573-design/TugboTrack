/**
 * Splash / loading screen (mockup 1). Shown on every app open, whether the
 * teacher is new or returning, then routes to MPIN setup or MPIN login.
 */
import { useEffect, useState } from 'react';
import { Animated, StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';

import {
  BookDoodle,
  BookStack,
  BottomWave,
  CapIcon,
  ClipboardCheckIcon,
  Leaf,
  Swoosh,
  TopCornerCurve,
} from '../components/decor';
import { SchoolLogo } from '../components/SchoolLogo';
import { colors, fonts } from '../lib/theme';
import { hasMpin } from '../lib/mpin';
import { useStore } from '../lib/store';

const SPLASH_MS = 2400;

export default function Splash() {
  const router = useRouter();
  const { width, height } = useWindowDimensions();
  const [progress] = useState(() => new Animated.Value(0));
  const [decided, setDecided] = useState(false);
  const hydrated = useStore((s) => s.hydrated);

  useEffect(() => {
    Animated.timing(progress, {
      toValue: 1,
      duration: SPLASH_MS,
      useNativeDriver: false,
    }).start();
  }, [progress]);

  useEffect(() => {
    if (decided) return;
    const minDelay = new Promise((res) => setTimeout(res, SPLASH_MS));
    const ready = new Promise<boolean>((res) => {
      if (hydrated) res(true);
      else {
        const unsub = useStore.subscribe((s) => {
          if (s.hydrated) {
            unsub();
            res(true);
          }
        });
      }
    });
    void Promise.all([minDelay, ready]).then(async () => {
      const mpinSet = await hasMpin();
      setDecided(true);
      router.replace(mpinSet ? '/mpin-login' : '/mpin-setup');
    });
  }, [decided, hydrated, router]);

  const barWidth = progress.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <View style={styles.root}>
      <LinearGradient colors={['#F7FAFF', '#E3EDFD']} style={StyleSheet.absoluteFill} />

      {/* decorative background */}
      <View style={[styles.decor, { top: -width * 0.02, left: -width * 0.14 }]}>
        <TopCornerCurve width={width * 0.62} height={width * 0.44} />
      </View>
      <View style={{ position: 'absolute', top: height * 0.02, right: width * 0.04, opacity: 0.9 }}>
        <BookDoodle size={width * 0.28} />
      </View>
      <View style={{ position: 'absolute', top: height * 0.55, left: -8, opacity: 0.5 }}>
        <Leaf size={44} />
      </View>
      <View style={{ position: 'absolute', top: height * 0.5, right: -6, opacity: 0.45 }}>
        <Leaf size={38} color="#A9C6F7" />
      </View>
      <View style={{ position: 'absolute', bottom: -10, left: -width * 0.06 }}>
        <BookStack width={width * 0.62} />
      </View>
      <View style={{ position: 'absolute', bottom: 0, right: 0 }}>
        <BottomWave width={width} height={Math.max(150, height * 0.16)} />
      </View>

      <SafeAreaView style={styles.content} edges={['top', 'bottom']}>
        <View style={styles.center}>
          <SchoolLogo size={width * 0.36} />

          <View style={styles.wordmarkWrap}>
            <View style={[styles.cap, { left: width * 0.31 }]}>
              <CapIcon size={46} />
            </View>
            <Text
              style={styles.wordmark}
              numberOfLines={1}
              adjustsFontSizeToFit
              minimumFontScale={0.55}
            >
              <Text style={{ color: colors.navyDark }}>Class</Text>
              <Text style={{ color: colors.blue }}>Track</Text>
            </Text>
          </View>

          <View style={styles.dividerRow}>
            <View style={styles.dash} />
            <Text style={styles.schoolName} numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.6}>
              Tugbo Integrated School
            </Text>
            <View style={styles.dash} />
          </View>

          <Text style={styles.tagline}>
            Smarter Class Records,{'\n'}Made Simple.
          </Text>
          <Swoosh width={width * 0.4} />

          <View style={[styles.pill, { marginTop: height * 0.035, maxWidth: width * 0.82 }]}>
            <ClipboardCheckIcon size={30} />
            <Text style={styles.pillText} numberOfLines={1}>
              Loading your class records...
            </Text>
          </View>

          <View style={[styles.track, { width: width * 0.42 }]}>
            <Animated.View style={[styles.fill, { width: barWidth }]} />
          </View>
        </View>

        <View style={styles.footerWrap} pointerEvents="none">
          <Text style={styles.footer}>
            Your Class Records,{`\n`}Organized.
          </Text>
          <Swoosh width={110} />
        </View>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  decor: { position: 'absolute' },
  content: { flex: 1, justifyContent: 'space-between' },
  center: { flex: 1, alignItems: 'center', paddingTop: '6%' },
  wordmarkWrap: { marginTop: 14, alignItems: 'center' },
  cap: { position: 'absolute', top: -30 },
  wordmark: {
    fontFamily: fonts.extrabold,
    fontSize: 42,
    letterSpacing: -1,
    color: colors.navyDark,
  },
  dividerRow: { flexDirection: 'row', alignItems: 'center', marginTop: 10, gap: 10 },
  dash: { width: 26, height: 3, borderRadius: 2, backgroundColor: colors.blueSoft },
  schoolName: {
    fontFamily: fonts.semibold,
    fontSize: 17,
    color: colors.navy,
    letterSpacing: 0.2,
  },
  tagline: {
    fontFamily: fonts.scriptBold,
    fontSize: 30,
    color: colors.navy,
    textAlign: 'center',
    marginTop: 18,
    lineHeight: 34,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: colors.white,
    borderRadius: 999,
    paddingVertical: 14,
    paddingHorizontal: 22,
    shadowColor: colors.navy,
    shadowOpacity: 0.1,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 4,
  },
  pillText: { fontFamily: fonts.semibold, fontSize: 15, color: colors.navy },
  track: {
    height: 12,
    borderRadius: 8,
    backgroundColor: '#C6D9F5',
    marginTop: 18,
    overflow: 'hidden',
  },
  fill: { height: '100%', borderRadius: 8, backgroundColor: colors.navy },
  footerWrap: { alignItems: 'flex-end', paddingRight: 26, paddingBottom: 4 },
  footer: {
    fontFamily: fonts.scriptBold,
    fontSize: 24,
    color: colors.white,
    textAlign: 'right',
    lineHeight: 26,
  },
});
