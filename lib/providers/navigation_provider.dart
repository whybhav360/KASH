import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    int clampedIndex = index;
    if (clampedIndex < 0 || clampedIndex > 3) {
      clampedIndex = 0;
    }
    if (_selectedIndex == clampedIndex) return;
    _selectedIndex = clampedIndex;
    notifyListeners();
  }
}
