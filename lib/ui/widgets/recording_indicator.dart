import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RecordingIndicator extends StatelessWidget {
  final bool isRecording;

  const RecordingIndicator({super.key, required this.isRecording});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
            ),
          )
              .animate(
                target: isRecording ? 1 : 0,
                onPlay: (c) => c.repeat(reverse: true),
              )
              .scaleXY(end: 1.3, duration: 800.ms)
              .fade(begin: 1, end: 0.5, duration: 800.ms),
          const SizedBox(width: 8),
          Text(
            isRecording ? 'Listening' : 'Paused',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isRecording
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
