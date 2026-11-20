import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = 'https://mchdfilzickkrebcmrtb.supabase.co';
  static const publishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jaGRmaWx6aWNra3JlYmNtcnRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUxMzgwMTQsImV4cCI6MjExMDcxNDAxNH0.8PaNxc2-pNDIUXdV0dGtqlWO-U2RwpbXkw6CA8msjqA';

  static bool _isInitialized = false;

  static bool get isConfigured => publishableKey.isNotEmpty;

  static SupabaseClient? get client =>
      _isInitialized ? Supabase.instance.client : null;

  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(url: url, publishableKey: publishableKey);
    _isInitialized = true;
  }

  static StateError configurationError() =>
      StateError('Supabase belum diinisialisasi.');
}
