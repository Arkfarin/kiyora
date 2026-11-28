import 'package:flutter_test/flutter_test.dart';
import 'package:kiyora/core/routing/navigation.dart';

void main() {
  test(
    'revisiting the current page does not create duplicate back entries',
    () {
      final navigation = MusicNavigation();
      addTearDown(navigation.dispose);
      var notifications = 0;
      navigation.addListener(() => notifications++);

      navigation.go(const MusicLocation(Destination.home));
      expect(navigation.canBack, isFalse);
      expect(notifications, 0);

      navigation.go(const MusicLocation(Destination.library));
      navigation.go(const MusicLocation(Destination.library));
      expect(notifications, 1);
      navigation.back();
      expect(navigation.current.destination, Destination.home);
      expect(navigation.canBack, isFalse);
    },
  );

  test('distinct details retain history and old entries are bounded', () {
    final navigation = MusicNavigation();
    addTearDown(navigation.dispose);
    navigation.go(const MusicLocation(Destination.playlist, id: 'a'));
    navigation.go(const MusicLocation(Destination.playlist, id: 'b'));
    navigation.back();
    expect(navigation.current.id, 'a');
    navigation.forward();
    expect(navigation.current.id, 'b');

    for (var i = 0; i < 200; i++) {
      navigation.go(MusicLocation(Destination.album, title: 'Album $i'));
    }
    for (var i = 0; i < 150; i++) navigation.back();
    expect(navigation.canBack, isFalse);
    expect(navigation.current.title, 'Album 100');
  });
}
