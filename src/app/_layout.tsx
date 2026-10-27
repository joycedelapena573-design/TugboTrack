/** Root layout: fonts, native splash hand-off, and the app re-lock listener. */
import { useEffect } from 'react';
import { AppState } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as SplashScreen from 'expo-splash-screen';
import { useFonts } from 'expo-font';
import { Caveat_600SemiBold, Caveat_700Bold } from '@expo-google-fonts/caveat';
import {
  Poppins_400Regular,
  Poppins_500Medium,
  Poppins_600SemiBold,
  Poppins_700Bold,
  Poppins_800ExtraBold,
} from '@expo-google-fonts/poppins';

import { useAppLock } from '../lib/appLock';
import { colors } from '../lib/theme';

SplashScreen.preventAutoHideAsync().catch(() => {});

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    Poppins_400Regular,
    Poppins_500Medium,
    Poppins_600SemiBold,
    Poppins_700Bold,
    Poppins_800ExtraBold,
    Caveat_600SemiBold,
    Caveat_700Bold,
  });
  const setLocked = useAppLock((s) => s.setLocked);

  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      // Re-lock as soon as the app leaves the foreground (requirement 6.2/6.4).
      if (state === 'background' || state === 'inactive') setLocked(true);
    });
    return () => sub.remove();
  }, [setLocked]);

  useEffect(() => {
    if (fontsLoaded || fontError) {
      SplashScreen.hideAsync().catch(() => {});
    }
  }, [fontsLoaded, fontError]);

  return (
    <>
      <StatusBar style="dark" />
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: colors.bg },
          animation: 'slide_from_right',
        }}
      >
        <Stack.Screen name="index" options={{ animation: 'fade' }} />
        <Stack.Screen name="mpin-setup" options={{ animation: 'fade' }} />
        <Stack.Screen name="mpin-login" options={{ animation: 'fade' }} />
        <Stack.Screen name="(main)" options={{ animation: 'fade' }} />
      </Stack>
    </>
  );
}
