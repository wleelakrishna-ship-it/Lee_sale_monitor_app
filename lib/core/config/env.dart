/// Compile-time configuration supplied with `--dart-define` or
/// `--dart-define-from-file=env/dev.json`.
///
/// Only public values (project URL and the anon key) belong here. Never add a
/// service-role key or other secret to the Flutter build.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}