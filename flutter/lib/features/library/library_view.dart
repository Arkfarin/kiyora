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

enum LibraryFilter { tracks, playlists, albums, artists, downloaded }

String filterLabel(LibraryFilter filter) => switch (filter) {
  LibraryFilter.tracks => 'Композиции',
  LibraryFilter.playlists => 'Плейлисты',
  LibraryFilter.albums => 'Альбомы',
  LibraryFilter.artists => 'Исполнители',
  LibraryFilter.downloaded => 'Скачанные',
};

String _sortLabel(api.TrackSort sort) => switch (sort) {
  api.TrackSort.existing => 'По умолчанию',
  api.TrackSort.title => 'По названию',
  api.TrackSort.artist => 'По исполнителю',
  api.TrackSort.album => 'По альбому',
};

class LibraryView extends StatefulWidget {
  const LibraryView({
    super.key,
    required this.backend,
    required this.navigation,
    required this.location,
    this.initialFilter = LibraryFilter.tracks,
    this.search = '',
    this.mobile = false,
    this.externalSearch = false,
    this.onFilterChanged,
    this.onLocalSearchChanged,
  });
  final BackendController backend;
  final MusicNavigation navigation;
  final MusicLocation location;
  final LibraryFilter initialFilter;
  final String search;
  final bool mobile, externalSearch;
  final ValueChanged<LibraryFilter>? onFilterChanged;
  final ValueChanged<String>? onLocalSearchChanged;
  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  late LibraryFilter _filter;
  api.TrackSort _sort = api.TrackSort.existing;
  late final PagedQuery<Object> _page;
  late final TextEditingController _search;
  final _mobileScroll = ScrollController(keepScrollOffset: false);
  PageStorageBucket? _storage;
  bool _restoreScroll = true;
  bool _restoredSort = false;
  int _requestVersion = 0;
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
    _page = PagedQuery(_fetch);
    b.libraryRevision.addListener(_refresh);
  }

  @override
  void didUpdateWidget(LibraryView old) {
    super.didUpdateWidget(old);
    if ((!widget.mobile || widget.externalSearch) &&
        old.search != widget.search &&
        _query != widget.search) {
      _debounce?.cancel();
      _query = widget.search;
      _search.text = _query;
      _resetResults();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = PageStorage.maybeOf(context);
    if (!_restoredSort) {
      _restoredSort = true;
      final sort = _storage?.readState(context, identifier: _sortId);
      if (sort is api.TrackSort) _sort = sort;
      _refresh();
    }
  }

  Object get _sortId =>
      (b.sessionId, widget.location.destination, 'track-sort');

  bool get _trackFilter =>
      _filter == LibraryFilter.tracks || _filter == LibraryFilter.downloaded;

  Object get _scrollId => (
    widget.location.destination,
    widget.location.id,
    widget.location.title,
    widget.location.artist,
    _filter,
    _sort,
    _query,
  );

  void _restoreMobileScroll() {
    if (!widget.mobile || !_restoreScroll || _page.loading) return;
    _restoreScroll = false;
    final id = _scrollId;
    final offset = _storage?.readState(context, identifier: id);
    if (offset is! double || offset == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrollId != id || !_mobileScroll.hasClients) return;
      _mobileScroll.jumpTo(
        offset.clamp(0.0, _mobileScroll.position.maxScrollExtent),
      );
    });
  }

  void _resetResults() {
    _restoreScroll = false;
    // A global query can arrive in didUpdateWidget. Scrolling there would
    // notify the AppBar while it is building.
    final id = _scrollId;
    if (widget.mobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollId == id && _mobileScroll.hasClients) {
          _mobileScroll.jumpTo(0);
        }
      });
    }
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mobileScroll.dispose();
    b.libraryRevision.removeListener(_refresh);
    _page.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    _requestVersion++;
    _total = null;
    return _page.reset();
  }

  Future<List<Object>> _fetch(int offset, int limit) async {
    final location = widget.location;
    final version = _requestVersion;
    switch (location.destination) {
      case Destination.playlist:
        final page = await edits.playlist(
          sessionId: b.sessionId,
          playlistId: location.id!,
          query: _query,
          offset: offset,
          limit: limit,
        );
        if (mounted && version == _requestVersion) _total = page?.total;
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
        if (mounted && version == _requestVersion) _total = page.total;
        return page.tracks;
      default:
        return switch (_filter) {
          LibraryFilter.tracks || LibraryFilter.downloaded =>
            _filter == LibraryFilter.tracks && _sort == api.TrackSort.existing
                ? api.library_(
                    sessionId: b.sessionId,
                    query: _query,
                    offset: offset,
                    limit: limit,
                  )
                : api.libraryFiltered(
                    sessionId: b.sessionId,
                    query: _query,
                    downloadedOnly: _filter == LibraryFilter.downloaded,
                    sort: _sort,
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

  Widget _filterChip(LibraryFilter filter) => ChoiceChip(
    label: Text(filterLabel(filter)),
    selected: _filter == filter,
    onSelected: (_) {
      if (_filter == filter) return;
      setState(() => _filter = filter);
      widget.onFilterChanged?.call(filter);
      if (widget.mobile && !widget.externalSearch) {
        _debounce?.cancel();
        _query = _search.text;
      }
      _resetResults();
    },
  );

  Widget _sortMenu() => PopupMenuButton<api.TrackSort>(
    tooltip: 'Сортировка',
    initialValue: _sort,
    onSelected: (sort) {
      if (sort == _sort) return;
      setState(() => _sort = sort);
      _storage?.writeState(context, sort, identifier: _sortId);
      if (widget.mobile && !widget.externalSearch) {
        _debounce?.cancel();
        _query = _search.text;
      }
      _resetResults();
    },
    itemBuilder: (_) => [
      for (final sort in api.TrackSort.values)
        CheckedPopupMenuItem(
          value: sort,
          checked: sort == _sort,
          child: Text(_sortLabel(sort)),
        ),
    ],
    icon: Icon(
      Icons.sort,
      color: _sort == api.TrackSort.existing
          ? null
          : Theme.of(context).colorScheme.primary,
    ),
  );

  Widget _emptyState(BuildContext context) {
    final nav = widget.navigation;
    final destination = widget.location.destination;
    var title = 'Здесь появится ваша музыка';
    var description = 'Импортируйте музыку или синхронизируйте библиотеку.';
    var actionLabel = 'Добавить музыку';
    VoidCallback? action = () =>
        nav.go(const MusicLocation(Destination.imports));
    if (_query.isNotEmpty) {
      title = 'Ничего не найдено';
      description = 'Попробуйте другое название или исполнителя.';
      action = null;
    } else if (!_detail && _filter == LibraryFilter.downloaded) {
      title = 'Нет скачанных композиций';
      description = 'Скачайте музыку через меню композиции. Здесь появятся файлы, доступные офлайн.';
      actionLabel = 'Все композиции';
      action = () {
        setState(() => _filter = LibraryFilter.tracks);
        widget.onFilterChanged?.call(_filter);
        _resetResults();
      };
    } else if (widget.mobile) {
      if (destination == Destination.search) {
        title = 'Найдите свою музыку';
        description = 'Введите название композиции, альбома или исполнителя.';
        action = null;
      } else if (destination == Destination.favorites) {
        title = 'Пока нет любимых композиций';
        description =
            'Добавляйте понравившиеся треки, чтобы быстро найти их здесь.';
        actionLabel = 'Открыть медиатеку';
        action = () => nav.go(const MusicLocation(Destination.library));
      } else if (destination == Destination.playlist) {
        title = 'Плейлист пока пуст';
        description =
            'Добавьте композиции из своей медиатеки через меню трека.';
        actionLabel = 'Открыть медиатеку';
        action = () => nav.go(const MusicLocation(Destination.library));
      } else if (destination == Destination.library &&
          _filter == LibraryFilter.playlists) {
        title = 'Создайте первый плейлист';
        description = 'Соберите любимую музыку в собственную подборку.';
        actionLabel = 'Создать плейлист';
        action = () => createPlaylist(context, b, nav);
      }
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              destination == Destination.favorites
                  ? Icons.favorite_outline
                  : destination == Destination.search
                  ? Icons.search
                  : Icons.library_music_outlined,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
            if (action != null)
              TextButton(onPressed: action, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _page,
    builder: (context, _) {
      _restoreMobileScroll();
      final scroll = CustomScrollView(
        key: PageStorageKey(
          '${widget.location.destination}:${widget.location.id}:${widget.location.title}:${widget.location.artist}:$_filter',
        ),
        controller: widget.mobile ? _mobileScroll : null,
        physics: widget.mobile ? const AlwaysScrollableScrollPhysics() : null,
        keyboardDismissBehavior: widget.mobile
            ? ScrollViewKeyboardDismissBehavior.onDrag
            : ScrollViewKeyboardDismissBehavior.manual,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: widget.mobile
                  ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
                  : const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_detail)
                    _detailHeader(context)
                  else if (!widget.mobile)
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
                  if (widget.mobile &&
                      widget.location.destination == Destination.library) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.favorite_outline, size: 20),
                          label: const Text('Любимое'),
                          onPressed: () => widget.navigation.go(
                            const MusicLocation(Destination.favorites),
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 20),
                          label: const Text('Плейлист'),
                          onPressed: () =>
                              createPlaylist(context, b, widget.navigation),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.file_upload_outlined,
                            size: 20,
                          ),
                          label: const Text('Импорт'),
                          onPressed: () => widget.navigation.go(
                            const MusicLocation(Destination.imports),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!widget.mobile || _detail) const SizedBox(height: 16),
                  if (!_detail &&
                      !widget.externalSearch &&
                      (MediaQuery.sizeOf(context).width < 900 ||
                          widget.mobile ||
                          widget.location.destination != Destination.search))
                    ValueListenableBuilder(
                      valueListenable: _search,
                      builder: (context, value, _) => TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: widget.mobile
                              ? 'Поиск в медиатеке'
                              : 'Что хотите послушать?',
                          suffixIcon: widget.mobile && value.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Очистить поиск в медиатеке',
                                  onPressed: () {
                                    _debounce?.cancel();
                                    _search.clear();
                                    _query = '';
                                    widget.onLocalSearchChanged?.call('');
                                    _resetResults();
                                  },
                                  icon: const Icon(Icons.close),
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          widget.onLocalSearchChanged?.call(value);
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 220),
                            () {
                              _query = value;
                              _resetResults();
                            },
                          );
                        },
                        onSubmitted: (value) {
                          _debounce?.cancel();
                          _query = value;
                          _resetResults();
                          if (widget.mobile) FocusScope.of(context).unfocus();
                        },
                      ),
                    ),
                  if (!_detail) ...[
                    SizedBox(height: widget.externalSearch ? 0 : 16),
                    if (widget.mobile)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _filterChip(LibraryFilter.tracks),
                          _filterChip(LibraryFilter.playlists),
                          if (_trackFilter) _sortMenu(),
                          _filterChip(LibraryFilter.albums),
                          _filterChip(LibraryFilter.artists),
                          _filterChip(LibraryFilter.downloaded),
                        ],
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in LibraryFilter.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _filterChip(filter),
                              ),
                            if (_trackFilter) _sortMenu(),
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
              child: _emptyState(context),
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
      );
      return widget.mobile
          ? NotificationListener<ScrollUpdateNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    !_restoreScroll &&
                    !_page.loading) {
                  _storage?.writeState(
                    context,
                    notification.metrics.pixels,
                    identifier: _scrollId,
                  );
                }
                return false;
              },
              child: RefreshIndicator(onRefresh: _refresh, child: scroll),
            )
          : scroll;
    },
  );

  Widget _detailHeader(BuildContext context) {
    final first = _page.items.firstOrNull;
    final track = first is api.Track
        ? first
        : first is edits.PlaylistEntry
        ? first.track
        : null;
    final narrow =
        MediaQuery.sizeOf(context).width < (widget.mobile ? 800 : 700);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(fontWeight: FontWeight.w900),
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
        mobile: widget.mobile,
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
      contentPadding: EdgeInsets.symmetric(
        horizontal: widget.mobile ? 16 : 24,
        vertical: 6,
      ),
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
    this.mobile = false,
  });
  final BackendController backend;
  final api.Track track;
  final VoidCallback onPlay;
  final void Function(Offset?) onMenu;
  final bool mobile;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onSecondaryTapDown: (d) => onMenu(d.globalPosition),
    child: ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 24,
        vertical: mobile ? 4 : 2,
      ),
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
          if (!mobile && MediaQuery.sizeOf(context).width >= 900)
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
