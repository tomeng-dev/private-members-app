import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

/// Column definition for [AdminDataTable].
class TableColumn<T> {
  const TableColumn({
    required this.id,
    required this.label,
    required this.cell,
    this.width,
    this.flex = 1,
    this.minWidth = 120,
    this.sortKey,
    this.numeric = false,
    this.hideable = true,
  });
  final String id;
  final String label;
  final Widget Function(BuildContext context, T row) cell;

  /// Fixed width; when null the column flexes with [flex] (at least [minWidth]).
  final double? width;
  final int flex;
  final double minWidth;

  /// Server-side sort key; null = not sortable.
  final String? sortKey;
  final bool numeric;
  final bool hideable;
}

/// Server-driven query state shared by table pages.
class TableQueryState {
  TableQueryState({this.page = 1, this.pageSize = 20, this.sort = 'createdAt', this.order = 'desc', this.q = ''});
  int page;
  int pageSize;
  String sort;
  String order;
  String q;

  Map<String, dynamic> toParams() => {'page': page, 'pageSize': pageSize, 'sort': sort, 'order': order, if (q.trim().isNotEmpty) 'q': q.trim()};

  void toggleSort(String key) {
    if (sort == key) {
      order = order == 'asc' ? 'desc' : 'asc';
    } else {
      sort = key;
      order = key == 'createdAt' ? 'desc' : 'asc';
    }
    page = 1;
  }
}

/// A paginated, sortable, selectable data table with server-side paging.
///
/// Rows are keyboard-focusable (Tab / Enter opens the row), the header is
/// announced as column headers, and selection checkboxes have labels.
class AdminDataTable<T> extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.idOf,
    required this.query,
    required this.total,
    required this.onQueryChanged,
    this.loading = false,
    this.error,
    this.onRetry,
    this.selected = const {},
    this.onSelectionChanged,
    this.onRowTap,
    this.hiddenColumns = const {},
    this.rowLabel,
    this.empty,
    this.activeRowId,
  });

  final List<TableColumn<T>> columns;
  final List<T> rows;
  final String Function(T row) idOf;
  final TableQueryState query;
  final int total;
  final VoidCallback onQueryChanged;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final Set<String> selected;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<T>? onRowTap;
  final Set<String> hiddenColumns;
  final String Function(T row)? rowLabel;
  final Widget? empty;
  final String? activeRowId;

  static const double _checkW = 52;
  static const double _rowH = 60;

  List<TableColumn<T>> get _visible => columns.where((c) => !hiddenColumns.contains(c.id)).toList();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final visible = _visible;
    final selectable = onSelectionChanged != null;
    final minW = (selectable ? _checkW : 0) + visible.fold<double>(0, (a, c) => a + (c.width ?? c.minWidth)) + Gap.lg * 2;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth < minW ? minW : box.maxWidth;
                final table = SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      _header(context, visible, selectable),
                      Divider(height: 1, color: t.border),
                      Expanded(child: _body(context, visible, selectable)),
                    ],
                  ),
                );
                if (width == box.maxWidth) return table;
                return Scrollbar(
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: table),
                );
              },
            ),
          ),
          Divider(height: 1, color: t.border),
          _footer(context),
        ],
      ),
    );
  }

  Widget _cellBox(TableColumn<T> c, Widget child) {
    final aligned = Align(alignment: c.numeric ? Alignment.centerRight : Alignment.centerLeft, child: child);
    if (c.width != null) return SizedBox(width: c.width, child: aligned);
    return Expanded(
      flex: c.flex,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: c.minWidth),
        child: aligned,
      ),
    );
  }

  Widget _header(BuildContext context, List<TableColumn<T>> visible, bool selectable) {
    final ids = rows.map(idOf).toSet();
    final allSelected = ids.isNotEmpty && ids.every(selected.contains);
    final someSelected = ids.any(selected.contains);
    return Container(
      height: 46,
      color: context.tokens.surfaceRaised,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Row(
        children: [
          if (selectable)
            SizedBox(
              width: _checkW,
              child: Semantics(
                label: allSelected ? 'Deselect all rows on this page' : 'Select all rows on this page',
                child: Checkbox(
                  tristate: true,
                  value: allSelected ? true : (someSelected ? null : false),
                  onChanged: rows.isEmpty
                      ? null
                      : (_) {
                          final next = {...selected};
                          allSelected ? next.removeAll(ids) : next.addAll(ids);
                          onSelectionChanged!(next);
                        },
                ),
              ),
            ),
          for (final c in visible) _cellBox(c, _headerCell(context, c)),
        ],
      ),
    );
  }

  Widget _headerCell(BuildContext context, TableColumn<T> c) {
    final active = c.sortKey != null && query.sort == c.sortKey;
    final style = context.text.labelMedium?.copyWith(color: active ? context.tokens.textPrimary : context.tokens.textMuted);
    final label = Text(c.label.toUpperCase(), style: style, overflow: TextOverflow.ellipsis);
    if (c.sortKey == null) return Semantics(header: true, child: label);
    return Semantics(
      header: true,
      button: true,
      label: '${c.label}, ${active ? (query.order == 'asc' ? 'sorted ascending' : 'sorted descending') : 'not sorted'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () {
          query.toggleSort(c.sortKey!);
          onQueryChanged();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: label),
              const SizedBox(width: 4),
              Icon(
                active ? (query.order == 'asc' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
                size: 14,
                color: active ? context.tokens.accentText : context.tokens.textMuted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<TableColumn<T>> visible, bool selectable) {
    if (loading && rows.isEmpty) return const SingleChildScrollView(child: TableSkeleton());
    if (error != null && rows.isEmpty) return ErrorView(message: error!, onRetry: onRetry);
    if (rows.isEmpty) {
      return empty ?? const EmptyView(title: 'No results', message: 'Try adjusting the search or filters.', icon: Icons.search_off_rounded);
    }
    return Stack(
      children: [
        ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: context.tokens.border),
          itemBuilder: (context, i) => _row(context, rows[i], visible, selectable),
        ),
        if (loading) const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    );
  }

  Widget _row(BuildContext context, T row, List<TableColumn<T>> visible, bool selectable) {
    final id = idOf(row);
    final isSel = selected.contains(id);
    final isActive = activeRowId == id;
    final t = context.tokens;
    final bg = isActive
        ? AppColors.gold.withValues(alpha: 0.10)
        : isSel
        ? AppColors.gold.withValues(alpha: 0.06)
        : Colors.transparent;
    return Semantics(
      label: rowLabel?.call(row),
      selected: isSel,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onRowTap == null ? null : () => onRowTap!(row),
          hoverColor: t.surfaceRaised,
          focusColor: AppColors.gold.withValues(alpha: 0.12),
          child: Container(
            height: _rowH,
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            decoration: isActive
                ? const BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
                  )
                : null,
            child: Row(
              children: [
                if (selectable)
                  SizedBox(
                    width: _checkW,
                    child: Semantics(
                      label: 'Select ${rowLabel?.call(row) ?? 'row'}',
                      child: Checkbox(
                        value: isSel,
                        onChanged: (_) {
                          final next = {...selected};
                          isSel ? next.remove(id) : next.add(id);
                          onSelectionChanged!(next);
                        },
                      ),
                    ),
                  ),
                for (final c in visible)
                  _cellBox(
                    c,
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.md),
                      child: c.cell(context, row),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final pageCount = total == 0 ? 1 : ((total + query.pageSize - 1) ~/ query.pageSize);
    final from = total == 0 ? 0 : (query.page - 1) * query.pageSize + 1;
    final to = (query.page * query.pageSize).clamp(0, total);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Row(
        children: [
          if (selected.isNotEmpty) Text('${selected.length} selected · ', style: context.text.bodySmall?.copyWith(color: context.tokens.accentText)),
          Text('$from–$to of $total', style: context.text.bodySmall),
          const Spacer(),
          Text('Rows per page', style: context.text.bodySmall),
          const SizedBox(width: Gap.sm),
          DropdownButton<int>(
            value: query.pageSize,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(Radii.md),
            style: context.text.bodyMedium,
            items: const [10, 20, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
            onChanged: (n) {
              if (n == null) return;
              query.pageSize = n;
              query.page = 1;
              onQueryChanged();
            },
          ),
          const SizedBox(width: Gap.lg),
          IconButton(
            tooltip: 'Previous page',
            onPressed: query.page > 1
                ? () {
                    query.page -= 1;
                    onQueryChanged();
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('Page ${query.page} of $pageCount', style: context.text.bodySmall),
          IconButton(
            tooltip: 'Next page',
            onPressed: query.page < pageCount
                ? () {
                    query.page += 1;
                    onQueryChanged();
                  }
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// Debounced search field for table toolbars.
class TableSearchField extends StatefulWidget {
  const TableSearchField({super.key, required this.onChanged, this.hint = 'Search', this.initial = '', this.width = 320});
  final ValueChanged<String> onChanged;
  final String hint;
  final String initial;
  final double width;
  @override
  State<TableSearchField> createState() => _TableSearchFieldState();
}

class _TableSearchFieldState extends State<TableSearchField> {
  late final _ctrl = TextEditingController(text: widget.initial);
  DateTime _last = DateTime.now();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _changed(String v) {
    final stamp = _last = DateTime.now();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted && stamp == _last) widget.onChanged(v);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _ctrl,
        onChanged: _changed,
        onSubmitted: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }
}

/// "Columns" menu toggling optional column visibility.
class ColumnVisibilityButton<T> extends StatelessWidget {
  const ColumnVisibilityButton({super.key, required this.columns, required this.hidden, required this.onChanged});
  final List<TableColumn<T>> columns;
  final Set<String> hidden;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final c in columns.where((c) => c.hideable))
          CheckboxMenuButton(
            value: !hidden.contains(c.id),
            onChanged: (v) {
              final next = {...hidden};
              v == true ? next.remove(c.id) : next.add(c.id);
              onChanged(next);
            },
            child: Text(c.label),
          ),
      ],
      builder: (context, ctrl, _) => OutlinedButton.icon(
        onPressed: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
        icon: const Icon(Icons.view_column_outlined, size: 18),
        label: const Text('Columns'),
      ),
    );
  }
}

/// Contextual bar shown when rows are selected.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({super.key, required this.count, required this.actions, required this.onClear});
  final int count;
  final List<Widget> actions;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: count == 0
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('bulk'),
              margin: const EdgeInsets.only(bottom: Gap.md),
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Semantics(liveRegion: true, child: Text('$count selected', style: context.text.titleSmall)),
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: actions),
                  ),
                  TextButton(onPressed: onClear, child: const Text('Clear selection')),
                ],
              ),
            ),
    );
  }
}

/// Filter chip with an optional count badge.
class FacetChip extends StatelessWidget {
  const FacetChip({super.key, required this.label, required this.selected, required this.onSelected, this.count});
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(count == null ? label : '$label  $count'),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
