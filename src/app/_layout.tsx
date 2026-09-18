import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useColorScheme } from 'react-native';
import { enableScreens } from 'react-native-screens';

import { AnimatedSplashOverlay } from '@/components/animated-icon';
import { OcrWorker } from '@/components/ocr-worker';

// react-native-screens' native Fragment-based Screen is currently fighting
// Android's edge-to-edge enforcement (an active, documented issue across
// react-native-screens/react-navigation as of SDK 57 / RN 0.86), showing up
// as app content being squeezed into roughly the bottom half of the window.
// Disabling the native screen optimization avoids it at a small cost to
// navigation transition performance, which doesn't matter for this app.
enableScreens(false);

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const colorScheme = useColorScheme();
  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <AnimatedSplashOverlay />
      <OcrWorker />
      <Stack>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="book/[id]" options={{ title: 'Review Book' }} />
      </Stack>
    </ThemeProvider>
  );
}
