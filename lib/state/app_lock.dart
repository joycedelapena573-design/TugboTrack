/// In-memory lock state: the app re-locks whenever it goes to the background
/// (requirement 6.2 / 6.4).
library;

import 'package:flutter/foundation.dart';

class AppLock extends ChangeNotifier {
  bool locked = true;

  void lock() {
    if (!locked) return;
    locked = true;
    notifyListeners();
  }

  void unlock() {
    if (!locked) return;
    locked = false;
    notifyListeners();
  }
}
