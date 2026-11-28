import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/bridge/generated/api/auth.dart' as auth;
import '../../core/bridge/generated/api/vault.dart' as vault;
import '../../core/state/backend_controller.dart';
import '../settings/profile_menu.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.backend, this.onConnected});
  final BackendController backend;
  final VoidCallback? onConnected;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _profileName = TextEditingController();
  final _libraryName = TextEditingController();
  final _input = TextEditingController();
  List<vault.Candidate>? _candidates;
  Type? _lastAuth;
  bool _editingPhone = false;
  String? _lastSession;
  BackendController get b => widget.backend;

  @override
  void dispose() {
    for (final c in [_profileName, _libraryName, _input]) {
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
        _editingPhone = false;
        _input.clear();
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'KIYORA',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  ProfileMenuButton(backend: b, showName: false),
                ],
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
                if (b.canCancel)
                  TextButton(
                    onPressed: b.cancel,
                    child: const Text('Отменить'),
                  ),
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
          controller: _profileName,
          decoration: const InputDecoration(labelText: 'Название профиля'),
          onSubmitted: (_) => _createProfile(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: b.busy ? null : _createProfile,
          child: const Text('Создать профиль'),
        ),
      ];
    final actualAuthorization = b.authorization;
    final authorization = _editingPhone
        ? const auth.Authorization.phoneRequired()
        : actualAuthorization;
    if (authorization == null ||
        authorization is auth.Authorization_ParametersRequired ||
        authorization is auth.Authorization_Closed) {
      return [
        _heading('Ваша музыка в Telegram'),
        const Text('Войдите в свой аккаунт, чтобы открыть коллекцию.'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: b.busy ? null : b.connect,
          child: const Text('Войти в Telegram'),
        ),
      ];
    }
    if (authorization is auth.Authorization_Ready && b.hasLibrary) {
      return [
        _heading('Telegram подключён'),
        const Text('Ваш профиль снова готов к синхронизации.'),
        const SizedBox(height: 24),
        if (widget.onConnected != null)
          FilledButton(
            onPressed: widget.onConnected,
            child: const Text('Вернуться к медиатеке'),
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
          controller: _libraryName,
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
                    title: _libraryName.text.trim().isEmpty
                        ? null
                        : _libraryName.text.trim(),
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
            child: LayoutBuilder(
              builder: (context, constraints) => QrImageView(
                data: authorization.link,
                size: math.min(
                  240,
                  math.min(
                    constraints.maxWidth,
                    MediaQuery.sizeOf(context).height * .3,
                  ),
                ),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'QR-код обновляется автоматически.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: b.busy ? null : b.restartLogin,
          icon: const Icon(Icons.phone_outlined),
          label: const Text('Войти по номеру телефона'),
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
        _codeTitle(authorization.delivery),
        'Код подтверждения',
        false,
        authorization.delivery == 'SmsWord' ||
                authorization.delivery == 'SmsPhrase'
            ? TextInputType.text
            : TextInputType.number,
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
        false,
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
          auth.Authorization_PremiumRequired() => 'Telegram требует Premium для этого способа входа. Завершите вход в официальном приложении.',
          auth.Authorization_LoggingOut() ||
          auth.Authorization_Closing() => 'Завершаем сеанс…',
          _ => 'Этот шаг авторизации пока не поддерживается. Попробуйте подключиться снова.',
        }),
        TextButton(
          onPressed: b.busy ? null : b.reconnect,
          child: const Text('Подключиться снова'),
        ),
      ];
    return [
      _heading(title),
      if (authorization is auth.Authorization_CodeRequired)
        Text(_codeHelp(authorization.delivery)),
      const SizedBox(height: 20),
      TextField(
        controller: _input,
        obscureText: secret,
        keyboardType: keyboard,
        enableSuggestions: !secret,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: label,
          helperText: authorization is auth.Authorization_PhoneRequired
              ? 'С кодом страны, например +996…'
              : null,
        ),
        onSubmitted: (_) => _submit(authorization),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: b.busy ? null : () => _submit(authorization),
        child: const Text('Продолжить'),
      ),
      if (authorization is auth.Authorization_PhoneRequired ||
          authorization is auth.Authorization_CodeRequired ||
          authorization is auth.Authorization_PasswordRequired ||
          authorization is auth.Authorization_EmailRequired ||
          authorization is auth.Authorization_EmailCodeRequired) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: b.busy ? null : () => b.login(const auth.Login.qr()),
          icon: const Icon(Icons.qr_code),
          label: const Text('Войти по QR-коду'),
        ),
      ],
      if (authorization is auth.Authorization_CodeRequired)
        _ResendCodeButton(backend: b, authorization: authorization),
      if (authorization is auth.Authorization_EmailCodeRequired) ...[
        const SizedBox(height: 12),
        TextButton(
          onPressed: b.busy
              ? null
              : () => b.login(const auth.Login.resendCode()),
          child: const Text('Отправить письмо повторно'),
        ),
      ],
      if (authorization is auth.Authorization_CodeRequired ||
          authorization is auth.Authorization_PasswordRequired ||
          authorization is auth.Authorization_EmailRequired ||
          authorization is auth.Authorization_EmailCodeRequired) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: b.busy
              ? null
              : () => setState(() {
                  _input.clear();
                  _editingPhone = true;
                }),
          child: const Text('Изменить номер телефона'),
        ),
      ],
      if (_editingPhone) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: b.busy
              ? null
              : () => setState(() {
                  _input.clear();
                  _editingPhone = false;
                }),
          child: const Text('Вернуться к подтверждению'),
        ),
      ],
    ];
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
  void _createProfile() {
    if (_profileName.text.trim().isNotEmpty) b.createProfile(_profileName.text);
  }

  Future<void> _submit(auth.Authorization state) async {
    if (b.busy || _input.text.trim().isEmpty) return;
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
    if (input == null) return;
    await b.login(input);
    if (!mounted) return;
    if (b.error == null)
      setState(() {
        _input.clear();
        _editingPhone = false;
      });
  }
}

String _deliveryName(String delivery) => switch (delivery) {
  'TelegramMessage' => 'Telegram',
  'Sms' || 'FirebaseAndroid' || 'FirebaseIos' => 'СМС',
  'SmsWord' => 'слово в СМС',
  'SmsPhrase' => 'фраза в СМС',
  'Call' => 'звонок',
  'FlashCall' || 'MissedCall' => 'номер входящего звонка',
  'Fragment' => 'Fragment',
  _ => 'способ, выбранный Telegram',
};
String _codeTitle(String delivery) => switch (delivery) {
  'TelegramMessage' => 'Проверьте Telegram',
  'Sms' ||
  'SmsWord' ||
  'SmsPhrase' ||
  'FirebaseAndroid' ||
  'FirebaseIos' => 'Проверьте СМС',
  'Call' || 'FlashCall' || 'MissedCall' => 'Ожидайте звонок',
  _ => 'Введите код подтверждения',
};
String _codeHelp(String delivery) => switch (delivery) {
  'TelegramMessage' =>
    'Код отправлен в Telegram на устройстве, где вы уже вошли в аккаунт.',
  'SmsWord' => 'Введите слово из сообщения СМС.',
  'SmsPhrase' => 'Введите фразу из сообщения СМС.',
  'Call' => 'Введите код, который продиктуют во время звонка.',
  'FlashCall' || 'MissedCall' =>
    'Введите цифры номера входящего звонка, которые запрашивает Telegram.',
  'Fragment' => 'Посмотрите код для своего номера на Fragment.',
  _ => 'Способ доставки: ${_deliveryName(delivery)}.',
};

class _ResendCodeButton extends StatefulWidget {
  const _ResendCodeButton({required this.backend, required this.authorization});
  final BackendController backend;
  final auth.Authorization_CodeRequired authorization;
  @override
  State<_ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<_ResendCodeButton> {
  Timer? _timer;
  int? _remaining;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant _ResendCodeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.authorization, widget.authorization)) _reset();
  }

  void _reset() {
    _timer?.cancel();
    _remaining = widget.authorization.timeoutSeconds;
    if ((_remaining ?? 0) > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _remaining = _remaining! - 1);
        if (_remaining == 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.authorization.nextDelivery;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: next == null
          ? const Text(
              'Telegram пока не предлагает другой способ доставки кода.',
            )
          : TextButton(
              onPressed: widget.backend.busy || _remaining != 0
                  ? null
                  : () => widget.backend.login(const auth.Login.resendCode()),
              child: Text(
                (_remaining ?? 0) > 0
                    ? 'Получить код: ${_deliveryName(next)} через $_remaining с'
                    : _remaining == null
                    ? 'Повторная отправка пока недоступна'
                    : 'Получить код: ${_deliveryName(next)}',
              ),
            ),
    );
  }
}
