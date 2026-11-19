import 'package:flutter/foundation.dart';

enum Destination {
  home,
  search,
  library,
  playlist,
  album,
  artist,
  favorites,
  settings,
  imports,
}

@immutable
class MusicLocation {
  const MusicLocation(this.destination, {this.id, this.title, this.artist});
  final Destination destination;
  final String? id;
  final String? title;
  final String? artist;
}

/// UI history only; playback and its queue never live in this navigator.
class MusicNavigation extends ChangeNotifier {
  final List<MusicLocation> _history = [const MusicLocation(Destination.home)];
  int _index = 0;
  MusicLocation get current => _history[_index];
  bool get canBack => _index > 0;
  bool get canForward => _index + 1 < _history.length;

  void go(MusicLocation location) {
    _history.removeRange(_index + 1, _history.length);
    _history.add(location);
    _index++;
    notifyListeners();
  }

  void back() {
    if (canBack) {
      _index--;
      notifyListeners();
    }
  }

  void forward() {
    if (canForward) {
      _index++;
      notifyListeners();
    }
  }

  void reset() {
    _history
      ..clear()
      ..add(const MusicLocation(Destination.home));
    _index = 0;
    notifyListeners();
  }
}
