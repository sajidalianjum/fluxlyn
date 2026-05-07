import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

class SqlAutocompletePromptsBuilder extends CodeAutocompletePromptsBuilder {
  final CodeLineEditingController controller;
  final List<String> currentSuggestions;

  SqlAutocompletePromptsBuilder({
    required this.controller,
    required this.currentSuggestions,
  });

  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    int globalOffset = 0;
    final lines = controller.codeLines;
    final lineCount = lines.length;
    for (int i = 0; i < selection.baseIndex && i < lineCount; i++) {
      globalOffset += lines[i].text.length + 1;
    }
    globalOffset += selection.baseOffset;

    final query = controller.text;
    if (query.isEmpty) return null;

    final clampedOffset = globalOffset.clamp(0, query.length);
    final textBeforeCursor = query.substring(0, clampedOffset);
    final wordMatch = RegExp(r'\w+$').firstMatch(textBeforeCursor);
    final input = wordMatch?.group(0) ?? '';

    final matchedPrompts = currentSuggestions
        .where((word) => word.toLowerCase().startsWith(input.toLowerCase()))
        .map((word) => CodeKeywordPrompt(word: word))
        .toList();

    if (matchedPrompts.isEmpty) return null;

    return CodeAutocompleteEditingValue(
      input: input,
      prompts: matchedPrompts,
      index: 0,
    );
  }
}

class SqlAutocompleteListView extends StatelessWidget implements PreferredSizeWidget {
  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;

  static const double kItemHeight = 28;
  static const double kMaxHeight = 200;

  @override
  Size get preferredSize {
    return const Size(240, kMaxHeight + 2);
  }

  const SqlAutocompleteListView({
    super.key,
    required this.notifier,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final length = notifier.value.prompts.length;
    final effectiveHeight = (kItemHeight * length).clamp(0.0, 200.0);

    return Container(
      width: 240,
      constraints: BoxConstraints(maxHeight: effectiveHeight + 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: length,
        itemExtent: kItemHeight,
        itemBuilder: (context, index) {
          final prompt = notifier.value.prompts[index];
          final isSelected = index == notifier.value.index;
          return InkWell(
            onTap: () {
              onSelected(notifier.value.copyWith(index: index).autocomplete);
            },
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: isSelected
                  ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFEFF6FF))
                  : null,
              child: Text(
                prompt.word,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF1E40AF))
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
