import 'package:flutter/material.dart';

import '../../core/language_codes.dart';

class LanguagePicker extends StatefulWidget {
  final String selectedCode;
  final ValueChanged<String> onLanguageSelected;

  const LanguagePicker({
    super.key,
    required this.selectedCode,
    required this.onLanguageSelected,
  });

  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<LanguagePicker> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<MapEntry<String, String>> get _filteredLanguages {
    final entries = LanguageCodes.languageNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (_searchQuery.isEmpty) return entries;

    return entries.where((entry) {
      return entry.value.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search languages...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredLanguages.length,
            itemBuilder: (context, index) {
              final entry = _filteredLanguages[index];
              final isSelected = entry.key == widget.selectedCode;

              return ListTile(
                title: Text(entry.value),
                subtitle: Text(entry.key.toUpperCase()),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
                selected: isSelected,
                onTap: () => widget.onLanguageSelected(entry.key),
              );
            },
          ),
        ),
      ],
    );
  }
}
