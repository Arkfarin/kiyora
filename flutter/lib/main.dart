import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'app/music_shell.dart';
import 'core/bridge/generated/frb_generated.dart';
import 'core/bridge/generated/api.dart' as api;
import 'core/state/backend_controller.dart';
import 'core/state/ui_preferences.dart';
import 'core/theme/kiyora_theme.dart';
import 'features/onboarding/onboarding.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The owner outlives routes and widget rebuilding. Android Activity teardown
  // must not call Backend::shutdown; native playback owns that lifetime.
  runApp(KiyoraApp(backend: BackendController()));
}

class KiyoraApp extends StatefulWidget {
  const KiyoraApp({super.key, required this.backend});
  final BackendController backend;
  @override
  State<KiyoraApp> createState() => _KiyoraAppState();
}

class _KiyoraAppState extends State<KiyoraApp> {
  static const _host = MethodChannel('io.github.arkfarin.kiyora/host');
  ThemeMode _theme = ThemeMode.system;
  UiPreferencesStore? _preferences;
  Future<void>? _loadingPreferences;
  bool _exiting = false;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _loading = true;
  bool _bridgeReady = false;
  Object? _startupError;
  late final AppLifecycleListener _lifecycle;
  Timer? _raiseTimer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        if (Platform.isAndroid) return AppExitResponse.exit;
        _exiting = true;
        if (Platform.isLinux) {
          try {
            await _loadingPreferences;
            final window = await _host.invokeMapMethod<String, dynamic>(
              'windowState',
            );
            if (window != null) await _preferences?.setWindow(window);
          } catch (_) {
            // Saving presentation settings must never strand a closing player.
            debugPrint('KIYORA: unable to save window preferences');
          }
          try {
            await _preferences?.flush();
          } catch (_) {
            debugPrint('KIYORA: unable to finish saving interface preferences');
          }
        }
        try {
          await widget.backend.close();
          return AppExitResponse.exit;
        } catch (e) {
          _exiting = false;
          if (mounted) setState(() => _startupError = e);
          return AppExitResponse.cancel;
        }
      },
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _startupError = null;
    });
    try {
      if (Platform.isLinux || Platform.isAndroid) {
        await (_loadingPreferences ??= _loadPreferences());
      }
      if (_exiting || !mounted) return;
      final root = File(Platform.resolvedExecutable).parent.path;
      if (!_bridgeReady) {
        final library =
            Platform.environment['KIYORA_NATIVE_LIBRARY'] ??
            (Platform.isWindows
                ? '$root/kiyora_flutter_bridge.dll'
                : Platform.isAndroid
                ? 'libkiyora_flutter_bridge.so'
                : '$root/lib/libkiyora_flutter_bridge.so');
        await RustLib.init(externalLibrary: ExternalLibrary.open(library));
        _bridgeReady = true;
      }
      if (_exiting || !mounted) return;
      final window = Platform.isWindows
          ? await _host.invokeMethod<int>('windowHandle')
          : null;
      await widget.backend.start(
        resources: root,
        windowHandle: window == null ? null : BigInt.from(window),
      );
      if (_exiting || !mounted) return;
      if (!Platform.isAndroid) {
        _raiseTimer ??= Timer.periodic(const Duration(milliseconds: 500), (
          _,
        ) async {
          try {
            if (await api.takeWindowRaiseRequest())
              await _host.invokeMethod<void>('raise');
          } catch (e) {
            // A failed host integration is visible, rather than an unhandled
            // periodic callback or a silent media-key failure.
            _raiseTimer?.cancel();
            await widget.backend.action(() async {
              throw e;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _startupError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      if (Platform.isAndroid) {
        final directory = await _host.invokeMethod<String>(
          'preferencesDirectory',
        );
        if (directory == null || directory.isEmpty) {
          throw const FileSystemException(
            'Configuration directory unavailable',
          );
        }
        _preferences = UiPreferencesStore(
          File('$directory/ui-preferences.json'),
        );
      } else {
        _preferences = UiPreferencesStore.linux();
      }
      await _preferences!.load();
      _theme = ThemeMode.values.byName(_preferences!.value.theme);
    } catch (_) {
      _reportPreferencesError('Не удалось восстановить настройки интерфейса.');
    }
    // The Linux runner maps its first frame after receiving geometry, including
    // defaults when reading the settings failed. This avoids a Wayland resize
    // racing the initial surface configure.
    if (Platform.isLinux && !_exiting && mounted) {
      try {
        await _host.invokeMethod<void>(
          'restoreWindow',
          (_preferences?.value ?? const UiPreferences()).toJson(),
        );
      } catch (_) {
        _reportPreferencesError('Не удалось восстановить размер окна.');
      }
    }
  }

  @override
  void dispose() {
    _raiseTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _reportPreferencesError(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messenger.currentState?.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    setState(() => _theme = mode);
    if (!Platform.isLinux && !Platform.isAndroid) return;
    try {
      if (_preferences == null) {
        await _loadPreferences();
        // Restore may update _theme; the user's explicit choice wins.
        if (mounted) setState(() => _theme = mode);
      }
      if (_preferences == null) {
        throw const FileSystemException('Configuration directory unavailable');
      }
      await _preferences!.setTheme(mode.name);
    } catch (_) {
      _reportPreferencesError(
        'Не удалось сохранить тему. Проверьте доступ к папке настроек.',
      );
    }
  }

  Future<void> _changeSearchHistory(
    String profileId,
    List<String> queries,
  ) async {
    try {
      await _preferences?.setSearchHistory(profileId, queries);
    } catch (_) {
      _reportPreferencesError('Не удалось сохранить историю поиска.');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: _messenger,
    title: 'KIYORA',
    debugShowCheckedModeBanner: false,
    theme: kiyoraTheme(Brightness.light),
    darkTheme: kiyoraTheme(Brightness.dark),
    themeMode: _theme,
    home: _loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _startupError != null
        ? Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Не удалось открыть KIYORA',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SelectableText(_startupError.toString()),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _initialize,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : ListenableBuilder(
            listenable: widget.backend,
            builder: (context, _) {
              final profileId = widget.backend.session?.profileId;
              return widget.backend.hasLibrary
                  ? MusicShell(
                      key: ValueKey(widget.backend.session?.sessionId),
                      backend: widget.backend,
                      themeMode: _theme,
                      onThemeChanged: _changeTheme,
                      searchHistory:
                          _preferences?.value.searchHistory[profileId] ??
                          const [],
                      onSearchHistoryChanged: (queries) {
                        if (profileId != null)
                          unawaited(_changeSearchHistory(profileId, queries));
                      },
                    )
                  : Scaffold(
                      body: SafeArea(
                        child: Onboarding(backend: widget.backend),
                      ),
                    );
            },
          ),
  );
}
