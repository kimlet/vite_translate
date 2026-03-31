import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/language_codes.dart';
import '../../models/transcription_result.dart';

class PartialTranscriptionWidget extends StatelessWidget {
  final TranscriptionResult transcription;

  const PartialTranscriptionWidget({
    super.key,
    required this.transcription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langName = LanguageCodes.getLanguageName(
      transcription.languageCode,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hearing,
                size: 14,
                color: theme.colorScheme.primary,
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 600.ms)
                  .then()
                  .fadeOut(duration: 600.ms),
              const SizedBox(width: 6),
              Text(
                'Listening... ($langName)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            transcription.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
