import 'package:flutter/foundation.dart';

/// A bounded window over backend pagination. A generation fences outstanding
/// reads after a query, profile or projection change.
class PagedQuery<T> extends ChangeNotifier {
  PagedQuery(this.fetch, {this.pageSize = 80, this.maxPages = 8});
  final Future<List<T>> Function(int offset, int limit) fetch;
  final int pageSize;
  final int maxPages;
  List<T> items = [];
  int firstOffset = 0;
  bool loading = false;
  bool hasMore = true;
  Object? error;
  int _generation = 0;
  bool _disposed = false;

  Future<void> reset() async {
    _generation++;
    firstOffset = 0;
    items = [];
    hasMore = true;
    loading = false;
    error = null;
    await next();
  }

  Future<void> next() => load(firstOffset + items.length);

  Future<void> previous() async {
    if (loading || firstOffset == 0) return;
    final offset = (firstOffset - pageSize).clamp(0, firstOffset);
    await load(offset, prepend: true);
  }

  Future<void> load(int offset, {bool prepend = false}) async {
    if (_disposed || loading || (!prepend && !hasMore)) return;
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await fetch(offset, pageSize);
      if (_disposed || generation != _generation) return;
      if (prepend) {
        items = [...page, ...items];
        firstOffset = offset;
        if (items.length > pageSize * maxPages) {
          items = items.take(pageSize * maxPages).toList();
          hasMore = true;
        }
      } else {
        items = [...items, ...page];
        hasMore = page.length == pageSize;
        final excess = items.length - pageSize * maxPages;
        if (excess > 0) {
          items = items.sublist(excess);
          firstOffset += excess;
        }
      }
    } catch (e) {
      if (!_disposed && generation == _generation) error = e;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
