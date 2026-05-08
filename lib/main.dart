import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var supabaseReady = false;
  String? setupError;

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    setupError = 'Файл .env не найден или не добавлен в assets.';
  }

  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      supabaseReady = true;
    } catch (error) {
      setupError = error.toString();
    }
  }

  runApp(ToolsupApp(supabaseReady: supabaseReady, setupError: setupError));
}

class ToolsupApp extends StatelessWidget {
  const ToolsupApp({required this.supabaseReady, this.setupError, super.key});

  final bool supabaseReady;
  final String? setupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toolsup',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
        ),
        useMaterial3: true,
      ),
      home: supabaseReady
          ? const AuthGate()
          : SupabaseSetupPage(errorMessage: setupError),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            auth.currentSession == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session ?? auth.currentSession;
        final user = session?.user;

        if (user == null) {
          return const LoginPage();
        }

        return HomePage(user: user);
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iin = user.userMetadata?['iin']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toolsup'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            onPressed: Supabase.instance.client.auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              color: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 72,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Карточка аккаунта',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 24),
                    _AccountInfoRow(
                      icon: Icons.mail_outline,
                      label: 'Email',
                      value: user.email ?? 'Не указан',
                    ),
                    const Divider(height: 24),
                    _AccountInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'ИИН',
                      value: iin == null || iin.isEmpty ? 'Не указан' : iin,
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

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SupabaseSetupPage extends StatelessWidget {
  const SupabaseSetupPage({this.errorMessage, super.key});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Supabase не настроен',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    errorMessage ??
                        'Укажите SUPABASE_URL и SUPABASE_ANON_KEY в файле .env или через --dart-define.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
