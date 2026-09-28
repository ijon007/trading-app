import { DarkTheme, DefaultTheme, type Theme } from 'expo-router';
import { DynamicColorIOS, Platform, type ColorValue } from 'react-native';

export const palette = {
  light: {
    background: '#F4F4F5',
    foreground: '#18181B',
    muted: '#71717A',
    glass: '#FFFFFF',
    hairline: '#E4E4E7',
  },
  dark: {
    background: '#0C0C0E',
    foreground: '#F4F4F5',
    muted: '#A1A1AA',
    glass: '#1C1C1E',
    hairline: '#2C2C2E',
  },
} as const;

export const foregroundColor: ColorValue =
  Platform.OS === 'ios'
    ? DynamicColorIOS({ light: palette.light.foreground, dark: palette.dark.foreground })
    : palette.light.foreground;

export function navigationTheme(scheme: 'light' | 'dark'): Theme {
  const colors = palette[scheme];
  const base = scheme === 'dark' ? DarkTheme : DefaultTheme;

  return {
    ...base,
    colors: {
      ...base.colors,
      primary: colors.foreground,
      background: colors.background,
      card: colors.background,
      text: colors.foreground,
      border: colors.hairline,
      notification: colors.foreground,
    },
  };
}
