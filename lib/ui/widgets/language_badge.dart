import 'package:flutter/material.dart';

import '../../core/language_codes.dart';

class LanguageBadge extends StatelessWidget {
  final String languageCode;
  final bool isPrimary;

  const LanguageBadge({
    super.key,
    required this.languageCode,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = LanguageCodes.getLanguageName(languageCode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPrimary ? 'You ($name)' : name,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isPrimary
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
