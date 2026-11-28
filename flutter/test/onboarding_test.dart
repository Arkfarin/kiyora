import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/onboarding/onboarding.dart';
import 'package:kiyora/core/theme/kiyora_theme.dart';

import 'backend_controller_test.dart' show TestApi;

class LoginApi extends TestApi {
  int connections = 0;
  late Completer<auth.Authorization> connection;
  auth.Login? lastInput;
  auth.Authorization result = const auth.Authorization.qrConfirmation(
    link: 'tg://login?token=test',
  );
  Object? loginError;
  int logouts = 0;
  @override
  Future<auth.Authorization> crateApiAuthStatus({
    required String sessionId,
  }) async => result;
  @override
  Future<void> crateApiAuthLogout({required String sessionId}) async {
    logouts++;
  }

  @override
  Future<auth.Authorization> crateApiAuthConnect({required String sessionId}) {
    expect(sessionId, TestApi.session.sessionId);
    connections++;
    connection = Completer<auth.Authorization>();
    return connection.future;
  }

  @override
  Future<auth.Authorization> crateApiAuthAuthenticate({
    required String sessionId,
    required auth.Login input,
    required auth.Operation operation,
  }) async {
    lastInput = input;
    if (loginError != null) throw loginError!;
    return result;
  }
}

void main() {
  late LoginApi native;
  late BackendController backend;
  setUp(() {
    native = LoginApi();
    RustLib.initMock(api: native);
    backend = BackendController();
  });
  tearDown(() async {
    await backend.close();
    RustLib.dispose();
  });

  testWidgets('login needs no application credentials and preserves QR flow', (
    tester,
  ) async {
    await backend.start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Onboarding(backend: backend)),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('API'), findsNothing);
    expect(find.textContaining('my.telegram.org'), findsNothing);
    final login = find.text('Войти в Telegram');
    await tester.tap(login);
    await tester.pump();
    await tester.tap(login);
    expect(native.connections, 1);
    native.connection.complete(const auth.Authorization.phoneRequired());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Номер телефона'), findsOneWidget);
    await tester.tap(find.text('Войти по QR-коду'));
    await tester.pumpAndSettle();
    expect(native.lastInput, const auth.Login.qr());
    expect(backend.authorization, isA<auth.Authorization_QrConfirmation>());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unconfigured build reports an error without credential fields', (
    tester,
  ) async {
    await backend.start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Onboarding(backend: backend)),
      ),
    );
    await tester.tap(find.text('Войти в Telegram'));
    native.connection.completeError(
      const api.BridgeError(
        code: 'AppConfigurationUnavailable',
        message: 'Установите настроенную сборку приложения.',
        retryable: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Установите настроенную сборку приложения.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(backend.busy, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('profile name never leaks into the new library title', (
    tester,
  ) async {
    await backend.start();
    backend.session = null;
    backend.authorization = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Onboarding(backend: backend)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'My personal profile');
    backend.session = TestApi.session;
    backend.authorization = const auth.Authorization.ready();
    backend.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Название новой библиотеки'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<void> showStep(WidgetTester tester, auth.Authorization state) async {
    await backend.start();
    backend.authorization = state;
    native.result = state;
    await tester.pumpWidget(
      MaterialApp(
        theme: kiyoraTheme(Brightness.dark),
        home: Scaffold(body: Onboarding(backend: backend)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'phone and QR actions are separated and code entry can switch methods',
    (tester) async {
      await showStep(tester, const auth.Authorization.phoneRequired());
      final primary = tester.getRect(
        find.widgetWithText(FilledButton, 'Продолжить'),
      );
      final qr = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Войти по QR-коду'),
      );
      expect(qr.top - primary.bottom, greaterThanOrEqualTo(12));
      native.result = const auth.Authorization.codeRequired(
        delivery: 'TelegramMessage',
      );
      await tester.enterText(find.byType(TextField), '+996123456789');
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TelegramMessage'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      await tester.tap(find.text('Изменить номер телефона'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '+996987654321');
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(native.lastInput, const auth.Login.phone('+996987654321'));
      expect(find.text('Код подтверждения'), findsOneWidget);
      native.result = const auth.Authorization.qrConfirmation(
        link: 'tg://login?token=test',
      );
      await tester.tap(find.text('Войти по QR-коду'));
      await tester.pumpAndSettle();
      expect(native.lastInput, const auth.Login.qr());
      expect(find.text('Обновить QR-код'), findsNothing);
      await tester.ensureVisible(find.text('Войти по номеру телефона'));
      await tester.tap(find.text('Войти по номеру телефона'));
      await tester.pump();
      expect(native.logouts, 1);
      native.connection.complete(const auth.Authorization.phoneRequired());
      await tester.pumpAndSettle();
      expect(find.text('Номер телефона'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'resend respects server delay and a rejected code remains editable',
    (tester) async {
      await showStep(
        tester,
        const auth.Authorization.codeRequired(
          delivery: 'Sms',
          nextDelivery: 'Call',
          timeoutSeconds: 3,
        ),
      );
      expect(find.text('Проверьте СМС'), findsOneWidget);
      expect(native.lastInput, isNull);
      await tester.enterText(find.byType(TextField), '12345');
      native.loginError = StateError('Invalid code');
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '12345',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      native.loginError = null;
      await tester.tap(find.text('Получить код: звонок'));
      await tester.pumpAndSettle();
      expect(native.lastInput, const auth.Login.resendCode());
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'switching away from a QR that just completed never logs out the account',
    (tester) async {
      await showStep(
        tester,
        const auth.Authorization.qrConfirmation(link: 'tg://login?token=test'),
      );
      native.result = const auth.Authorization.ready();
      await tester.ensureVisible(find.text('Войти по номеру телефона'));
      await tester.tap(find.text('Войти по номеру телефона'));
      await tester.pumpAndSettle();
      expect(native.logouts, 0);
      expect(backend.authorization, const auth.Authorization.ready());
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
