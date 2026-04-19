/// App-wide configuration constants.
/// Replace placeholders with your actual Supabase project values.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = 'https://bifiyppbqubakllgouci.supabase.co';

  // ⚠️ This is the ANON (public) key — safe to embed in client apps.
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZml5cHBicXViYWtsbGdvdWNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjYyMDAsImV4cCI6MjA5MDA0MjIwMH0.SrN0euyuPjeBCqJDxdz2GYFFBE6okusSW4IbOcjplDA';

  static const String checkoutFunctionUrl =
      '$supabaseUrl/functions/v1/checkout';
}
