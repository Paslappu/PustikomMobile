import 'package:flutter/widgets.dart';
import 'package:qrscan/services/app_services.dart';

/// Exposes [AppServices] to the widget tree. It never changes during the app
/// lifetime, so widgets that call [of] only rebuild when the instance is
/// replaced (tests).
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
