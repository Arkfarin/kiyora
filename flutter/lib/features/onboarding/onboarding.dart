import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/bridge/generated/api/auth.dart' as auth;
import '../../core/bridge/generated/api/vault.dart' as vault;
import '../../core/state/backend_controller.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.backend});
  final BackendController backend;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _name = TextEditingController();
  final _apiId = TextEditingController();
  final _apiHash = TextEditingController();
  final _input = TextEditingController();
  List<vault.Candidate>? _candidates;
  Type? _lastAuth;
  String? _lastSession;
  BackendController get b => widget.backend;

  @override
  void dispose() {
    for (final c in [_name, _apiId, _apiHash, _input]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: b,
    builder: (context, _) {
      if (_lastSession != b.session?.sessionId) {
        _lastSession = b.session?.sessionId;
        _candidates = null;
        _input.clear();
      }
      if (_lastAuth != b.authorization.runtimeType) {
        _lastAuth = b.authorization.runtimeType;
        _input.clear();
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              Text(
                'KIYORA',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 40),
              if (b.starting) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Открываем вашу музыку…'),
              ] else
                ..._step(context),
              if (b.busy) ...[
                const SizedBox(height: 20),
                const LinearProgressIndicator(),
                TextButton(onPressed: b.cancel, child: const Text('Отменить')),
              ],
              if (b.error != null) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    b.error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                if (b.session == null)
                  TextButton(
                    onPressed: b.busy ? null : () => b.start(),
                    child: const Text('Повторить'),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );

  List<Widget> _step(BuildContext context) {
    if (b.session == null)
      return [
        _heading('Ваша музыка. Всегда рядом.'),
        const Text('Создайте профиль или откройте существующую коллекцию.'),
        const SizedBox(height: 24),
        for (final profile in b.profiles)
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(profile.label),
            onTap: b.busy ? null : () => b.chooseProfile(profile.id),
          ),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Название профиля'),
          onSubmitted: (_) => _createProfile(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: b.busy ? null : _createProfile,
          child: const Text('Создать профиль'),
        ),
      ];
    final authorization = b.authorization;
    if (authorization == null ||
        authorization is auth.Authorization_ParametersRequired ||
        authorization is auth.Authorization_Closed) {
      return [
        _heading('Подключите хранилище'),
        const Text(
          'Музыка хранится в вашем Telegram. Параметры приложения нужны для входа; они сохраняются средствами защиты устройства.',
        ),
        const SizedBox(height: 20),
        if (b.details?.apiConfigured == true) ...[
          FilledButton(
            onPressed: b.busy ? null : b.reconnect,
            child: const Text('Продолжить вход'),
          ),
          const SizedBox(height: 24),
        ],
        const SelectableText(
          'Получите API ID и API hash в разделе API development tools на my.telegram.org.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _apiId,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'API ID'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiHash,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'API hash'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: b.busy
              ? null
              : () async {
                  final id = int.tryParse(_apiId.text.trim());
                  if (id == null || id <= 0 || _apiHash.text.trim().isEmpty)
                    return;
                  final hash = _apiHash.text.trim();
                  _apiHash.clear();
                  await b.connect(id, hash);
                },
          child: const Text('Подключить Telegram'),
        ),
      ];
    }
    if (authorization is auth.Authorization_Ready)
      return [
        _heading('Откройте свою коллекцию'),
        const Text('Восстановите библиотеку из Telegram или создайте новую.'),
        const SizedBox(height: 24),
        if (b.details?.creation?.chatId case final String chatId)
          FilledButton(
            onPressed: b.busy
                ? null
                : () => b.operate((op) async {
                    await vault.resumeCreation(
                      sessionId: b.sessionId,
                      chatId: chatId,
                      operation: op,
                    );
                    // Runtime events update the attached Vault without creating a session.
                  }),
            child: const Text('Продолжить создание библиотеки'),
          ),
        OutlinedButton(
          onPressed: b.busy
              ? null
              : () => b.operate((op) async {
                  final candidates = await vault.discover(
                    sessionId: b.sessionId,
                    operation: op,
                  );
                  if (mounted) setState(() => _candidates = candidates);
                }),
          child: const Text('Найти мою библиотеку'),
        ),
        if (_candidates != null && _candidates!.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Библиотеки в этом аккаунте не найдены.'),
          ),
        for (final candidate in _candidates ?? <vault.Candidate>[])
          ListTile(
            title: Text(candidate.title),
            leading: const Icon(Icons.library_music_outlined),
            onTap: b.busy
                ? null
                : () => b.operate((op) async {
                    await vault.attach(
                      sessionId: b.sessionId,
                      chatId: candidate.chatId,
                      operation: op,
                    );
                  }),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Название новой библиотеки',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: b.busy
              ? null
              : () => b.operate((op) async {
                  await vault.create(
                    sessionId: b.sessionId,
                    title: _name.text.trim().isEmpty ? null : _name.text.trim(),
                    operation: op,
                  );
                }),
          child: const Text('Создать библиотеку'),
        ),
      ];
    if (authorization is auth.Authorization_QrConfirmation)
      return [
        _heading('Подтвердите вход'),
        const Text(
          'В Telegram откройте Настройки → Устройства → Подключить устройство.',
        ),
        const SizedBox(height: 24),
        Center(
          child: ColoredBox(
            color: Colors.white,
            child: QrImageView(
              data: authorization.link,
              size: 240,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: b.busy ? null : () => b.login(const auth.Login.qr()),
          child: const Text('Обновить QR-код'),
        ),
      ];
    final (title, label, secret, keyboard) = switch (authorization) {
      auth.Authorization_PhoneRequired() => (
        'Вход в Telegram',
        'Номер телефона',
        false,
        TextInputType.phone,
      ),
      auth.Authorization_CodeRequired() => (
        'Проверьте Telegram',
        'Код подтверждения',
        true,
        TextInputType.number,
      ),
      auth.Authorization_PasswordRequired() => (
        'Двухэтапная защита',
        'Пароль Telegram',
        true,
        TextInputType.visiblePassword,
      ),
      auth.Authorization_EmailRequired() => (
        'Подтвердите почту',
        'Электронная почта',
        false,
        TextInputType.emailAddress,
      ),
      auth.Authorization_EmailCodeRequired() => (
        'Проверьте почту',
        'Код из письма',
        true,
        TextInputType.number,
      ),
      _ => ('Вход пока недоступен', '', false, TextInputType.text),
    };
    if (label.isEmpty)
      return [
        _heading(title),
        Text(switch (authorization) {
          auth.Authorization_RegistrationRequired() =>
            'Сначала завершите регистрацию в официальном приложении Telegram.',
          auth.Authorization_PremiumRequired() =>
            'Telegram требует Premium для этого способа входа. Завершите вход в официальном приложении.',
          auth.Authorization_LoggingOut() ||
          auth.Authorization_Closing() => 'Завершаем сеанс…',
          _ =>
            'Этот шаг авторизации пока не поддерживается. Попробуйте подключиться снова.',
        }),
        TextButton(
          onPressed: b.busy ? null : b.reconnect,
          child: const Text('Подключиться снова'),
        ),
      ];
    return [
      _heading(title),
      if (authorization is auth.Authorization_CodeRequired)
        Text('Способ доставки: ${authorization.delivery}'),
      const SizedBox(height: 20),
      TextField(
        controller: _input,
        obscureText: secret,
        keyboardType: keyboard,
        enableSuggestions: !secret,
        autocorrect: false,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => _submit(authorization),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: b.busy ? null : () => _submit(authorization),
        child: const Text('Продолжить'),
      ),
      if (authorization is auth.Authorization_PhoneRequired)
        TextButton(
          onPressed: b.busy ? null : () => b.login(const auth.Login.qr()),
          child: const Text('Войти по QR-коду'),
        ),
      if (authorization is auth.Authorization_CodeRequired &&
          authorization.nextDelivery != null)
        TextButton(
          onPressed: b.busy
              ? null
              : () => b.login(const auth.Login.resendCode()),
          child: const Text('Отправить код повторно'),
        ),
    ];
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
  void _createProfile() {
    if (_name.text.trim().isNotEmpty) b.createProfile(_name.text);
  }

  void _submit(auth.Authorization state) {
    if (_input.text.isEmpty) return;
    final input = switch (state) {
      auth.Authorization_PhoneRequired() => auth.Login.phone(
        _input.text.trim(),
      ),
      auth.Authorization_CodeRequired() => auth.Login.code(_input.text.trim()),
      auth.Authorization_PasswordRequired() => auth.Login.password(_input.text),
      auth.Authorization_EmailRequired() => auth.Login.email(
        _input.text.trim(),
      ),
      auth.Authorization_EmailCodeRequired() => auth.Login.emailCode(
        _input.text.trim(),
      ),
      _ => null,
    };
    _input.clear();
    if (input != null) b.login(input);
  }
}
