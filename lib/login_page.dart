import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'supabase_config.dart';
import 'user_profiles.dart';

final _emailHiddenCharacters = RegExp(r'[\s\u00A0\u200B-\u200D\uFEFF]+');
final _emailPattern = RegExp(
  r"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)+$",
  caseSensitive: false,
);

String normalizeEmail(String email) {
  return email.replaceAll(_emailHiddenCharacters, '').toLowerCase();
}

String? emailError(String email) {
  final normalizedEmail = normalizeEmail(email);
  if (normalizedEmail.isEmpty) {
    return 'Введите email';
  }
  if (!_emailPattern.hasMatch(normalizedEmail)) {
    return 'Введите корректный email';
  }
  return null;
}

String? passwordError(String password) {
  if (password.isEmpty) {
    return 'Введите пароль';
  }
  if (password.length < 6) {
    return 'Минимум 6 символов';
  }
  return null;
}

String? iinError(String iin) {
  final trimmed = iin.trim();
  if (trimmed.isEmpty) {
    return 'Введите ИИН';
  }
  if (!RegExp(r'^\d{12}$').hasMatch(trimmed)) {
    return 'ИИН должен состоять из 12 цифр';
  }
  return null;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _iinController = TextEditingController();

  var _isLogin = true;
  var _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _iinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final email = normalizeEmail(_emailController.text);
      final password = _passwordController.text;
      final iin = _iinController.text.trim();

      _emailController.text = email;

      if (_isLogin) {
        final response = await auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = response.user;
        if (user != null) {
          await syncCurrentUserProfile(Supabase.instance.client, user);
        }
      } else {
        final response = await auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: SupabaseConfig.emailRedirectUrl,
          data: {'iin': iin, 'display_name': email},
        );

        if (response.session != null && response.user != null) {
          await syncCurrentUserProfile(
            Supabase.instance.client,
            response.user!,
          );
        }

        if (response.session == null && mounted) {
          setState(() {
            _successMessage =
                'Аккаунт создан. Проверьте почту для подтверждения входа.';
          });
        }
      }
    } on AuthException catch (error) {
      setState(() => _errorMessage = _authMessage(error));
    } catch (error) {
      setState(() => _errorMessage = 'Ошибка подключения: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _authMessage(AuthException error) {
    return switch (error.code) {
      'invalid_credentials' => 'Неверный email или пароль.',
      'email_not_confirmed' => 'Подтвердите email перед входом.',
      'user_already_exists' => 'Пользователь с таким email уже существует.',
      'weak_password' => 'Пароль слишком простой.',
      'signup_disabled' => 'Регистрация отключена в настройках Supabase.',
      _ when error.message.toLowerCase().contains('invalid format') =>
        'Email содержит недопустимый символ. Проверьте адрес и попробуйте снова.',
      _ => error.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: ToolsupPalette.navyCard,
                        ),
                        child: Image.asset(
                          'assets/images/toolsup_logo2.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isLogin ? 'Вход' : 'Регистрация',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin ? '' : 'Создайте аккаунт по email и паролю.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      enableSuggestions: false,
                      smartDashesType: SmartDashesType.disabled,
                      smartQuotesType: SmartQuotesType.disabled,
                      autofillHints: const [AutofillHints.email],
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                          _emailHiddenCharacters,
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) => emailError(value ?? ''),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => passwordError(value ?? ''),
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _iinController,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.username],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 12,
                        decoration: const InputDecoration(
                          labelText: 'ИИН',
                          counterText: '',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) => iinError(value ?? ''),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _MessageBox(
                        message: _errorMessage!,
                        background: colors.errorContainer,
                        foreground: colors.onErrorContainer,
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 16),
                      _MessageBox(
                        message: _successMessage!,
                        background: colors.secondaryContainer,
                        foreground: colors.onSecondaryContainer,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isLogin ? Icons.login : Icons.person_add_alt_1,
                            ),
                      label: Text(_isLogin ? 'Войти' : 'Создать аккаунт'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _errorMessage = null;
                                _successMessage = null;
                              });
                            },
                      child: Text(
                        _isLogin
                            ? 'Нет аккаунта? Зарегистрироваться'
                            : 'Уже есть аккаунт? Войти',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.message,
    required this.background,
    required this.foreground,
  });

  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: foreground)),
      ),
    );
  }
}
