import 'package:flutter/material.dart';
import 'package:qrscan/config/app_config.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/auth_scope.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_logo.dart';
import 'package:qrscan/widgets/app_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _loading = false;
  String? _error;
  String? _emailError;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = AuthScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
      _emailError = null;
    });
    try {
      await auth.login(email: _emailCtrl.text, password: _passCtrl.text);
      // AuthGate swaps to the signed-in home; nothing to do here.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.failure == ApiFailure.validation) {
          _emailError = e.firstError('email') ?? e.message;
        } else {
          _error = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sessionExpired = AuthScope.of(context).sessionExpired;

    return Scaffold(
      backgroundColor: scheme.primary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bandHeight = (constraints.maxHeight * 0.32).clamp(
            220.0,
            constraints.maxHeight,
          );
          final panelMinHeight = (constraints.maxHeight - bandHeight).clamp(
            0.0,
            constraints.maxHeight,
          );
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                _Header(height: bandHeight),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: panelMinHeight),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Masuk', style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text(
                              'Gunakan akun SIPP Anda untuk melanjutkan.',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            if (_error != null) ...[
                              _Banner(message: _error!, isError: true),
                              const SizedBox(height: 16),
                            ] else if (sessionExpired) ...[
                              const _Banner(
                                message: ApiException.unauthorizedMessage,
                                isError: false,
                              ),
                              const SizedBox(height: 16),
                            ],
                            AppTextField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              label: 'Email',
                              hint: 'nama@email.com',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              prefixIcon: Icons.mail_outline,
                              errorText: _emailError,
                              enabled: !_loading,
                              onChanged: (_) {
                                if (_emailError != null) {
                                  setState(() => _emailError = null);
                                }
                              },
                              onSubmitted: (_) => _passFocus.requestFocus(),
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) return 'Email wajib diisi.';
                                if (!_emailPattern.hasMatch(value)) {
                                  return 'Format email tidak valid.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              label: 'Kata sandi',
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              prefixIcon: Icons.lock_outline,
                              enabled: !_loading,
                              onSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Kata sandi wajib diisi.'
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            AppButton(
                              label: 'Masuk',
                              isLoading: _loading,
                              onPressed: _loading ? null : _submit,
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Text(
                                '© ${DateTime.now().year} Pustikom UNG',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: const AppLogo(size: 72),
            ),
            const SizedBox(height: 12),
            Text(
              AppConfig.appName,
              style: theme.textTheme.headlineSmall?.copyWith(color: onPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              AppConfig.appFullName,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: onPrimary.withValues(alpha: 0.8),
              ),
            ),
            Text(
              AppConfig.institution,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: onPrimary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final background = isError ? tokens.dangerContainer : tokens.infoContainer;
    final foreground = isError ? tokens.danger : tokens.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: foreground,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
