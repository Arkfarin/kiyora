import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api/edits.dart' as edits;
import '../../core/bridge/generated/api.dart' as api;
import '../../core/routing/navigation.dart';
import '../../core/state/backend_controller.dart';
import '../../core/state/paged_query.dart';
import '../../core/widgets/artwork.dart';
import '../player/player.dart';
import 'track_actions.dart';

enum LibraryFilter { tracks, playlists, albums, artists }

String filterLabel(LibraryFilter filter) => switch (filter) {
  LibraryFilter.tracks => 'Композиции',
  LibraryFilter.playlists => 'Плейлисты',
  LibraryFilter.albums => 'Альбомы',
  LibraryFilter.artists => 'Исполнители',
};

class LibraryView extends StatefulWidget {
  const LibraryView({
    super.key,
    required this.backend,
    required this.navigation,
    required this.location,
    this.initialFilter = LibraryFilter.tracks,
    this.search = '',
  });
  final BackendController backend;
  final MusicNavigation navigation;
  final MusicLocation location;
  final LibraryFilter initialFilter;
  final String search;
  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  late LibraryFilter _filter;
  late final PagedQuery<Object> _page;
  late final TextEditingController _search;
  Timer? _debounce;
  String _query = '';
  BigInt? _total;
  BackendController get b => widget.backend;
  bool get _detail => {
    Destination.playlist,
    Destination.album,
    Destination.artist,
    Destination.favorites,
  }.contains(widget.location.destination);
  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _query = widget.search;
    _search = TextEditingController(text: _query);
    _page = PagedQuery(_fetch)..reset();
    b.libraryRevision.addListener(_refresh);
  }

  @override
  void didUpdateWidget(LibraryView old) {
    super.didUpdateWidget(old);
    if (old.search != widget.search) {
      _query = widget.search;
      _search.text = _query;
      _refresh();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    b.libraryRevision.removeListener(_refresh);
    _page.dispose();
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    _total = null;
    _page.reset();
  }

  Future<List<Object>> _fetch(int offset, int limit) async {
    final location = widget.location;
    switch (location.destination) {
      case Destination.playlist:
        final page = await edits.playlist(
          sessionId: b.sessionId,
          playlistId: location.id!,
          query: _query,
          offset: offset,
          limit: limit,
        );
        _total = page?.total;
        return page?.items ?? [];
      case Destination.album:
      case Destination.artist:
        return content.catalogTracks(
          sessionId: b.sessionId,
          album: location.destination == Destination.album
              ? location.title
              : null,
          artist: location.artist!,
          offset: offset,
          limit: limit,
        );
      case Destination.favorites:
        final page = await edits.favorites(
          sessionId: b.sessionId,
          setName: 'liked',
          offset: offset,
          limit: limit,
        );
        _total = page.total;
        return page.tracks;
      default:
        return switch (_filter) {
          LibraryFilter.tracks => api.library_(
            sessionId: b.sessionId,
            query: _query,
            offset: offset,
            limit: limit,
          ),
          LibraryFilter.playlists => content.playlists(
            sessionId: b.sessionId,
            query: _query,
            offset: offset,
            limit: limit,
          ),
          LibraryFilter.albums => content.albums(
            sessionId: b.sessionId,
            query: _query,
            offset: offset,
            limit: limit,
          ),
          LibraryFilter.artists => content.artists(
            sessionId: b.sessionId,
            query: _query,
            offset: offset,
            limit: limit,
          ),
        };
    }
  }

  String get _title => switch (widget.location.destination) {
    Destination.search => 'Поиск',
    Destination.playlist ||
    Destination.album ||
    Destination.artist => widget.location.title ?? 'Медиатека',
    Destination.favorites => 'Любимые композиции',
    _ => 'Моя медиатека',
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _page,
    builder: (context, _) => CustomScrollView(
      key: PageStorageKey(
        '${widget.location.destination}:${widget.location.id}:${widget.location.title}:$_filter',
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_detail)
                  _detailHeader(context)
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Создать плейлист',
                        onPressed: () =>
                            createPlaylist(context, b, widget.navigation),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: 'Импорт музыки',
                        onPressed: () => widget.navigation.go(
                          const MusicLocation(Destination.imports),
                        ),
                        icon: const Icon(Icons.file_upload_outlined),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (!_detail &&
                    (MediaQuery.sizeOf(context).width < 900 ||
                        widget.location.destination != Destination.search))
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Что хотите послушать?',
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 220), () {
                        _query = value;
                        _refresh();
                      });
                    },
                  ),
                if (!_detail) ...[
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in LibraryFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filterLabel(filter)),
                              selected: _filter == filter,
                              onSelected: (_) {
                                setState(() => _filter = filter);
                                _refresh();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (_page.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (_page.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_page.error.toString()),
                        TextButton(
                          onPressed: _page.reset,
                          child: const Text('Повторить загрузку'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_page.firstOffset > 0)
          SliverToBoxAdapter(
            child: TextButton(
              onPressed: _page.previous,
              child: const Text('Предыдущие композиции'),
            ),
          ),
        if (_page.items.isEmpty && !_page.loading && _page.error == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.library_music_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _query.isEmpty
                          ? 'Здесь появится ваша музыка'
                          : 'Ничего не найдено',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _query.isEmpty
                          ? 'Импортируйте музыку или синхронизируйте библиотеку.'
                          : 'Попробуйте другое название или исполнителя.',
                    ),
                    if (_query.isEmpty)
                      TextButton(
                        onPressed: () => widget.navigation.go(
                          const MusicLocation(Destination.imports),
                        ),
                        child: const Text('Добавить музыку'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: _page.items.length,
          itemBuilder: (context, index) => _row(_page.items[index], index),
        ),
        if (_page.hasMore && _page.items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: _page.loading ? null : _page.next,
                child: const Text('Показать ещё'),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    ),
  );

  Widget _detailHeader(BuildContext context) {
    final first = _page.items.firstOrNull;
    final track = first is api.Track
        ? first
        : first is edits.PlaylistEntry
        ? first.track
        : null;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.location.artist != null) Text(widget.location.artist!),
        if (_total != null) Text('$_total композиций'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _page.items.isEmpty ? null : () => _play(0),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Слушать'),
        ),
      ],
    );
    final art = MusicArtwork(
      sessionId: b.sessionId,
      trackId: track?.id,
      digest: track?.artworkDigest,
      size: narrow ? 156 : 190,
      round: widget.location.destination == Destination.artist,
    );
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: art),
              const SizedBox(height: 24),
              title,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              art,
              const SizedBox(width: 24),
              Expanded(child: title),
            ],
          );
  }

  void _play(int index) {
    if (widget.location.destination == Destination.playlist) {
      final item = _page.items[index] as edits.PlaylistEntry;
      b.action(() async {
        b.queue.value = await content.playPlaylist(
          sessionId: b.sessionId,
          playlistId: widget.location.id!,
          position: item.position,
        );
      });
    } else {
      final tracks = _page.items.whereType<api.Track>().toList();
      b.play(tracks.map((t) => t.id).toList(), index);
    }
  }

  Widget _row(Object object, int index) {
    if (object is api.Track || object is edits.PlaylistEntry) {
      final entry = object is edits.PlaylistEntry ? object : null;
      final track = entry?.track ?? object as api.Track;
      return TrackRow(
        backend: b,
        track: track,
        onPlay: () => _play(index),
        onMenu: (anchor) => showTrackActions(
          context,
          b,
          widget.navigation,
          track,
          anchor: anchor,
          playlistId: widget.location.id,
          entryId: entry?.entryId,
        ),
      );
    }
    final (title, subtitle, icon, destination) = switch (object) {
      content.Playlist p => (
        p.title,
        'Плейлист',
        Icons.playlist_play,
        MusicLocation(Destination.playlist, id: p.id, title: p.title),
      ),
      content.Album a => (
        a.title,
        '${a.artist} · ${a.trackCount} композиций',
        Icons.album_outlined,
        MusicLocation(Destination.album, title: a.title, artist: a.artist),
      ),
      content.Artist a => (
        a.name,
        '${a.trackCount} композиций',
        Icons.person_outline,
        MusicLocation(Destination.artist, title: a.name, artist: a.name),
      ),
      _ => throw StateError('Unsupported library item'),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: object is content.Artist
              ? BoxShape.circle
              : BoxShape.rectangle,
        ),
        child: Icon(icon),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => widget.navigation.go(destination),
    );
  }
}

class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.backend,
    required this.track,
    required this.onPlay,
    required this.onMenu,
  });
  final BackendController backend;
  final api.Track track;
  final VoidCallback onPlay;
  final void Function(Offset?) onMenu;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onSecondaryTapDown: (d) => onMenu(d.globalPosition),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: MusicArtwork(
        sessionId: backend.sessionId,
        trackId: track.id,
        digest: track.artworkDigest,
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (MediaQuery.sizeOf(context).width >= 900)
            Text(
              musicTime(track.durationMs.toInt()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Действия с композицией',
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                final box = context.findRenderObject() as RenderBox?;
                onMenu(box?.localToGlobal(Offset.zero));
              },
            ),
          ),
        ],
      ),
      onTap: onPlay,
      onLongPress: () => onMenu(null),
    ),
  );
}
