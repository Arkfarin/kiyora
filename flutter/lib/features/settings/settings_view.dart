import 'package:material_ui/material_ui.dart';

import '../../core/bridge/generated/api/auth.dart' as auth;
import '../../core/bridge/generated/api/offline.dart' as offline;
import '../../core/state/backend_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.backend,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final BackendController backend;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  offline.Cache? _cache;
  BackendController get b => widget.backend;
  Future<void> _loadCache() => b.operate((op) async {
    final cache = await offline.cache(
      sessionId: b.sessionId,
      quotaBytes: null,
      operation: op,
    );
    if (mounted) setState(() => _cache = cache);
  });
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
              title: const Text('Подключиться снова'),
              subtitle: Text(b.details?.connection ?? ''),
              trailing: const Icon(Icons.refresh),
              onTap: b.busy ? null : b.reconnect,
            ),
            ListTile(
              title: const Text('Выйти из Telegram'),
              onTap: b.busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Выйти из Telegram?'),
                          content: const Text(
                            'Для синхронизации потребуется снова войти в аккаунт.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Выйти'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await b.action(() async {
                          await auth.logout(sessionId: b.sessionId);
                        });
                        await b.refresh();
                      }
                    },
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
                _cache == null
                    ? 'Доступность музыки офлайн зависит от скачанных файлов.'
                    : '${_fileSize(_cache!.usedBytes)} из ${_fileSize(_cache!.quotaBytes)}',
              ),
              trailing: IconButton(
                tooltip: 'Обновить размер кэша',
                onPressed: b.busy ? null : _loadCache,
                icon: const Icon(Icons.refresh),
              ),
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
              subtitle: Text(
                'Ваша музыка в Telegram. Воспроизведение и хранение работают на Rust.',
              ),
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
