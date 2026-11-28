import 'package:material_ui/material_ui.dart';

import '../../core/bridge/generated/api/auth.dart' as auth;
import '../../core/state/backend_controller.dart';

/// A single place to find account switching, a new local profile and logout.
/// This also works before a Telegram library has been attached.
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({
    super.key,
    required this.backend,
    this.showName = true,
    this.onSettings,
    this.onLogin,
  });

  final BackendController backend;
  final bool showName;
  final VoidCallback? onSettings;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: backend,
    builder: (context, _) {
      final selected = backend.session?.profileId;
      final current = [
        for (final profile in backend.profiles)
          if (profile.id == selected) profile.label,
      ];
      final name = current.isEmpty ? 'Профиль' : current.first;
      return PopupMenuButton<String>(
        enabled: !backend.busy,
        tooltip: 'Сменить профиль или выйти',
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(minWidth: 300, maxWidth: 360),
        onSelected: (value) async {
          if (value == 'create') {
            await showCreateProfileDialog(context, backend);
          } else if (value == 'logout') {
            await confirmTelegramLogout(context, backend);
          } else if (value == 'settings') {
            onSettings?.call();
          } else if (value == 'login') {
            onLogin?.call();
          } else if (value.startsWith('profile:')) {
            await backend.chooseProfile(value.substring('profile:'.length));
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('Сменить профиль'),
          ),
          for (final profile in backend.profiles)
            PopupMenuItem<String>(
              value: 'profile:${profile.id}',
              enabled: !backend.busy && profile.id != selected,
              child: Row(
                children: [
                  Icon(
                    profile.id == selected
                        ? Icons.check_circle
                        : Icons.account_circle_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(profile.label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          if (backend.profiles.isNotEmpty) const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'create',
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1_outlined, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Добавить профиль',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (onSettings != null)
            const PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Настройки', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          if (onLogin != null &&
              backend.hasLibrary &&
              backend.authorization is! auth.Authorization_Ready)
            const PopupMenuItem<String>(
              value: 'login',
              child: Row(
                children: [
                  Icon(Icons.login, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('Войти в Telegram')),
                ],
              ),
            ),
          if (backend.session != null) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Выйти из Telegram',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_outlined, size: 28),
              if (showName) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 136),
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
              ],
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showCreateProfileDialog(
  BuildContext context,
  BackendController backend,
) async {
  var label = '';
  final name = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, rebuild) => AlertDialog(
        title: const Text('Добавить профиль'),
        content: TextField(
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Название профиля'),
          onChanged: (value) => rebuild(() => label = value),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: label.trim().isEmpty
                ? null
                : () => Navigator.pop(context, label.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    ),
  );
  if (name != null && name.isNotEmpty && !backend.busy) {
    await backend.createProfile(name);
  }
}

Future<void> confirmTelegramLogout(
  BuildContext context,
  BackendController backend,
) async {
  if (backend.busy || backend.session == null) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Выйти из Telegram?'),
      content: const Text(
        'Вход в Telegram будет завершён для текущего профиля. '
        'Локальная медиатека и другие профили сохранятся. '
        'Для синхронизации потребуется войти снова.',
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
  if (confirmed == true && !backend.busy) await backend.logoutTelegram();
}
