import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kiyora/core/bridge/generated/api.dart' as api;
import 'package:kiyora/core/bridge/generated/api/auth.dart' as auth;
import 'package:kiyora/core/bridge/generated/api/vault.dart' as vault;
import 'package:kiyora/core/bridge/generated/frb_generated.dart';
import 'package:kiyora/core/state/backend_controller.dart';
import 'package:kiyora/features/onboarding/onboarding.dart';
import 'package:kiyora/features/settings/profile_menu.dart';

import 'backend_controller_test.dart' show TestApi;

class ProfileActionsApi extends TestApi {
  api.Session active = TestApi.session;
  final savedProfiles = <api.Profile>[
    const api.Profile(id: 'profile', label: 'Основной'),
    const api.Profile(id: 'second', label: 'Второй'),
  ];
  final switched = <String>[];
  int logouts = 0;
  int connects = 0;
  String? createdName;

  @override
  Future<List<api.Profile>> crateApiProfiles() async => [...savedProfiles];

  @override
  Future<api.Profile> crateApiCreateProfile({required String label}) async {
    createdName = label;
    final profile = api.Profile(id: 'new', label: label);
    savedProfiles.add(profile);
    return profile;
  }

  @override
  Future<api.Session> crateApiSwitchProfile({required String profileId}) async {
    switched.add(profileId);
    active = api.Session(profileId: profileId, sessionId: 'session-$profileId');
    return active;
  }

  @override
  Future<vault.SessionDetails> crateApiVaultSessionDetails({
    required String sessionId,
  }) async => vault.SessionDetails(
    session: active,
    eventSequence: '0',
    apiConfigured: false,
    connection: 'not_started',
    serviceRunning: false,
    repairRequired: false,
  );

  @override
  Future<vault.Status> crateApiVaultStatus() async =>
      vault.Status(session: active, mode: vault.Mode.authRequired);

  @override
  Future<api.ProjectionMarker> crateApiProjectionMarker({
    required String sessionId,
  }) async => api.ProjectionMarker(
    session: active,
    sequence: '0',
    cursor: '',
    trackCount: BigInt.zero,
    playlistCount: BigInt.zero,
  );

  @override
  Future<void> crateApiAuthLogout({required String sessionId}) async {
    expect(sessionId, active.sessionId);
    logouts++;
  }

  @override
  Future<auth.Authorization> crateApiAuthConnect({
    required String sessionId,
  }) async {
    expect(sessionId, active.sessionId);
    connects++;
    return const auth.Authorization.ready();
  }
}

void main() {
  late ProfileActionsApi native;
  late BackendController backend;

  setUp(() async {
    native = ProfileActionsApi();
    RustLib.initMock(api: native);
    backend = BackendController();
    await backend.start();
  });

  tearDown(() async {
    await backend.close();
    RustLib.dispose();
  });

  Future<void> mountMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [ProfileMenuButton(backend: backend)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'current profile is visible and a different profile can be chosen',
    (tester) async {
      await mountMenu(tester);
      expect(find.text('Основной'), findsOneWidget);
      await tester.tap(find.byTooltip('Сменить профиль или выйти'));
      await tester.pumpAndSettle();
      expect(find.text('Сменить профиль'), findsOneWidget);
      await tester.tap(find.text('Второй'));
      await tester.pumpAndSettle();
      expect(native.switched, ['second']);
      expect(backend.session?.profileId, 'second');
      expect(find.text('Второй'), findsOneWidget);
      expect(backend.error, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Telegram logout is confirmed and retains the local profile', (
    tester,
  ) async {
    await mountMenu(tester);
    await tester.tap(find.byTooltip('Сменить профиль или выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти из Telegram'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из Telegram?'), findsOneWidget);
    expect(find.textContaining('Локальная медиатека'), findsOneWidget);
    expect(native.logouts, 0);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(native.logouts, 0);

    await tester.tap(find.byTooltip('Сменить профиль или выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти из Telegram'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(native.logouts, 1);
    expect(backend.authorization, const auth.Authorization.closed());
    expect(backend.session, TestApi.session);
    expect(backend.profiles, hasLength(2));
    expect(backend.error, isNull);
  });

  testWidgets('create profile validates the label and switches to it', (
    tester,
  ) async {
    await mountMenu(tester);
    await tester.tap(find.byTooltip('Сменить профиль или выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить профиль'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Создать'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Создать'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '  Рабочий  ');
    await tester.pump();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(native.createdName, 'Рабочий');
    expect(native.switched, ['new']);
    expect(backend.session?.profileId, 'new');
    expect(find.text('Рабочий'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile menu stays available without an attached library', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Onboarding(backend: backend)),
      ),
    );
    expect(find.byTooltip('Сменить профиль или выйти'), findsOneWidget);
    await tester.tap(find.byTooltip('Сменить профиль или выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Второй'), findsOneWidget);
    await tester.tap(find.text('Второй'));
    await tester.pumpAndSettle();
    expect(backend.session?.profileId, 'second');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 400.0, 720.0]) {
    testWidgets('profile menu fits onboarding width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 700);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Onboarding(backend: backend)),
        ),
      );
      await tester.tap(find.byTooltip('Сменить профиль или выйти'));
      await tester.pumpAndSettle();
      expect(find.text('Добавить профиль'), findsOneWidget);
      expect(find.text('Выйти из Telegram'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('signed-out library offers a route back to Telegram login', (
    tester,
  ) async {
    native.active = const api.Session(
      profileId: 'profile',
      sessionId: 'session',
      vaultId: 'vault',
    );
    backend.session = native.active;
    backend.authorization = const auth.Authorization.closed();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ProfileMenuButton(backend: backend, onLogin: () => opened++),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Сменить профиль или выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Войти в Telegram'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reauthentication with an existing library returns to the player',
    (tester) async {
      native.active = const api.Session(
        profileId: 'profile',
        sessionId: 'session',
        vaultId: 'vault',
      );
      backend.session = native.active;
      backend.authorization = const auth.Authorization.closed();
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Onboarding(
              backend: backend,
              onConnected: () => returned = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Войти в Telegram'));
      await tester.pumpAndSettle();
      expect(native.connects, 1);
      expect(find.text('Telegram подключён'), findsOneWidget);
      expect(find.text('Создать библиотеку'), findsNothing);
      await tester.tap(find.text('Вернуться к медиатеке'));
      expect(returned, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
