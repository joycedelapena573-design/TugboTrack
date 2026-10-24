/**
 * Root layout: providers, shared header styling and the full route table.
 */
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { KeyboardAvoidingView, Platform, StyleSheet } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { StoreProvider } from '@/lib/store';
import { colors } from '@/theme';

const headerOptions = {
  headerStyle: { backgroundColor: colors.surface },
  headerTintColor: colors.text,
  headerTitleStyle: { fontWeight: '700' as const, color: colors.text },
  headerShadowVisible: false,
  contentStyle: { backgroundColor: colors.bg },
};

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <StoreProvider>
        <StatusBar style="dark" />
        <KeyboardAvoidingView
          style={styles.flex}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <Stack screenOptions={headerOptions}>
            <Stack.Screen name="index" options={{ headerShown: false }} />
            <Stack.Screen
              name="mpin/setup"
              options={{ headerShown: false, gestureEnabled: false }}
            />
            <Stack.Screen
              name="mpin/unlock"
              options={{ headerShown: false, gestureEnabled: false }}
            />
            <Stack.Screen name="dashboard" options={{ title: 'Class Records' }} />
            <Stack.Screen
              name="classes/[id]/index"
              options={{ title: 'Class', headerBackTitle: 'Back' }}
            />
            <Stack.Screen name="classes/[id]/assessments" options={{ title: 'Assessments' }} />
            <Stack.Screen name="classes/[id]/grades" options={{ title: 'Quarterly Grades' }} />
            <Stack.Screen name="classes/[id]/bmi" options={{ title: 'BMI Record' }} />
          </Stack>
        </KeyboardAvoidingView>
      </StoreProvider>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({ flex: { flex: 1 } });