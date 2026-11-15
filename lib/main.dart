import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qrscan/pages/auth_gate.dart';
import 'package:qrscan/services/api_client.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/app_services.dart';
import 'package:qrscan/services/auth_controller.dart';
import 'package:qrscan/services/auth_scope.dart';
import 'package:qrscan/services/auth_service.dart';
import 'package:qrscan/services/token_storage.dart';
import 'package:qrscan/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documentsDir = await getApplicationDocumentsDirectory();
  runApp(MyApp(documentsDir: documentsDir));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.authController,
    this.services,
    this.documentsDir,
  });

  /// Injectable for tests. When null the app builds its own controller.
  final AuthController? authController;

  /// Injectable for tests. When null the real services are built.
  final AppServices? services;

  /// Where the outbox keeps photos. Defaults to the system temp directory
  /// (only meaningful in tests).
  final Directory? documentsDir;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _navKey = GlobalKey<NavigatorState>();

  ApiClient? _api;
  late final AuthController _auth;
  late final AppServices _services;
  late final bool _ownsAuth;
  late final bool _ownsServices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ownsAuth = widget.authController == null;
    if (_ownsAuth) {
      final api = ApiClient();
      _api = api;
      _auth = AuthController(
        service: HttpAuthService(api),
        storage: SecureTokenStorage(),
        api: api,
      );
    } else {
      _auth = widget.authController!;
    }

    _ownsServices = widget.services == null;
    _services =
        widget.services ??
        AppServices.create(
          api: _api ?? (_api = ApiClient()),
          auth: _auth,
          documentsDir: widget.documentsDir ?? Directory.systemTemp,
        );

    _auth.addListener(_onAuthChanged);
    if (_ownsAuth) _auth.restore();
  }

  void _onAuthChanged() {
    if (_auth.status == AuthStatus.signedOut) {
      // Drop any pushed routes when a logout or 401 happens deep in the stack.
      _navKey.currentState?.popUntil((r) => r.isFirst);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _services.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _services.onAppPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_onAuthChanged);
    if (_ownsServices) _services.dispose();
    if (_ownsAuth) _auth.dispose();
    _api?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: AppScope(
        services: _services,
        child: MaterialApp(
          navigatorKey: _navKey,
          title: 'SIPP Pustikom',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const AuthGate(),
        ),
      ),
    );
  }
}
