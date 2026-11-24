import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/onboarding/onboarding.dart';

import 'backend_controller_test.dart' show TestApi;

class LoginApi extends TestApi {
  int connections = 0;
  late Completer<auth.Authorization> connection;
  auth.Login? lastInput;

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
    return const auth.Authorization.qrConfirmation(
      link: 'tg://login?token=test',
    );
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
}
