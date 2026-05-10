import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static const _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const _anonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _emailRedirectUrlFromDefine = String.fromEnvironment(
    'SUPABASE_EMAIL_REDIRECT_URL',
  );

  static String get url {
    final rawUrl = _urlFromDefine.isNotEmpty
        ? _urlFromDefine
        : dotenv.env['SUPABASE_URL'] ?? '';

    return _normalizeProjectUrl(rawUrl);
  }

  static String _normalizeProjectUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.endsWith('/rest/v1/')) {
      return trimmed.substring(0, trimmed.length - '/rest/v1/'.length);
    }
    if (trimmed.endsWith('/rest/v1')) {
      return trimmed.substring(0, trimmed.length - '/rest/v1'.length);
    }
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static String get anonKey {
    if (_anonKeyFromDefine.isNotEmpty) {
      return _anonKeyFromDefine;
    }
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  static String? get emailRedirectUrl {
    final rawUrl = _emailRedirectUrlFromDefine.isNotEmpty
        ? _emailRedirectUrlFromDefine
        : dotenv.env['SUPABASE_EMAIL_REDIRECT_URL'] ?? '';
    final trimmed = rawUrl.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool get isConfigured {
    return url.isNotEmpty &&
        anonKey.isNotEmpty &&
        !url.contains('your-project') &&
        anonKey != 'your_anon_key';
  }
}
