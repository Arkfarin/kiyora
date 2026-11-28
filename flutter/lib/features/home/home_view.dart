import 'package:material_ui/material_ui.dart';

import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api/edits.dart' as edits;
import '../../core/bridge/generated/api.dart' as api;
import '../../core/routing/navigation.dart';
import '../../core/state/backend_controller.dart';
import '../../core/widgets/artwork.dart';
import '../library/track_actions.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.backend,
    required this.navigation,
    this.mobile = false,
    this.onOpenLibraryTracks,
  });
  final BackendController backend;
  final MusicNavigation navigation;
  final bool mobile;
  final VoidCallback? onOpenLibraryTracks;
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Future<_HomeData> _data;
  @override
  void initState() {
    super.initState();
    _refresh();
    widget.backend.libraryRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.backend.libraryRevision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    final b = widget.backend;
    final id = b.sessionId;
    final future = () async {
      final results = await Future.wait<Object>([
        api.library_(sessionId: id, query: null, offset: 0, limit: 12),
        content.playlists(sessionId: id, query: null, offset: 0, limit: 6),
        content.recentlyPlayed(sessionId: id, limit: 12),
        edits.favorites(sessionId: id, setName: 'liked', offset: 0, limit: 12),
        content.albums(sessionId: id, query: '', offset: 0, limit: 12),
        content.artists(sessionId: id, query: '', offset: 0, limit: 12),
      ]);
      return _HomeData(
        results[0] as List<api.Track>,
        results[1] as List<content.Playlist>,
        results[2] as List<api.Track>,
        (results[3] as edits.TrackPage).tracks,
        results[4] as List<content.Album>,
        results[5] as List<content.Artist>,
      );
    }();
    if (mounted) {
      setState(() {
        _data = future;
      });
    } else {
      _data = future;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Повторить загрузку'),
                ),
              ],
            ),
          ),
        );
      final data = snapshot.data;
      if (data == null) return const Center(child: CircularProgressIndicator());
      final nav = widget.navigation;
      final hour = DateTime.now().hour;
      final greeting = hour < 6
          ? 'Доброй ночи'
          : hour < 12
          ? 'Доброе утро'
          : hour < 18
          ? 'Добрый день'
          : 'Добрый вечер';
      final scroll = CustomScrollView(
        key: const PageStorageKey('home'),
        physics: widget.mobile ? const AlwaysScrollableScrollPhysics() : null,
        slivers: [
          SliverPadding(
            padding: widget.mobile
                ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
                : const EdgeInsets.fromLTRB(24, 24, 24, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.mobile) ...[
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth < 280
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 8) / 2;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuickLink(
                              width: width,
                              title: 'Любимое',
                              icon: Icons.favorite,
                              onTap: () => nav.go(
                                const MusicLocation(Destination.favorites),
                              ),
                            ),
                            _QuickLink(
                              width: width,
                              title: 'Добавить музыку',
                              icon: Icons.add,
                              onTap: () => nav.go(
                                const MusicLocation(Destination.imports),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (data.playlists.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Ваши плейлисты',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        const Chip(label: Text('Музыка')),
                        ActionChip(
                          label: const Text('Любимые композиции'),
                          onPressed: () => nav.go(
                            const MusicLocation(Destination.favorites),
                          ),
                        ),
                        ActionChip(
                          label: const Text('Добавить музыку'),
                          onPressed: () =>
                              nav.go(const MusicLocation(Destination.imports)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          widget.mobile && constraints.maxWidth < 280
                          ? 1
                          : constraints.maxWidth > 750
                          ? 3
                          : 2;
                      final width =
                          (constraints.maxWidth - 8 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final playlist in data.playlists)
                            SizedBox(
                              width: width,
                              height: 64,
                              child: Material(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  widget.mobile ? 12 : 4,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => nav.go(
                                    MusicLocation(
                                      Destination.playlist,
                                      id: playlist.id,
                                      title: playlist.title,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox.square(
                                        dimension: widget.mobile ? 48 : 64,
                                        child: const Icon(
                                          Icons.playlist_play,
                                          size: 28,
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Text(
                                            playlist.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (data.recent.isNotEmpty)
            _tracks('Недавно прослушанное', data.recent),
          if (data.liked.isNotEmpty)
            _tracks(
              'Любимые композиции',
              data.liked,
              open: () => nav.go(const MusicLocation(Destination.favorites)),
            ),
          if (data.tracks.isNotEmpty)
            _tracks(
              'В вашей медиатеке',
              data.tracks,
              open:
                  widget.onOpenLibraryTracks ??
                  () => nav.go(const MusicLocation(Destination.library)),
            ),
          if (data.albums.isNotEmpty)
            _collection(
              'Альбомы',
              data.albums
                  .map(
                    (album) => _CatalogCard(
                      title: album.title,
                      subtitle: album.artist,
                      icon: Icons.album_outlined,
                      mobile: widget.mobile,
                      onTap: () => nav.go(
                        MusicLocation(
                          Destination.album,
                          title: album.title,
                          artist: album.artist,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (data.artists.isNotEmpty)
            _collection(
              'Исполнители',
              data.artists
                  .map(
                    (artist) => _CatalogCard(
                      title: artist.name,
                      subtitle: 'Исполнитель',
                      icon: Icons.person_outline,
                      mobile: widget.mobile,
                      round: true,
                      onTap: () => nav.go(
                        MusicLocation(
                          Destination.artist,
                          title: artist.name,
                          artist: artist.name,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (data.tracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Начните со своей любимой музыки',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Добавьте файлы — KIYORA сохранит их в вашей библиотеке Telegram.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () =>
                            nav.go(const MusicLocation(Destination.imports)),
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить музыку'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
      return widget.mobile
          ? RefreshIndicator(
              onRefresh: () async {
                _refresh();
                try {
                  await _data;
                } catch (_) {
                  // FutureBuilder presents a retry action for this failure.
                }
              },
              child: scroll,
            )
          : scroll;
    },
  );
  Widget _tracks(String title, List<api.Track> tracks, {VoidCallback? open}) =>
      _collection(title, [
        for (var i = 0; i < tracks.length; i++)
          _TrackCard(
            backend: widget.backend,
            track: tracks[i],
            mobile: widget.mobile,
            onTap: () =>
                widget.backend.play(tracks.map((t) => t.id).toList(), i),
            onMenu: () => showTrackActions(
              context,
              widget.backend,
              widget.navigation,
              tracks[i],
            ),
          ),
      ], open: open);
  Widget _collection(String title, List<Widget> cards, {VoidCallback? open}) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.mobile ? 16 : 24,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (open != null)
                      TextButton(
                        onPressed: open,
                        child: const Text('Показать всё'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: widget.mobile
                    ? 164 + MediaQuery.textScalerOf(context).scale(38)
                    : 236,
                child: ListView.separated(
                  key: PageStorageKey('home-collection:$title'),
                  primary: false,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (_, i) => cards[i],
                ),
              ),
            ],
          ),
        ),
      );
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.width,
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final double width;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeData {
  _HomeData(
    this.tracks,
    this.playlists,
    this.recent,
    this.liked,
    this.albums,
    this.artists,
  );
  final List<api.Track> tracks, recent, liked;
  final List<content.Playlist> playlists;
  final List<content.Album> albums;
  final List<content.Artist> artists;
}

class _TrackCard extends StatefulWidget {
  const _TrackCard({
    required this.backend,
    required this.track,
    required this.onTap,
    required this.onMenu,
    required this.mobile,
  });
  final BackendController backend;
  final api.Track track;
  final VoidCallback onTap, onMenu;
  final bool mobile;
  @override
  State<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<_TrackCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: SizedBox(
      width: widget.mobile ? 144 : 176,
      child: Material(
        color: _hover
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(widget.mobile ? 12 : 6),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onMenu,
          borderRadius: BorderRadius.circular(widget.mobile ? 12 : 6),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    MusicArtwork(
                      sessionId: widget.backend.sessionId,
                      trackId: widget.track.id,
                      digest: widget.track.artworkDigest,
                      size: widget.mobile ? 128 : 160,
                    ),
                    if (widget.mobile)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: IconButton.filledTonal(
                          tooltip: 'Действия с композицией',
                          onPressed: widget.onMenu,
                          icon: const Icon(Icons.more_horiz),
                        ),
                      )
                    else if (_hover)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: IconButton.filled(
                          tooltip: 'Воспроизвести',
                          onPressed: widget.onTap,
                          icon: const Icon(Icons.play_arrow),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.mobile,
    this.round = false,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool round, mobile;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: mobile ? 144 : 176,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: mobile ? 128 : 160,
              height: mobile ? 128 : 160,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: round
                    ? null
                    : BorderRadius.circular(mobile ? 12 : 0),
              ),
              child: Icon(icon, size: 64),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
