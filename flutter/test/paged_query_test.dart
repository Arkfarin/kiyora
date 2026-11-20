import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/state/paged_query.dart';

void main() {
  test(
    'ten thousand rows are reachable with bounded memory and reverse paging',
    () async {
      final query = PagedQuery<int>(
        (offset, limit) async => [
          for (var i = offset; i < offset + limit && i < 10000; i++) i,
        ],
      );
      addTearDown(query.dispose);
      final visited = <int>{};
      while (query.hasMore) {
        await query.next();
        visited.addAll(query.items);
        expect(query.items.length, lessThanOrEqualTo(640));
      }
      expect(visited.length, 10000);
      expect(query.items.last, 9999);
      while (query.firstOffset > 0) {
        await query.previous();
      }
      expect(query.items.first, 0);
      expect(query.hasMore, isTrue);
    },
  );
  test('an old query response cannot overwrite a reset', () async {
    final first = Completer<List<int>>();
    var calls = 0;
    final query = PagedQuery<int>(
      (_, _) => ++calls == 1 ? first.future : Future.value([2]),
    );
    addTearDown(query.dispose);
    final old = query.next();
    await query.reset();
    first.complete([1]);
    await old;
    expect(query.items, [2]);
    expect(query.loading, isFalse);
  });
  test('a failed page can be retried without skipping its offset', () async {
    var fail = true;
    final offsets = <int>[];
    final query = PagedQuery<int>((offset, _) async {
      offsets.add(offset);
      if (fail) throw StateError('offline');
      return [42];
    });
    addTearDown(query.dispose);
    await query.next();
    expect(query.error, isStateError);
    fail = false;
    await query.next();
    expect(offsets, [0, 0]);
    expect(query.items, [42]);
    expect(query.error, isNull);
  });
}
