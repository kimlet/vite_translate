import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/language_codes.dart';
import '../../state/engine_state.dart';
import '../../state/settings_state.dart';
import '../widgets/language_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: switch (_currentStep) {
          0 => _buildWelcome(theme),
          1 => _buildLanguageSelection(theme),
          2 => _buildPermissions(theme),
          3 => _buildModelDownload(theme),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _buildWelcome(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.translate,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'vibeTranslate',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Real-time conversation translation.\n'
            'No buttons. No network. Just talk.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: () => setState(() => _currentStep = 1),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelection(ThemeData theme) {
    final settings = ref.watch(settingsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Your Language',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the language you speak.\nOther languages will be translated to this.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LanguagePicker(
            selectedCode: settings.primaryLanguageCode,
            onLanguageSelected: (code) {
              ref.read(settingsProvider.notifier).setPrimaryLanguage(code);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: Text(
                'Continue with ${LanguageCodes.getLanguageName(settings.primaryLanguageCode)}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Microphone Access',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'vibeTranslate needs microphone access to hear '
            'and translate conversations in real-time.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () async {
              final status = await Permission.microphone.request();
              if (status.isGranted) {
                setState(() => _currentStep = 3);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Microphone permission is required. '
                        'Please enable it in Settings.',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.mic),
            label: const Text('Grant Access'),
          ),
        ],
      ),
    );
  }

  Widget _buildModelDownload(ThemeData theme) {
    final engineState = ref.watch(engineProvider);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Download Models',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Download the speech recognition and translation models.\n'
            'This is a one-time download (~450 MB).\n'
            'After this, everything works offline.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          if (engineState.isLoading) ...[
            LinearProgressIndicator(
              value: engineState.downloadProgress,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${(engineState.downloadProgress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
          ] else if (engineState.errorMessage != null) ...[
            Text(
              'Download failed: ${engineState.errorMessage}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _startDownload(),
              child: const Text('Retry'),
            ),
          ] else if (engineState.isReady) ...[
            Icon(
              Icons.check_circle,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(settingsProvider.notifier)
                    .setOnboardingComplete(true);
                await ref
                    .read(settingsProvider.notifier)
                    .setModelsDownloaded(true);
                widget.onComplete();
              },
              child: const Text('Start Translating'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => _startDownload(),
              icon: const Icon(Icons.download),
              label: const Text('Download (~450 MB)'),
            ),
          ],
        ],
      ),
    );
  }

  void _startDownload() {
    ref.read(engineProvider.notifier).downloadModels();
  }
}
