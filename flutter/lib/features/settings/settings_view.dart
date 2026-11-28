import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/bridge/generated/api/auth.dart' as auth;
import '../../core/bridge/generated/api/offline.dart' as offline;
import '../../core/state/backend_controller.dart';
import 'profile_menu.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.backend,
    required this.themeMode,
    required this.onThemeChanged,
    this.onLogin,
  });
  final BackendController backend;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback? onLogin;
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  offline.Cache? _cache;
  String? _cacheSession;
  BackendController get b => widget.backend;
  Future<void> _loadCache({BigInt? quota}) => b.operate((op) async {
    final session = b.sessionId;
    final cache = await offline.cache(
      sessionId: session,
      quotaBytes: quota,
      operation: op,
    );
    if (mounted && b.session?.sessionId == session) {
      setState(() {
        _cache = cache;
        _cacheSession = session;
      });
    }
  });

  Future<void> _chooseQuota() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Размер кэша'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Уменьшение лимита может удалить незакреплённые файлы. Закреплённая музыка сохранится.',
            ),
          ),
          for (final gib in [1, 2, 5, 10, 20, 50])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, gib),
              child: Text('$gib ГиБ'),
            ),
        ],
      ),
    );
    if (selected != null && mounted && !b.busy) {
      await _loadCache(quota: BigInt.from(selected * 1024 * 1024 * 1024));
    }
  }

  Future<void> _openProject() async {
    const url = 'https://github.com/Arkfarin/kiyora';
    try {
      if (Platform.isAndroid) {
        await const MethodChannel('io.github.arkfarin.kiyora/host')
            .invokeMethod<void>('openProjectPage');
        return;
      }
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [url]);
        if (result.exitCode == 0) return;
      }
    } catch (_) {
      // The repository is still accessible when a browser is unavailable.
    }
    await Clipboard.setData(const ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: b,
    builder: (context, _) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Настройки',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 28),
            _title('Аккаунт'),
            Text(
              'Выберите профиль или создайте новый. Медиатеки каждого профиля сохраняются отдельно.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: b.session?.profileId,
              onChanged: (id) {
                if (!b.busy && id != null) b.chooseProfile(id);
              },
              child: Column(
                children: [
                  for (final profile in b.profiles)
                    RadioListTile<String>(
                      value: profile.id,
                      title: Text(profile.label),
                      enabled: !b.busy,
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Добавить профиль'),
              onTap: b.busy ? null : () => showCreateProfileDialog(context, b),
            ),
            ListTile(
              title: const Text('Подключиться снова'),
              subtitle: Text(b.details?.connection ?? ''),
              trailing: const Icon(Icons.refresh),
              onTap: b.busy ? null : b.reconnect,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Выйти из Telegram'),
              subtitle: const Text(
                'Локальная медиатека останется на устройстве',
              ),
              onTap: b.busy ? null : () => confirmTelegramLogout(context, b),
            ),
            if (widget.onLogin != null &&
                b.hasLibrary &&
                b.authorization is! auth.Authorization_Ready)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Войти в Telegram'),
                subtitle: const Text('Для синхронизации музыки'),
                onTap: b.busy ? null : widget.onLogin,
              ),
            const SizedBox(height: 28),
            _title('Оформление'),
            DropdownButtonFormField<ThemeMode>(
              initialValue: widget.themeMode,
              decoration: const InputDecoration(labelText: 'Тема'),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Как в системе'),
                ),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Тёмная')),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Светлая'),
                ),
              ],
              onChanged: (value) {
                if (value != null) widget.onThemeChanged(value);
              },
            ),
            const SizedBox(height: 28),
            _title('Хранилище и загрузки'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Локальный кэш'),
              subtitle: Text(
                _cache == null || _cacheSession != b.session?.sessionId
                    ? 'Доступность музыки офлайн зависит от скачанных файлов.'
                    : '${_fileSize(_cache!.usedBytes)} из ${_fileSize(_cache!.quotaBytes)}',
              ),
              trailing: IconButton(
                tooltip: 'Обновить размер кэша',
                onPressed: b.busy ? null : _loadCache,
                icon: const Icon(Icons.refresh),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Изменить лимит кэша'),
              onTap: b.busy || !b.hasLibrary ? null : _chooseQuota,
            ),
            TextButton(
              onPressed: b.busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Очистить незакреплённый кэш?'),
                          content: const Text(
                            'Эти файлы понадобится скачать снова. Закреплённая музыка и файлы в Telegram сохранятся.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Очистить'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await b.operate((op) async {
                          await offline.clearUnpinned(
                            sessionId: b.sessionId,
                            operation: op,
                          );
                        });
                        await _loadCache();
                      }
                    },
              child: const Text('Очистить незакреплённые файлы'),
            ),
            const SizedBox(height: 28),
            _title('Синхронизация'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Синхронизировать библиотеку'),
              subtitle: Text(
                b.runtime?.mode.name ??
                    'Статус подключения доступен после входа',
              ),
              trailing: const Icon(Icons.sync),
              onTap: b.busy ? null : b.synchronize,
            ),
            const SizedBox(height: 28),
            _title('О приложении'),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('KIYORA'),
              subtitle: Text('Ваша музыка в Telegram. Автор: arkfarin.'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code),
              title: const Text('GitHub'),
              subtitle: const Text('Arkfarin/kiyora'),
              trailing: const Icon(Icons.open_in_new),
              onTap: _openProject,
            ),
            TextButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'KIYORA'),
              child: const Text('Лицензии'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _title(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

String _fileSize(BigInt size) {
  final value = size.toDouble();
  if (value < 1024) return '$size Б';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} КиБ';
  if (value < 1024 * 1024 * 1024)
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} МиБ';
  return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГиБ';
}
