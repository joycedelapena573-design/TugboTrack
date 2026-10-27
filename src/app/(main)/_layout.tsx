/** Main tab shell: Home, Attendance, Grades, More. Re-locks when needed. */
import { Ionicons } from '@expo/vector-icons';
import { Redirect, Tabs } from 'expo-router';

import { useAppLock } from '../../lib/appLock';
import { colors, fonts } from '../../lib/theme';

export default function MainLayout() {
  const locked = useAppLock((s) => s.locked);

  if (locked) return <Redirect href="/mpin-login" />;

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.navy,
        tabBarInactiveTintColor: colors.textFaint,
        tabBarStyle: {
          backgroundColor: colors.white,
          borderTopColor: colors.border,
          height: 62,
          paddingBottom: 8,
          paddingTop: 6,
        },
        tabBarLabelStyle: { fontFamily: fonts.semibold, fontSize: 11 },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home" size={size} color={typeof color === 'number' ? colors.navy : (color ?? colors.navy)} />
          ),
        }}
      />
      <Tabs.Screen
        name="attendance"
        options={{
          title: 'Attendance',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="grid" size={size} color={typeof color === 'number' ? colors.navy : (color ?? colors.navy)} />
          ),
        }}
      />
      <Tabs.Screen
        name="grades"
        options={{
          title: 'Grades',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="stats-chart" size={size} color={typeof color === 'number' ? colors.navy : (color ?? colors.navy)} />
          ),
        }}
      />
      <Tabs.Screen
        name="more"
        options={{
          title: 'More',
          tabBarIcon: ({ color, size }) => (
            <Ionicons
              name="ellipsis-horizontal-circle"
              size={size}
              color={typeof color === 'number' ? colors.navy : (color ?? colors.navy)}
            />
          ),
        }}
      />
    </Tabs>
  );
}
