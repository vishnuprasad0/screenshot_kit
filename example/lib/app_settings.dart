import 'package:flutter/material.dart';

/// App-level state: a user name and an accent colour.
///
/// It stands in for the provider (Provider, Riverpod, Bloc, ...) a real app
/// would declare above its `MaterialApp`. The off-screen demo reads it from a
/// widget that is captured without ever being shown, to prove that such
/// providers are inherited.
class AppSettings extends ChangeNotifier {
  String _userName = 'Ada Lovelace';
  Color _accent = Colors.deepPurple;

  String get userName => _userName;
  set userName(String value) {
    _userName = value;
    notifyListeners();
  }

  Color get accent => _accent;
  set accent(Color value) {
    _accent = value;
    notifyListeners();
  }
}

/// Provides an [AppSettings] to the whole app.
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  /// The settings above [context]; rebuilds when they change.
  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'No AppSettingsScope above this context');
    return scope!.notifier!;
  }
}
