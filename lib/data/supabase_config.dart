class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://uoypqgnoohjnaiguvvgs.supabase.co');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_QihUpTZ-fvgvw5G8Fad1gA_M3o-4c0I');
  static const offlineDemo =
      bool.fromEnvironment('CAZINO_OFFLINE_DEMO', defaultValue: false);

  static bool get configured => url.isNotEmpty && key.isNotEmpty;
}
