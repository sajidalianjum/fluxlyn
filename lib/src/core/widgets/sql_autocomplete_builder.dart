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

    final items = engine.lastSuggestions;
    final wordToItem = <String, CompletionItem>{};
    for (final item in items) {
      wordToItem[item.word] = item;
    }

    // Group words by section priority so the flat prompt order matches visual layout
    final sectionOrder = [
      CompletionKind.table,
      CompletionKind.column,
      CompletionKind.function_,
      CompletionKind.keyword,
    ];
    final grouped = <CompletionKind, List<String>>{};
    for (final word in words) {
      final kind = wordToItem[word]?.kind ?? CompletionKind.keyword;
      grouped.putIfAbsent(kind, () => []).add(word);
    }

    final orderedWords = <String>[];
    for (final kind in sectionOrder) {
      if (grouped.containsKey(kind)) {
        orderedWords.addAll(grouped[kind]!);
      }
    }

    final matchedPrompts = orderedWords.map((word) => CodeKeywordPrompt(word: word)).toList();

    return CodeAutocompleteEditingValue(
      input: input,
      prompts: matchedPrompts,
      index: 0,
    );
  }
}

class _SectionData {
  final _Section section;
  final int startFlatIndex;
  final List<int> flatIndices;

  _SectionData(this.section, this.startFlatIndex, this.flatIndices);
}

class SqlAutocompleteListView extends StatefulWidget implements PreferredSizeWidget {
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
  State<SqlAutocompleteListView> createState() => _SqlAutocompleteListViewState();
}

class _SqlAutocompleteListViewState extends State<SqlAutocompleteListView> {
  final ScrollController _scrollController = ScrollController();
  int _lastSelectedFlatIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScrollToSelected(int flatIndex) {
    if (flatIndex == _lastSelectedFlatIndex) return;
    _lastSelectedFlatIndex = flatIndex;
    if (!_scrollController.hasClients) return;

    final scrollOffset = flatIndex * SqlAutocompleteListView.kItemHeight;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedOffset = scrollOffset.clamp(0.0, maxScroll);
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CodeAutocompleteEditingValue>(
      valueListenable: widget.notifier,
      builder: (context, value, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final prompts = value.prompts;
        if (prompts.isEmpty) return const SizedBox.shrink();

        final engineItems = widget.engine.lastSuggestions;
        final wordsToItems = <String, CompletionItem>{};
        for (final item in engineItems) {
          wordsToItems[item.word] = item;
        }

        final sections = _buildSections(prompts, wordsToItems);

        int flatIdx = 0;
        final sectionData = <_SectionData>[];
        for (final section in sections) {
          final indices = <int>[];
          final start = flatIdx;
          for (int j = 0; j < section.items.length; j++) {
            indices.add(flatIdx);
            flatIdx++;
          }
          sectionData.add(_SectionData(section, start, indices));
        }

        final rowCount = sections.fold<int>(0, (sum, s) => sum + 1 + s.items.length);
        final effectiveHeight = (rowCount * SqlAutocompleteListView.kItemHeight).clamp(0.0, SqlAutocompleteListView.kMaxHeight);
        final totalHeight = effectiveHeight + 2;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoScrollToSelected(value.index);
        });

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
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: rowCount,
              itemBuilder: (context, index) {
                int cursor = 0;
                for (final section in sectionData) {
                  if (index == cursor) {
                    return _buildSectionHeader(section.section.label, isDark);
                  }
                  cursor++;
                  final sectionStart = cursor;
                  cursor += section.flatIndices.length;
                  if (index < cursor) {
                    final itemIndex = index - sectionStart;
                    final itemFlatIdx = section.flatIndices[itemIndex];
                    return _buildItem(
                      section.section.items[itemIndex],
                      isDark,
                      theme,
                      value,
                      itemFlatIdx,
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
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
      height: SqlAutocompleteListView.kSectionHeaderHeight,
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

  Widget _buildItem(
    CompletionItem item,
    bool isDark,
    ThemeData theme,
    CodeAutocompleteEditingValue value,
    int flatIndex,
  ) {
    final isSelected = flatIndex == value.index;

    return InkWell(
      onTap: () {
        widget.onSelected(value.copyWith(index: flatIndex).autocomplete);
      },
      child: Container(
        height: SqlAutocompleteListView.kItemHeight,
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
