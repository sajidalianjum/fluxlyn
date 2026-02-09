enum SortDirection { asc, desc }

class TableSearchResult {
  final String? searchColumn;
  final String? searchText;
  final String? sortColumn;
  final SortDirection sortDirection;

  TableSearchResult({
    this.searchColumn,
    this.searchText,
    this.sortColumn,
    this.sortDirection = SortDirection.asc,
  });

  bool get hasFilters => searchColumn != null && searchText != null;
  bool get hasSort => sortColumn != null;

  TableSearchResult copyWith({
    String? searchColumn,
    String? searchText,
    String? sortColumn,
    SortDirection? sortDirection,
  }) {
    return TableSearchResult(
      searchColumn: searchColumn ?? this.searchColumn,
      searchText: searchText ?? this.searchText,
      sortColumn: sortColumn ?? this.sortColumn,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }

  @override
  String toString() {
    return 'TableSearchResult(searchColumn: $searchColumn, searchText: $searchText, sortColumn: $sortColumn, sortDirection: $sortDirection)';
  }
}
