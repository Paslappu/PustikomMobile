import 'package:flutter/material.dart';
import 'package:qrscan/pages/base.dart';
import 'package:qrscan/pages/login_page.dart';
import 'package:qrscan/pages/splash_page.dart';
import 'package:qrscan/services/auth_controller.dart';
import 'package:qrscan/services/auth_scope.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = AuthScope.of(context).status;
    final Widget page;
    switch (status) {
      case AuthStatus.unknown:
        page = const SplashPage(key: ValueKey('splash'));
      case AuthStatus.signedOut:
        page = const LoginPage(key: ValueKey('login'));
      case AuthStatus.signedIn:
        page = BaseHome(key: const ValueKey('home'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: page,
    );
  }
}
