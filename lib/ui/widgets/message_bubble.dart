import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/conversation_message.dart';
import '../../services/audio/audio_player_service.dart';
import 'language_badge.dart';

class MessageBubble extends StatefulWidget {
  final ConversationMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final _player = AudioPlayerService();
  bool _isPlaying = false;
  StreamSubscription<PlaybackEvent>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.message.hasAudio) {
      _sub = _player.events.listen((event) {
        if (event.filePath == widget.message.audioPath) {
          if (mounted) setState(() => _isPlaying = event.isPlaying);
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = widget.message;
    final isPrimary = msg.isPrimaryLanguageSpeaker;

    return Align(
      alignment: isPrimary ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isPrimary ? 16 : 4),
            bottomRight: Radius.circular(isPrimary ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isPrimary ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Header: language badge + play button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LanguageBadge(
                  languageCode: msg.detectedLanguage,
                  isPrimary: isPrimary,
                ),
                if (msg.hasAudio) ...[
                  const SizedBox(width: 6),
                  _PlayButton(
                    isPlaying: _isPlaying,
                    onTap: () => _player.play(msg.audioPath!),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Original text (smaller, muted)
            Text(
              msg.originalText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (msg.needsTranslation) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              // Translated text (larger, prominent)
              Text(
                msg.translatedText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 18,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
