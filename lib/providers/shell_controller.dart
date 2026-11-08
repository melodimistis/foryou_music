import 'package:flutter/foundation.dart';

import '../pages/libraries.dart';

class ShellController extends ChangeNotifier {
  static const home = 0;
  static const search = 1;
  static const libraries = 2;
  static const about = 3;
  static const legal = 4;

  int _index = home;
  bool _menuOpen = false;
  bool _searchOpen = false;
  final libraryView = ValueNotifier<LibraryView?>(null);

  ShellController() {
    libraryView.addListener(notifyListeners);
  }

  int get index => _index;
  bool get menuOpen => _menuOpen;
  bool get searchOpen => _searchOpen;
  bool get panelOpen => _menuOpen || _searchOpen;

  int get dockIndex =>
      _searchOpen ? search : (_index == search ? home : _index);

  bool get canPop =>
      !panelOpen && !(_index == libraries && libraryView.value != null);

  void select(int index) {
    if (index == libraries && _index == libraries) libraryView.value = null;
    _index = index;
    _menuOpen = false;
    _searchOpen = false;
    notifyListeners();
  }

  void toggleSearch() {
    _searchOpen = !_searchOpen;
    _menuOpen = false;
    notifyListeners();
  }

  void openSearch() {
    _searchOpen = true;
    _menuOpen = false;
    notifyListeners();
  }

  void toggleMenu() {
    _menuOpen = !_menuOpen;
    _searchOpen = false;
    notifyListeners();
  }

  void closePanels() {
    if (!panelOpen) return;
    _menuOpen = false;
    _searchOpen = false;
    notifyListeners();
  }

  void handleBack() {
    if (panelOpen) {
      closePanels();
    } else if (_index == libraries) {
      libraryView.value = null;
    }
  }

  @override
  void dispose() {
    libraryView.dispose();
    super.dispose();
  }
}
