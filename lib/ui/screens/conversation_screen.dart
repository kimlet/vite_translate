import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/conversation_message.dart';
import '../../services/audio/test_audio_service.dart';
import '../../state/conversation_state.dart';
import '../../state/settings_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/partial_transcription.dart';
import '../widgets/recording_indicator.dart';
import 'settings_screen.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start listening when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndStart();
    });
  }

  Future<void> _initAndStart() async {
    try {
      debugPrint('[ConversationScreen] Initializing engine...');
      final engine = ref.read(conversationEngineProvider);
      await engine.initialize();
      debugPrint('[ConversationScreen] Engine initialized, starting listening...');
      ref.read(conversationProvider.notifier).startListening();
      debugPrint('[ConversationScreen] Listening started');
    } catch (e, stack) {
      debugPrint('[ConversationScreen] Init failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: $e')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(conversationProvider.notifier);
    if (state == AppLifecycleState.paused) {
      notifier.stopListening();
    } else if (state == AppLifecycleState.resumed) {
      notifier.startListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _testWithAudioFile() async {
    try {
      debugPrint('[Test] Loading test audio file...');
      final samples = await TestAudioService.loadWavAsset(
        'assets/test_audio/test_english.wav',
      );

      debugPrint('[Test] Feeding ${samples.length} samples to whisper...');
      final engine = ref.read(conversationEngineProvider);

      if (!engine.isRunning) {
        debugPrint('[Test] Engine not running, initializing...');
        await engine.initialize();
      }

      // Feed directly to whisper via the engine's internal method
      // We simulate an utterance by transcribing the test audio
      final whisper = engine.whisperIsolate;
      if (!whisper.isInitialized) {
        debugPrint('[Test] Whisper not initialized!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Whisper model not loaded. Download model first.')),
          );
        }
        return;
      }

      debugPrint('[Test] Transcribing...');
      final result = await whisper.transcribe(samples);
      debugPrint('[Test] Result: lang=${result.languageCode} text="${result.text}"');

      if (result.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transcription returned empty result')),
          );
        }
        return;
      }

      // Add as a conversation message
      final settings = ref.read(settingsProvider);
      final isPrimary = result.languageCode == settings.primaryLanguageCode;

      ref.read(conversationProvider.notifier).addMessage(
        ConversationMessage(
          id: 'test_${DateTime.now().millisecondsSinceEpoch}',
          originalText: result.text,
          translatedText: result.text, // No translation in test mode
          detectedLanguage: result.languageCode,
          targetLanguage: settings.primaryLanguageCode,
          isPrimaryLanguageSpeaker: isPrimary,
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detected: ${result.languageCode} — "${result.text}"')),
        );
      }
    } catch (e, stack) {
      debugPrint('[Test] Error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test failed: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationProvider);
    final theme = Theme.of(context);

    // Auto-scroll when new messages arrive
    ref.listen(conversationProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    // Show errors as snackbar
    ref.listen(conversationProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
        ref.read(conversationProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'vibeTranslate',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_external_on),
            tooltip: 'Test Audio File',
            onPressed: () => _testWithAudioFile(),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Run Demo',
            onPressed: () {
              final lang = ref.read(settingsProvider).primaryLanguageCode;
              ref.read(conversationProvider.notifier).runDemo(lang);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              ref.read(conversationProvider.notifier).clearMessages();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: state.messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(message: state.messages[index]);
                    },
                  ),
          ),
          // Partial transcription
          if (state.partialTranscription != null &&
              !state.partialTranscription!.isEmpty)
            PartialTranscriptionWidget(
              transcription: state.partialTranscription!,
            ),
          // Recording indicator
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecordingIndicator(isRecording: state.isListening),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Start speaking',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your conversation will appear here.\n'
              'Speak in any language — it will be\n'
              'automatically detected and translated.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
