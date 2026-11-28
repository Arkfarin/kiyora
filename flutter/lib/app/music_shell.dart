import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/bridge/generated/api/edits.dart' as edits;
import '../core/routing/navigation.dart';
import '../core/state/backend_controller.dart';
import '../core/theme/kiyora_theme.dart';
import '../core/widgets/artwork.dart';
import '../features/home/home_view.dart';
import '../features/imports/import_view.dart';
import '../features/imports/import_selection.dart';
import '../features/library/library_view.dart';
import '../features/library/track_actions.dart';
import '../features/lyrics/lyrics_view.dart';
import '../features/onboarding/onboarding.dart';
import '../features/player/player.dart';
import '../features/queue/queue_view.dart';
import '../features/settings/settings_view.dart';
import '../features/settings/profile_menu.dart';

enum ContextPanel { playing, queue, lyrics }

// A history entry has its own identity even when callers reuse const routes.
// The mobile tab history can then associate detail pages with their origin.
class _ShellNavigation extends MusicNavigation {
  @override
  void go(MusicLocation location) => super.go(
    MusicLocation(
      location.destination,
      id: location.id,
      title: location.title,
      artist: location.artist,
    ),
  );
}

class MusicShell extends StatefulWidget {
  const MusicShell({
    super.key,
    required this.backend,
    required this.themeMode,
    required this.onThemeChanged,
    this.searchHistory = const [],
    this.onSearchHistoryChanged,
  });
  final BackendController backend;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final List<String> searchHistory;
  final ValueChanged<List<String>>? onSearchHistoryChanged;
  @override
  State<MusicShell> createState() => _MusicShellState();
}

class _MusicShellState extends State<MusicShell> {
  final _navigation = _ShellNavigation();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _storage = PageStorageBucket();
  double _leftWidth = 280;
  double _rightWidth = 320;
  bool _compactLibrary = false;
  ContextPanel? _panel;
  Timer? _searchDelay;
  String _query = '';
  final _tabHistory = Expando<int>();
  int _mobileTab = 0;
  LibraryFilter _mobileLibraryFilter = LibraryFilter.tracks;
  LibraryFilter _mobileSearchFilter = LibraryFilter.tracks;
  String _mobileLibraryQuery = '';
  late List<String> _searchHistory;
  BackendController get b => widget.backend;
  late final ImportSelection _imports;
  @override
  void initState() {
    super.initState();
    _searchHistory = List.of(widget.searchHistory);
    _imports = ImportSelection(b);
    _navigation.addListener(_rememberMobileTab);
    b.commandResults.addListener(_command);
    b.addListener(_error);
  }

  void _command() {
    final command = b.commandResults.value;
    if (command == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(commandMessage(command))));
    if (command.state == edits.CommandState.applied) b.libraryRevision.value++;
  }

  Object? _lastError;
  void _error() {
    if (b.error == null || identical(b.error, _lastError) || !mounted) return;
    _lastError = b.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(b.error.toString()),
        action: SnackBarAction(label: 'Закрыть', onPressed: b.clearError),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Close a docked panel when it no longer fits; do not resurrect it
    // when the window grows again.
    final width = MediaQuery.sizeOf(context).width;
    if (width < 1200 || _isMobileLayout(width)) _panel = null;
  }

  bool _isMobileLayout(double width) =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      (defaultTargetPlatform != TargetPlatform.linux && width < 900);

  void _rememberMobileTab() {
    final location = _navigation.current;
    final wasSearching = _mobileTab == 1;
    _mobileTab = switch (location.destination) {
      Destination.home => 0,
      Destination.search => 1,
      Destination.library => 2,
      _ => _tabHistory[location] ?? _mobileTab,
    };
    _tabHistory[location] = _mobileTab;
    if (_isMobileLayout(MediaQuery.sizeOf(context).width) &&
        location.destination != Destination.search) {
      if (wasSearching) _rememberSearch(_search.text);
      _searchDelay?.cancel();
      _query = _search.text;
      _searchFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    b.commandResults.removeListener(_command);
    b.removeListener(_error);
    _navigation.removeListener(_rememberMobileTab);
    _navigation.dispose();
    _imports.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openPanel(ContextPanel panel) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200 && !_isMobileLayout(width)) {
      setState(() => _panel = _panel == panel ? null : panel);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      if (_panel != null) setState(() => _panel = null);
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 440,
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Закрыть панель',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(child: _panelContent(panel)),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlaybackProgress(backend: b),
                      TransportControls(backend: b),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      if (_panel != null) setState(() => _panel = null);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: _panelContent(panel, mobile: true),
        ),
      );
    }
  }

  void _openPlayer() {
    final width = MediaQuery.sizeOf(context).width;
    if (defaultTargetPlatform == TargetPlatform.linux ||
        (width >= 1200 && !_isMobileLayout(width))) {
      _openPanel(ContextPanel.playing);
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => FullscreenPlayer(
          backend: b,
          navigation: _navigation,
          openQueue: () => _openPanel(ContextPanel.queue),
          openLyrics: () => _openPanel(ContextPanel.lyrics),
        ),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(title: const Text('Войти в Telegram')),
          body: SafeArea(
            child: Onboarding(
              backend: b,
              onConnected: () => Navigator.of(routeContext).pop(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelContent(ContextPanel panel, {bool mobile = false}) =>
      switch (panel) {
        ContextPanel.queue => QueueView(backend: b),
        ContextPanel.lyrics => LyricsView(backend: b, transport: mobile),
        ContextPanel.playing => ValueListenableBuilder(
          valueListenable: b.currentTrack,
          builder: (context, track, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Сейчас играет',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (_, c) => MusicArtwork(
                  sessionId: b.sessionId,
                  trackId: track?.id,
                  digest: track?.metadata.artworkDigest,
                  size: c.maxWidth,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                track?.metadata.title ?? 'Выберите композицию',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(track?.metadata.artist ?? ''),
              if (track?.metadata.album.isNotEmpty == true) ...[
                const SizedBox(height: 24),
                Text(track!.metadata.album),
              ],
            ],
          ),
        ),
      };
  Widget _content(MusicLocation location, {required bool mobile}) {
    final key = ValueKey(
      '${location.destination}:${location.id}:${location.title}:${location.artist}',
    );
    if (mobile &&
        location.destination == Destination.search &&
        _query.trim().isEmpty &&
        _searchHistory.isNotEmpty) {
      return _recentSearches();
    }
    return switch (location.destination) {
      Destination.home => HomeView(
        key: key,
        backend: b,
        navigation: _navigation,
        mobile: mobile,
        onOpenLibraryTracks: mobile
            ? () {
                _mobileLibraryFilter = LibraryFilter.tracks;
                _mobileLibraryQuery = '';
                _selectMobileTab(2);
              }
            : null,
      ),
      Destination.imports => ImportView(
        key: key,
        backend: b,
        selection: _imports,
      ),
      Destination.settings => SettingsView(
        key: key,
        backend: b,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onLogin: _openLogin,
      ),
      _ => LibraryView(
        key: key,
        backend: b,
        navigation: _navigation,
        location: location,
        mobile: mobile,
        externalSearch: mobile && location.destination == Destination.search,
        initialFilter: mobile && location.destination == Destination.search
            ? _mobileSearchFilter
            : mobile && location.destination == Destination.library
            ? _mobileLibraryFilter
            : LibraryFilter.tracks,
        search: location.destination == Destination.search
            ? _query
            : mobile && location.destination == Destination.library
            ? _mobileLibraryQuery
            : '',
        onFilterChanged: mobile
            ? (filter) {
                if (location.destination == Destination.search) {
                  _mobileSearchFilter = filter;
                } else if (location.destination == Destination.library) {
                  _mobileLibraryFilter = filter;
                }
              }
            : null,
        onLocalSearchChanged:
            mobile && location.destination == Destination.library
            ? (query) => _mobileLibraryQuery = query
            : null,
      ),
    };
  }

  void _go(Destination destination) =>
      _navigation.go(MusicLocation(destination));

  void _selectMobileTab(int index, {bool focusSearch = false}) {
    final destination = [
      Destination.home,
      Destination.search,
      Destination.library,
    ][index];
    if (_navigation.current.destination == destination) {
      if (destination == Destination.search) _searchFocus.requestFocus();
      return;
    }
    // Root tabs replace the previous tab's history. Android Back then returns
    // to Home, while detail pages keep their normal local history.
    _navigation.reset();
    if (destination != Destination.home) _go(destination);
    if (destination == Destination.search &&
        (focusSearch || (_search.text.isEmpty && _searchHistory.isEmpty))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _navigation.current.destination == Destination.search) {
          _searchFocus.requestFocus();
        }
      });
    }
  }

  void _changeSearch(String value, {required bool mobile}) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = value);
      if (!mobile && _navigation.current.destination != Destination.search) {
        _go(Destination.search);
      }
    });
  }

  void _rememberSearch(String value) {
    final query = value.trim();
    if (query.isEmpty ||
        query.length > 128 ||
        _searchHistory.firstOrNull == query)
      return;
    _setSearchHistory(
      [
        query,
        ..._searchHistory.where(
          (previous) => previous.toLowerCase() != query.toLowerCase(),
        ),
      ].take(10).toList(),
    );
  }

  void _setSearchHistory(List<String> queries) {
    setState(() => _searchHistory = queries);
    widget.onSearchHistoryChanged?.call(List.unmodifiable(queries));
  }

  Widget _recentSearches() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Недавние запросы',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            onPressed: () => _setSearchHistory([]),
            child: const Text('Очистить'),
          ),
        ],
      ),
      for (final query in _searchHistory)
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(query, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: 'Удалить запрос',
            onPressed: () => _setSearchHistory(
              _searchHistory.where((item) => item != query).toList(),
            ),
            icon: const Icon(Icons.close),
          ),
          onTap: () {
            _searchDelay?.cancel();
            _search.text = query;
            _searchFocus.unfocus();
            setState(() => _query = query);
            _rememberSearch(query);
          },
        ),
    ],
  );

  Widget _mobileSearchField() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: ValueListenableBuilder(
      valueListenable: _search,
      builder: (context, value, _) => TextField(
        key: const ValueKey('mobile-global-search'),
        controller: _search,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Что хотите послушать?',
          isDense: true,
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Очистить поиск',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchDelay?.cancel();
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
        onChanged: (value) => _changeSearch(value, mobile: true),
        onSubmitted: (value) {
          _searchDelay?.cancel();
          setState(() => _query = value);
          _rememberSearch(value);
          _searchFocus.unfocus();
        },
      ),
    ),
  );

  String _mobileTitle(MusicLocation location) => switch (location.destination) {
    Destination.home => 'KIYORA',
    Destination.search => 'Поиск',
    Destination.settings => 'Настройки',
    Destination.imports => 'Импорт',
    _ => 'Медиатека',
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _navigation,
    builder: (context, _) {
      final location = _navigation.current;
      final width = MediaQuery.sizeOf(context).width;
      final mobile = _isMobileLayout(width);
      final rail = mobile && width >= 700;
      final short = MediaQuery.sizeOf(context).height < 480;
      final keyboard = mobile && MediaQuery.viewInsetsOf(context).bottom > 0;
      final mobileRoot = [
        Destination.home,
        Destination.search,
        Destination.library,
      ].contains(location.destination);
      final compactLibrary = _compactLibrary || (!mobile && width < 1040);
      final forcedCompact = !mobile && width < 1040;
      final tokens = Theme.of(context).extension<KiyoraColors>()!;
      final player = PlayerBar(
        backend: b,
        mobile: mobile,
        openPlayer: _openPlayer,
        openQueue: () => _openPanel(ContextPanel.queue),
        openLyrics: () => _openPanel(ContextPanel.lyrics),
      );
      final content = PageStorage(
        bucket: _storage,
        child: _content(location, mobile: mobile),
      );
      return PopScope(
        canPop: !_navigation.canBack,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navigation.back();
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (HardwareKeyboard.instance.isControlPressed &&
                event.logicalKey == LogicalKeyboardKey.keyK) {
              if (mobile) {
                _selectMobileTab(1, focusSearch: true);
              } else {
                _go(Destination.search);
                _searchFocus.requestFocus();
              }
              return KeyEventResult.handled;
            }
            if (HardwareKeyboard.instance.isAltPressed &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _navigation.back();
              return KeyEventResult.handled;
            }
            if (HardwareKeyboard.instance.isAltPressed &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _navigation.forward();
              return KeyEventResult.handled;
            }
            if (FocusManager.instance.primaryFocus?.context
                    ?.findAncestorStateOfType<EditableTextState>() !=
                null)
              return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.space) {
              if (!b.busy) b.togglePlayback();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            appBar: mobile
                ? AppBar(
                    automaticallyImplyLeading: false,
                    leading: !mobileRoot && _navigation.canBack
                        ? BackButton(onPressed: _navigation.back)
                        : null,
                    title: Text(
                      _mobileTitle(location),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    bottom: location.destination == Destination.search
                        ? PreferredSize(
                            preferredSize: const Size.fromHeight(68),
                            child: _mobileSearchField(),
                          )
                        : null,
                    actions: [
                      ProfileMenuButton(
                        backend: b,
                        showName: width >= 430,
                        onSettings: () => _go(Destination.settings),
                        onLogin: _openLogin,
                      ),
                    ],
                  )
                : null,
            body: SafeArea(
              top: !mobile,
              bottom: !mobile || rail,
              child: mobile
                  ? Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (rail && !keyboard)
                                NavigationRail(
                                  selectedIndex: _mobileTab,
                                  onDestinationSelected: _selectMobileTab,
                                  labelType: short
                                      ? NavigationRailLabelType.none
                                      : NavigationRailLabelType.all,
                                  backgroundColor: tokens.canvas,
                                  destinations: const [
                                    NavigationRailDestination(
                                      icon: Icon(Icons.home_outlined),
                                      selectedIcon: Icon(Icons.home),
                                      label: Text('Главная'),
                                    ),
                                    NavigationRailDestination(
                                      icon: Icon(Icons.search),
                                      label: Text('Поиск'),
                                    ),
                                    NavigationRailDestination(
                                      icon: Icon(Icons.library_music_outlined),
                                      selectedIcon: Icon(Icons.library_music),
                                      label: Text('Медиатека'),
                                    ),
                                  ],
                                ),
                              Expanded(child: content),
                            ],
                          ),
                        ),
                        if (!keyboard) player,
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 64,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                if (width >= 900)
                                  const SizedBox(
                                    width: 130,
                                    child: Text(
                                      'KIYORA',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'Назад',
                                  onPressed: _navigation.canBack
                                      ? _navigation.back
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                IconButton(
                                  tooltip: 'Вперёд',
                                  onPressed: _navigation.canForward
                                      ? _navigation.forward
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                                IconButton(
                                  tooltip: 'Главная',
                                  onPressed: () => _go(Destination.home),
                                  icon: const Icon(Icons.home_rounded),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 520,
                                      ),
                                      child: TextField(
                                        controller: _search,
                                        focusNode: _searchFocus,
                                        decoration: const InputDecoration(
                                          prefixIcon: Icon(Icons.search),
                                          hintText: 'Что хотите послушать?',
                                          isDense: true,
                                        ),
                                        onChanged: (value) =>
                                            _changeSearch(value, mobile: false),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ProfileMenuButton(
                                  backend: b,
                                  showName: width >= 900,
                                  onSettings: () => _go(Destination.settings),
                                  onLogin: _openLogin,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final right =
                                    _panel != null && c.maxWidth >= 1184;
                                final leftWidth = compactLibrary
                                    ? 72.0
                                    : _leftWidth.clamp(
                                        220.0,
                                        right
                                            ? c.maxWidth - _rightWidth - 480
                                            : c.maxWidth - 480,
                                      );
                                return Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: leftWidth,
                                      child: Material(
                                        color: tokens.panel,
                                        borderRadius: BorderRadius.circular(8),
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                IconButton(
                                                  tooltip: forcedCompact
                                                      ? 'Открыть медиатеку'
                                                      : compactLibrary
                                                      ? 'Раскрыть медиатеку'
                                                      : 'Свернуть медиатеку',
                                                  onPressed: forcedCompact
                                                      ? () => _go(
                                                          Destination.library,
                                                        )
                                                      : () => setState(
                                                          () => _compactLibrary =
                                                              !_compactLibrary,
                                                        ),
                                                  icon: const Icon(
                                                    Icons.library_music,
                                                  ),
                                                ),
                                                if (!compactLibrary) ...[
                                                  const Expanded(
                                                    child: Text(
                                                      'Моя медиатека',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Создать плейлист',
                                                    onPressed: () =>
                                                        createPlaylist(
                                                          context,
                                                          b,
                                                          _navigation,
                                                        ),
                                                    icon: const Icon(Icons.add),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (compactLibrary) ...[
                                              IconButton(
                                                tooltip: 'Медиатека',
                                                onPressed: () =>
                                                    _go(Destination.library),
                                                icon: const Icon(
                                                  Icons.music_note,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Любимые композиции',
                                                onPressed: () =>
                                                    _go(Destination.favorites),
                                                icon: const Icon(
                                                  Icons.favorite,
                                                ),
                                              ),
                                            ] else
                                              Expanded(
                                                child: LibraryView(
                                                  backend: b,
                                                  navigation: _navigation,
                                                  location: const MusicLocation(
                                                    Destination.library,
                                                  ),
                                                  initialFilter:
                                                      LibraryFilter.playlists,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _resize(
                                      (dx) => setState(
                                        () => _leftWidth = (_leftWidth + dx)
                                            .clamp(220, 420),
                                      ),
                                    ),
                                    Expanded(
                                      child: Material(
                                        color: tokens.panel,
                                        borderRadius: BorderRadius.circular(8),
                                        clipBehavior: Clip.antiAlias,
                                        child: content,
                                      ),
                                    ),
                                    if (right) ...[
                                      _resize(
                                        (dx) => setState(
                                          () => _rightWidth = (_rightWidth - dx)
                                              .clamp(280, 400),
                                        ),
                                      ),
                                      SizedBox(
                                        width: _rightWidth,
                                        child: Material(
                                          color: tokens.panel,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            children: [
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: IconButton(
                                                  tooltip: 'Закрыть панель',
                                                  onPressed: () => setState(
                                                    () => _panel = null,
                                                  ),
                                                  icon: const Icon(Icons.close),
                                                ),
                                              ),
                                              Expanded(
                                                child: _panelContent(_panel!),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        player,
                      ],
                    ),
            ),
            bottomNavigationBar: !mobile || rail || keyboard
                ? null
                : NavigationBar(
                    selectedIndex: _mobileTab,
                    onDestinationSelected: _selectMobileTab,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'Главная',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.search),
                        label: 'Поиск',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music),
                        label: 'Медиатека',
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
  Widget _resize(ValueChanged<double> change) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => change(d.delta.dx),
      child: const SizedBox(width: 8),
    ),
  );
}
