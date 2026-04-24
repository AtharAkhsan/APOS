/// App-wide configuration constants.
/// Replace placeholders with your actual Supabase project values.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = 'https://fxuqmycgpmlkumxwszpi.supabase.co';

  // ⚠️ This is the ANON (public) key — safe to embed in client apps.
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4dXFteWNncG1sa3VteHdzenBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwNDY3NzksImV4cCI6MjA5MjYyMjc3OX0._ngO413mhPVTc1H7882C96nZN-F9scRJ1c321N7bqc0';

  static const String checkoutFunctionUrl =
      '$supabaseUrl/functions/v1/checkout';
}
