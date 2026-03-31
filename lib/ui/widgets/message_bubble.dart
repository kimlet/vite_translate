import 'package:flutter/material.dart';

import '../../models/conversation_message.dart';
import 'language_badge.dart';

class MessageBubble extends StatelessWidget {
  final ConversationMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = message.isPrimaryLanguageSpeaker;

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
            LanguageBadge(
              languageCode: message.detectedLanguage,
              isPrimary: isPrimary,
            ),
            const SizedBox(height: 6),
            // Original text (smaller, muted)
            Text(
              message.originalText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (message.needsTranslation) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              // Translated text (larger, prominent)
              Text(
                message.translatedText,
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
