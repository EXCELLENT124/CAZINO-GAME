import 'package:cazino/data/supabase_config.dart';
import 'package:test/test.dart';

void main() {
  test('packaged builds default to the live CAZINO Supabase project', () {
    expect(SupabaseConfig.offlineDemo, isFalse);
    expect(SupabaseConfig.configured, isTrue);
    expect(SupabaseConfig.url, 'https://uoypqgnoohjnaiguvvgs.supabase.co');
    expect(SupabaseConfig.key, startsWith('sb_publishable_'));
  });
}
