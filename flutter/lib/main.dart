import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'app/music_shell.dart';
import 'core/bridge/generated/frb_generated.dart';
import 'core/bridge/generated/api.dart' as api;
import 'core/state/backend_controller.dart';
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
        try {
          await widget.backend.close();
          return AppExitResponse.exit;
        } catch (e) {
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
      final window = Platform.isWindows
          ? await _host.invokeMethod<int>('windowHandle')
          : null;
      await widget.backend.start(
        resources: root,
        windowHandle: window == null ? null : BigInt.from(window),
      );
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

  @override
  void dispose() {
    _raiseTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'KIYORA',
    debugShowCheckedModeBanner: false,
    theme: kiyoraTheme(Brightness.light),
    darkTheme: kiyoraTheme(Brightness.dark),
    themeMode: _theme,
    home: _loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _startupError != null
        ? Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
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
          )
        : ListenableBuilder(
            listenable: widget.backend,
            builder: (context, _) => widget.backend.hasLibrary
                ? MusicShell(
                    key: ValueKey(widget.backend.session?.sessionId),
                    backend: widget.backend,
                    themeMode: _theme,
                    onThemeChanged: (mode) => setState(() => _theme = mode),
                  )
                : Scaffold(
                    body: SafeArea(child: Onboarding(backend: widget.backend)),
                  ),
          ),
  );
}
