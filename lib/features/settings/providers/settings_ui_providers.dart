import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsTabIndexProvider = NotifierProvider<SettingsTabIndexNotifier, int>(
  SettingsTabIndexNotifier.new,
);

class SettingsTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}
