import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/settings_state.dart';
import 'ui/screens/conversation_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme.dart';

class VibeTranslateApp extends ConsumerWidget {
  const VibeTranslateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'vibeTranslate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: settings.onboardingComplete
          ? const ConversationScreen()
          : OnboardingScreen(
              onComplete: () {
                // Settings state will update, triggering rebuild
              },
            ),
    );
  }
}
