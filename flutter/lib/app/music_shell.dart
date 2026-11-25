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
import '../features/player/player.dart';
import '../features/queue/queue_view.dart';
import '../features/settings/settings_view.dart';

enum ContextPanel { playing, queue, lyrics }

class MusicShell extends StatefulWidget {
  const MusicShell({
    super.key,
    required this.backend,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final BackendController backend;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<MusicShell> createState() => _MusicShellState();
}

class _MusicShellState extends State<MusicShell> {
  final _navigation = MusicNavigation();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _storage = PageStorageBucket();
  double _leftWidth = 280;
  double _rightWidth = 320;
  bool _compactLibrary = false;
  ContextPanel? _panel;
  Timer? _searchDelay;
  String _query = '';
  BackendController get b => widget.backend;
  late final ImportSelection _imports;
  @override
  void initState() {
    super.initState();
    _imports = ImportSelection(b);
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
  void dispose() {
    _searchDelay?.cancel();
    b.commandResults.removeListener(_command);
    b.removeListener(_error);
    _navigation.dispose();
    _imports.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openPanel(ContextPanel panel) {
    if (MediaQuery.sizeOf(context).width >= 1200) {
      setState(() => _panel = _panel == panel ? null : panel);
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
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
              ],
            ),
          ),
        ),
      );
    } else {
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
    if (defaultTargetPlatform == TargetPlatform.linux ||
        MediaQuery.sizeOf(context).width >= 1200) {
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
  Widget _content(MusicLocation location) {
    final key = ValueKey(
      '${location.destination}:${location.id}:${location.title}',
    );
    return switch (location.destination) {
      Destination.home => HomeView(
        key: key,
        backend: b,
        navigation: _navigation,
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
      ),
      _ => LibraryView(
        key: key,
        backend: b,
        navigation: _navigation,
        location: location,
        search: location.destination == Destination.search ? _query : '',
      ),
    };
  }

  void _go(Destination destination) =>
      _navigation.go(MusicLocation(destination));
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _navigation,
    builder: (context, _) {
      final location = _navigation.current;
      final width = MediaQuery.sizeOf(context).width;
      final mobile =
          defaultTargetPlatform != TargetPlatform.linux && width < 900;
      final compactLibrary = _compactLibrary || (!mobile && width < 1040);
      final tokens = Theme.of(context).extension<KiyoraColors>()!;
      final player = PlayerBar(
        backend: b,
        mobile: mobile,
        openPlayer: _openPlayer,
        openQueue: () => _openPanel(ContextPanel.queue),
        openLyrics: () => _openPanel(ContextPanel.lyrics),
      );
      final content = PageStorage(bucket: _storage, child: _content(location));
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
              _go(Destination.search);
              _searchFocus.requestFocus();
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
              b.togglePlayback();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            appBar: mobile
                ? AppBar(
                    leading: _navigation.canBack
                        ? BackButton(onPressed: _navigation.back)
                        : IconButton(
                            tooltip: 'Аккаунт и настройки',
                            onPressed: () => _go(Destination.settings),
                            icon: const Icon(Icons.account_circle_outlined),
                          ),
                    title: const Text(
                      'KIYORA',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Настройки',
                        onPressed: () => _go(Destination.settings),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  )
                : null,
            body: SafeArea(
              top: !mobile,
              bottom: !mobile,
              child: mobile
                  ? Column(
                      children: [
                        Expanded(child: content),
                        player,
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
                                        onChanged: (value) {
                                          _searchDelay?.cancel();
                                          _searchDelay = Timer(
                                            const Duration(milliseconds: 220),
                                            () {
                                              setState(() => _query = value);
                                              if (_navigation
                                                      .current
                                                      .destination !=
                                                  Destination.search)
                                                _go(Destination.search);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  tooltip: 'Аккаунт и настройки',
                                  onPressed: () => _go(Destination.settings),
                                  icon: const Icon(
                                    Icons.account_circle_outlined,
                                  ),
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
                                                  tooltip: compactLibrary
                                                      ? 'Раскрыть медиатеку'
                                                      : 'Свернуть медиатеку',
                                                  onPressed: () => setState(
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
            bottomNavigationBar: !mobile
                ? null
                : NavigationBar(
                    selectedIndex: switch (location.destination) {
                      Destination.home => 0,
                      Destination.search => 1,
                      _ => 2,
                    },
                    onDestinationSelected: (i) => _go(
                      [
                        Destination.home,
                        Destination.search,
                        Destination.library,
                      ][i],
                    ),
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
