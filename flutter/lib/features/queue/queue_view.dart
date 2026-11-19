import 'package:flutter/material.dart';
import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api.dart' as api;
import '../../core/state/backend_controller.dart';
import '../../core/state/paged_query.dart';
import '../../core/widgets/artwork.dart';

class QueueView extends StatefulWidget {
  const QueueView({super.key, required this.backend});
  final BackendController backend;
  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  late final PagedQuery<(int, String)> _page;
  api.Queue? _revision;
  @override
  void initState() {
    super.initState();
    _page = PagedQuery((offset, limit) async {
      final page = await api.queue(
        sessionId: widget.backend.sessionId,
        offset: offset,
        limit: limit,
      );
      if (_revision != null &&
          (_revision!.id != page.queue.id ||
              _revision!.revision != page.queue.revision)) {
        widget.backend.queue.value = page.queue;
        return [];
      }
      return [
        for (var i = 0; i < page.trackIds.length; i++)
          (page.offset + i, page.trackIds[i]),
      ];
    });
    widget.backend.queue.addListener(_changed);
    _changed();
  }

  void _changed() {
    final latest = widget.backend.queue.value;
    if (latest?.id != _revision?.id ||
        latest?.revision != _revision?.revision) {
      _revision = latest;
      _page.reset();
    }
  }

  @override
  void dispose() {
    widget.backend.queue.removeListener(_changed);
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _page,
    builder: (context, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Очередь',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (_page.loading) const LinearProgressIndicator(),
        if (_page.error != null)
          TextButton(
            onPressed: _page.reset,
            child: const Text('Не удалось загрузить очередь. Повторить'),
          ),
        if (_page.items.isEmpty && !_page.loading && _page.error == null)
          const Expanded(
            child: Center(child: Text('Добавьте музыку в очередь')),
          )
        else
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              header: _page.firstOffset > 0
                  ? TextButton(
                      onPressed: _page.previous,
                      child: const Text('Предыдущие композиции'),
                    )
                  : null,
              footer: _page.hasMore
                  ? TextButton(
                      onPressed: _page.next,
                      child: const Text('Показать ещё'),
                    )
                  : null,
              itemCount: _page.items.length,
              onReorder: (from, to) {
                if (to > from) to--;
                if (from == to) return;
                widget.backend.editQueue(
                  api.QueueEdit.move(
                    from: _page.items[from].$1,
                    to: _page.items[to].$1,
                  ),
                );
              },
              itemBuilder: (context, i) {
                final (position, id) = _page.items[i];
                final current = _revision?.position?.toInt();
                return Column(
                  key: ValueKey('${_revision?.id}:$position:$id'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (position == current || position == (current ?? -1) + 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          position == current
                              ? 'Сейчас играет'
                              : 'Далее в очереди',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    _QueueRow(
                      backend: widget.backend,
                      id: id,
                      position: position,
                      selected: position == current,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            tooltip: 'Действия с композицией',
                            onSelected: (action) =>
                                widget.backend.editQueue(switch (action) {
                                  'up' => api.QueueEdit.move(
                                    from: position,
                                    to: position - 1,
                                  ),
                                  'down' => api.QueueEdit.move(
                                    from: position,
                                    to: position + 1,
                                  ),
                                  _ => api.QueueEdit.remove(index: position),
                                }),
                            itemBuilder: (_) => [
                              if (position > 0)
                                const PopupMenuItem(
                                  value: 'up',
                                  child: Text('Переместить выше'),
                                ),
                              if (position + 1 <
                                  (_revision?.total.toInt() ?? 0))
                                const PopupMenuItem(
                                  value: 'down',
                                  child: Text('Переместить ниже'),
                                ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Убрать из очереди'),
                              ),
                            ],
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Tooltip(
                                message: 'Перетащить',
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _QueueRow extends StatefulWidget {
  const _QueueRow({
    required this.backend,
    required this.id,
    required this.position,
    required this.selected,
    required this.trailing,
  });
  final BackendController backend;
  final String id;
  final int position;
  final bool selected;
  final Widget trailing;
  @override
  State<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends State<_QueueRow> {
  late Future<content.TrackDetail?> _track;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_QueueRow old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _load();
  }

  void _load() {
    _track = content.track(
      sessionId: widget.backend.sessionId,
      trackId: widget.id,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _track,
    builder: (context, snapshot) {
      final track = snapshot.data;
      return ListTile(
        selected: widget.selected,
        leading: MusicArtwork(
          sessionId: widget.backend.sessionId,
          trackId: track?.id,
          digest: track?.metadata.artworkDigest,
          size: 40,
        ),
        title: Text(
          track?.metadata.title ??
              (snapshot.hasError
                  ? 'Не удалось загрузить композицию'
                  : 'Композиция недоступна'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track?.metadata.artist ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: widget.trailing,
        onTap: () => widget.backend.editQueue(
          api.QueueEdit.jump(index: widget.position),
        ),
      );
    },
  );
}
