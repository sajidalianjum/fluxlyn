import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import '../services/sql_autocomplete_engine.dart';

class SqlAutocompletePromptsBuilder extends CodeAutocompletePromptsBuilder {
  final CodeLineEditingController controller;
  final SqlAutocompleteEngine engine;

  SqlAutocompletePromptsBuilder({
    required this.controller,
    required this.engine,
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
    final wordMatch = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*$').firstMatch(textBeforeCursor);
    final input = wordMatch?.group(0) ?? '';

    final words = engine.getMatchingWords(
      text: query,
      cursorPosition: clampedOffset,
    );

    if (words.isEmpty) return null;

    final matchedPrompts = words.map((word) => CodeKeywordPrompt(word: word)).toList();

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
  final SqlAutocompleteEngine engine;

  static const double kItemHeight = 30;
  static const double kSectionHeaderHeight = 22;
  static const double kMaxHeight = 240;

  @override
  Size get preferredSize => const Size(280, kMaxHeight + 2);

  const SqlAutocompleteListView({
    super.key,
    required this.notifier,
    required this.onSelected,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prompts = notifier.value.prompts;
    if (prompts.isEmpty) return const SizedBox.shrink();

    final items = engine.lastSuggestions;
    final wordsToItems = <String, CompletionItem>{};
    for (final item in items) {
      wordsToItems[item.word] = item;
    }

    final sections = _buildSections(prompts, wordsToItems);
    final rowCount = sections.fold<int>(0, (sum, s) => sum + 1 + s.items.length);
    final effectiveHeight = (rowCount * kItemHeight).clamp(0.0, kMaxHeight);
    final totalHeight = effectiveHeight + 2;

    return Container(
      width: 280,
      constraints: BoxConstraints(maxHeight: totalHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: rowCount,
          itemBuilder: (context, index) {
            var currentIdx = 0;
            for (final section in sections) {
              if (index == currentIdx) {
                return _buildSectionHeader(section.label, isDark);
              }
              currentIdx++;
              final sectionStart = currentIdx;
              currentIdx += section.items.length;
              if (index < currentIdx) {
                final itemIndex = index - sectionStart;
                return _buildItem(section.items[itemIndex], isDark, theme);
              }
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  List<_Section> _buildSections(
    List prompts,
    Map<String, CompletionItem> items,
  ) {
    final tables = <CompletionItem>[];
    final columns = <CompletionItem>[];
    final functions = <CompletionItem>[];
    final keywords = <CompletionItem>[];

    for (final prompt in prompts) {
      final item = items[prompt.word];
      if (item != null) {
        switch (item.kind) {
          case CompletionKind.table:
            tables.add(item);
            break;
          case CompletionKind.column:
            columns.add(item);
            break;
          case CompletionKind.function_:
            functions.add(item);
            break;
          default:
            keywords.add(item);
        }
      } else {
        keywords.add(CompletionItem(word: prompt.word, kind: CompletionKind.keyword));
      }
    }

    final sections = <_Section>[];
    if (tables.isNotEmpty) sections.add(_Section('Tables', tables));
    if (columns.isNotEmpty) sections.add(_Section('Columns', columns));
    if (functions.isNotEmpty) sections.add(_Section('Functions', functions));
    if (keywords.isNotEmpty) sections.add(_Section('Keywords', keywords));

    return sections;
  }

  Widget _buildSectionHeader(String label, bool isDark) {
    return Container(
      height: kSectionHeaderHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildItem(CompletionItem item, bool isDark, ThemeData theme) {
    final notifierValue = notifier.value;
    final promptIndex = notifierValue.prompts.indexWhere((p) => p.word == item.word);
    final isSelected = promptIndex == notifierValue.index;

    return InkWell(
      onTap: () {
        final idx = promptIndex >= 0 ? promptIndex : 0;
        onSelected(notifierValue.copyWith(index: idx).autocomplete);
      },
      child: Container(
        height: kItemHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: isSelected
            ? (isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
            : null,
        child: Row(
          children: [
            _buildIcon(item.kind, isDark, isSelected),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.word,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF1E40AF))
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.detail != null && item.detail!.isNotEmpty)
              Text(
                item.detail!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: isSelected
                      ? (isDark ? Colors.white70 : const Color(0xFF60A5FA))
                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(CompletionKind kind, bool isDark, bool isSelected) {
    IconData icon;
    Color color;

    switch (kind) {
      case CompletionKind.table:
        icon = Icons.table_chart_outlined;
        color = isSelected
            ? Colors.white
            : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB));
        break;
      case CompletionKind.column:
        icon = Icons.view_column_outlined;
        color = isSelected
            ? Colors.white
            : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED));
        break;
      case CompletionKind.function_:
        icon = Icons.functions_outlined;
        color = isSelected
            ? Colors.white
            : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669));
        break;
      default:
        icon = Icons.code;
        color = isSelected
            ? Colors.white
            : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
    }

    return Icon(icon, size: 14, color: color);
  }
}

class _Section {
  final String label;
  final List<CompletionItem> items;

  _Section(this.label, this.items);
}
