import 'package:material_ui/material_ui.dart';

import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api/edits.dart' as edits;
import '../../core/bridge/generated/api.dart' as api;
import '../../core/routing/navigation.dart';
import '../../core/state/backend_controller.dart';
import '../../core/state/paged_query.dart';
import 'track_offline.dart';

Future<String?> askName(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final input = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (input.text.trim().isNotEmpty)
              Navigator.pop(context, input.text.trim());
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  input.dispose();
  return value;
}

Future<void> createPlaylist(
  BuildContext context,
  BackendController b,
  MusicNavigation nav,
) async {
  final title = await askName(context, 'Новый плейлист');
  if (title == null) return;
  await b.operate((op) async {
    final id = await api.newOperationId();
    final result = await edits.edit(
      sessionId: b.sessionId,
      operationId: await api.newOperationId(),
      entityId: id,
      edit: edits.LibraryEdit.createPlaylist(title: title),
      operation: op,
    );
    b.commandResults.value = result;
    if (result.state == edits.CommandState.applied) {
      b.libraryRevision.value++;
      nav.go(MusicLocation(Destination.playlist, id: id, title: title));
    }
  });
}

Future<void> showTrackActions(
  BuildContext context,
  BackendController b,
  MusicNavigation nav,
  api.Track track, {
  Offset? anchor,
  String? playlistId,
  String? entryId,
}) async {
  final sessionId = b.session?.sessionId;
  final actions = <(String, IconData, String)>[
    ('next', Icons.playlist_play, 'Воспроизвести следующим'),
    ('queue', Icons.queue_music, 'Добавить в очередь'),
    ('offline', Icons.download_outlined, 'Офлайн-доступ'),
    ('like', Icons.favorite_border, 'Добавить в любимые'),
    ('unlike', Icons.heart_broken_outlined, 'Убрать из любимых'),
    ('playlist', Icons.playlist_add, 'Добавить в плейлист'),
    if (playlistId != null && entryId != null)
      ('remove', Icons.playlist_remove, 'Убрать из плейлиста'),
    if (track.album.isNotEmpty)
      ('album', Icons.album_outlined, 'Перейти к альбому'),
    if (track.artist.isNotEmpty)
      ('artist', Icons.person_outline, 'Перейти к исполнителю'),
    ('edit', Icons.edit_outlined, 'Редактировать данные'),
  ];
  String? action;
  if (MediaQuery.sizeOf(context).width < 700) {
    action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(track.title), subtitle: Text(track.artist)),
              for (final (id, icon, title) in actions)
                ListTile(
                  leading: Icon(icon),
                  title: Text(title),
                  onTap: () => Navigator.pop(context, id),
                ),
            ],
          ),
        ),
      ),
    );
  } else {
    final point = anchor ?? const Offset(300, 200);
    action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(point.dx, point.dy, point.dx, point.dy),
      items: [
        for (final (id, icon, title) in actions)
          PopupMenuItem(
            value: id,
            height: 56,
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  if (action == null ||
      !context.mounted ||
      sessionId == null ||
      b.session?.sessionId != sessionId) {
    return;
  }
  switch (action) {
    case 'offline':
      await showTrackOffline(context, b, track);
    case 'next':
    case 'queue':
      await b.editQueue(
        api.QueueEdit.append(trackIds: [track.id], next: action == 'next'),
      );
    case 'like':
    case 'unlike':
      await b.operate((op) async {
        b.commandResults.value = await edits.edit(
          sessionId: b.sessionId,
          operationId: await api.newOperationId(),
          entityId: track.id,
          edit: edits.LibraryEdit.favorite(
            setName: 'liked',
            value: action == 'like',
          ),
          operation: op,
        );
      });
    case 'remove':
      await b.operate((op) async {
        b.commandResults.value = await edits.edit(
          sessionId: b.sessionId,
          operationId: await api.newOperationId(),
          entityId: playlistId!,
          edit: edits.LibraryEdit.removeTrack(entryId: entryId!),
          operation: op,
        );
      });
    case 'album':
      final detail = await content.track(
        sessionId: b.sessionId,
        trackId: track.id,
      );
      nav.go(
        MusicLocation(
          Destination.album,
          title: track.album,
          artist: detail?.metadata.albumArtist.isNotEmpty == true
              ? detail!.metadata.albumArtist
              : track.artist,
        ),
      );
    case 'artist':
      nav.go(
        MusicLocation(
          Destination.artist,
          title: track.artist,
          artist: track.artist,
        ),
      );
    case 'playlist':
      final playlist = await showModalBottomSheet<content.Playlist>(
        context: context,
        showDragHandle: true,
        builder: (_) => _PlaylistPicker(backend: b),
      );
      if (playlist == null) return;
      await b.operate((op) async {
        b.commandResults.value = await edits.edit(
          sessionId: b.sessionId,
          operationId: await api.newOperationId(),
          entityId: playlist.id,
          edit: edits.LibraryEdit.addTrack(
            trackId: track.id,
            entryId: await api.newOperationId(),
            afterEntryId: null,
          ),
          operation: op,
        );
      });
    case 'edit':
      await showDialog<void>(
        context: context,
        builder: (_) => _MetadataEditor(backend: b, track: track),
      );
  }
}

class _PlaylistPicker extends StatefulWidget {
  const _PlaylistPicker({required this.backend});
  final BackendController backend;
  @override
  State<_PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends State<_PlaylistPicker> {
  late final PagedQuery<content.Playlist> _page;
  @override
  void initState() {
    super.initState();
    _page = PagedQuery(
      (offset, limit) => content.playlists(
        sessionId: widget.backend.sessionId,
        query: null,
        offset: offset,
        limit: limit,
      ),
    )..reset();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _page,
    builder: (context, _) => Column(
      children: [
        const ListTile(title: Text('Добавить в плейлист')),
        if (_page.loading) const LinearProgressIndicator(),
        if (_page.error != null)
          TextButton(
            onPressed: _page.reset,
            child: const Text('Повторить загрузку'),
          ),
        Expanded(
          child: ListView(
            children: [
              if (_page.firstOffset > 0)
                TextButton(
                  onPressed: _page.previous,
                  child: const Text('Назад'),
                ),
              for (final playlist in _page.items)
                ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(playlist.title),
                  onTap: () => Navigator.pop(context, playlist),
                ),
              if (_page.hasMore)
                TextButton(
                  onPressed: _page.next,
                  child: const Text('Показать ещё'),
                ),
              if (_page.items.isEmpty && !_page.loading)
                const ListTile(
                  title: Text('Сначала создайте плейлист в медиатеке'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetadataEditor extends StatefulWidget {
  const _MetadataEditor({required this.backend, required this.track});
  final BackendController backend;
  final api.Track track;
  @override
  State<_MetadataEditor> createState() => _MetadataEditorState();
}

class _MetadataEditorState extends State<_MetadataEditor> {
  late final _title = TextEditingController(text: widget.track.title);
  late final _artist = TextEditingController(text: widget.track.artist);
  late final _album = TextEditingController(text: widget.track.album);
  late String _revision = widget.track.revision;
  String? _operationId;
  bool _saving = false;
  bool _rejected = false;
  edits.MetadataEdit? _attempt;
  String? _outcome;
  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Данные композиции'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              enabled: _attempt == null,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artist,
              enabled: _attempt == null,
              decoration: const InputDecoration(labelText: 'Исполнитель'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _album,
              enabled: _attempt == null,
              decoration: const InputDecoration(labelText: 'Альбом'),
            ),
            if (_saving) const LinearProgressIndicator(),
            if (_outcome != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_outcome!),
              ),
            if (_rejected)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: _saving || widget.backend.busy ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Загрузить актуальные данные'),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
      FilledButton(
        onPressed: _saving || widget.backend.busy || _rejected ? null : _save,
        child: Text(_attempt == null ? 'Сохранить' : 'Проверить результат'),
      ),
    ],
  );
  Future<void> _save() async {
    if (_saving || widget.backend.busy || _rejected) return;
    setState(() => _saving = true);
    final b = widget.backend;
    await b.operate((op) async {
      if (_attempt != null) {
        final result = await edits.commandStatus(
          sessionId: b.sessionId,
          operationId: _operationId!,
        );
        if (mounted) {
          setState(() {
            _outcome = result == null
                ? 'Команда ещё не подтверждена. Изменения не отправлены повторно.'
                : commandMessage(result);
            _rejected = result?.state == edits.CommandState.rejected;
          });
        }
        return;
      }
      _operationId = await api.newOperationId();
      _attempt = edits.MetadataEdit(
        expectedRevision: _revision,
        title: _title.text,
        artist: _artist.text,
        album: _album.text,
        albumArtist: null,
        durationMs: null,
        year: null,
        genre: null,
        trackNumber: null,
        discNumber: null,
        composer: null,
        comment: null,
        copyright: null,
        artwork: null,
        clearArtwork: false,
        lyrics: null,
        clearLyrics: false,
      );
      final result = await edits.editMetadata(
        sessionId: b.sessionId,
        operationId: _operationId!,
        trackId: widget.track.id,
        edit: _attempt!,
        operation: op,
      );
      b.commandResults.value = result;
      if (mounted)
        setState(() {
          _outcome = commandMessage(result);
          _rejected = result.state == edits.CommandState.rejected;
        });
    });
    if (mounted)
      setState(() {
        _saving = false;
        _outcome ??= b.error?.toString();
      });
  }

  Future<void> _reload() async {
    if (!_rejected || _saving || widget.backend.busy) return;
    setState(() => _saving = true);
    final b = widget.backend;
    await b.action(() async {
      final latest = await content.track(
        sessionId: b.sessionId,
        trackId: widget.track.id,
      );
      if (latest == null) throw StateError('Композиция больше не найдена');
      if (!mounted) return;
      _title.text = latest.metadata.title;
      _artist.text = latest.metadata.artist;
      _album.text = latest.metadata.album;
      setState(() {
        _revision = latest.revision;
        _operationId = null;
        _attempt = null;
        _rejected = false;
        _outcome = 'Данные обновлены. Внесите изменения и сохраните.';
      });
    });
    if (mounted)
      setState(() {
        _saving = false;
        if (b.error != null) _outcome = b.error.toString();
      });
  }
}

String commandMessage(edits.Command command) => switch (command.state) {
  edits.CommandState.applied => 'Изменения сохранены',
  edits.CommandState.rejected =>
    'Изменение отклонено. Обновите данные и повторите действие.',
  edits.CommandState.telegramError => 'Telegram не подтвердил изменение.',
  edits.CommandState.unknown =>
    'Результат пока неизвестен. Дождитесь синхронизации.',
  _ => 'Изменения отправлены. Ожидаем подтверждения.',
};
