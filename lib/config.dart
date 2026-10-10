/// =====================================================================
/// FILE PENGATURAN - hanya file ini yang perlu kamu edit.
/// =====================================================================
class AppConfig {
  // --- Supabase: Project Settings > API ---
  static const supabaseUrl = 'https://gzadtkqgegfaainabiov.supabase.co';        // contoh: https://abcdxyz.supabase.co
  static const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6YWR0a3FnZWdmYWFpbmFiaW92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0NjQ4NTEsImV4cCI6MjEwNzA0MDg1MX0.9Q8V33sOwiQWB0qJ_Eqz0S--JhzcnGpiy9T-H4elZ5k'; // kunci "anon public"

  // Roboflow TIDAK diisi di sini. Key & model disimpan sebagai Secret di
  // Supabase (Edge Functions > Secrets). Lihat README tahap 2.

  // --- Info aplikasi ---
  static const appName = 'Banana Ripeness Vision';
  static const appVersion = '1.0.0';
  static const emailDomain = 'pisang.app'; // domain email internal (tidak perlu diubah)
  static const contactEmail = 'geovanipradipta123@gmail.com';
  static const contactWa = '085947105271';
}
