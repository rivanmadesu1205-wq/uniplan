import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class AuthService {
  SupabaseClient get _client =>
      SupabaseConfig.client ?? (throw SupabaseConfig.configurationError());

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => SupabaseConfig.client?.auth.currentUser;

  Future<User?> register({
    required String email,
    required String password,
    required String nama,
    required String nim,
    required String prodi,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedNim = nim.trim();
      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'nama': nama, 'nim': normalizedNim, 'prodi': prodi},
      );

      final user = response.user;
      if (user != null && response.session != null) {
        await _upsertProfile(
          userId: user.id,
          nama: nama,
          email: normalizedEmail,
          nim: normalizedNim,
          prodi: prodi,
        );
      }
      return user;
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('profiles_nim_key') ||
          message.contains('duplicate key value')) {
        throw 'NIM sudah terdaftar. Silakan gunakan NIM lain.';
      }
      if (message.contains('already registered') ||
          message.contains('already exists') ||
          message.contains('user already registered')) {
        throw 'Email sudah terdaftar. Silakan gunakan email lain atau masuk.';
      }
      if (message.contains('password') && message.contains('least')) {
        throw 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      }
      if (message.contains('email') && message.contains('invalid')) {
        throw 'Format email tidak valid.';
      }
      throw error.message;
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw 'NIM sudah terdaftar. Silakan gunakan NIM lain.';
      }
      throw 'Profil tidak dapat disimpan: ${error.message}';
    } on StateError {
      rethrow;
    } catch (error) {
      if (error is String) rethrow;
      throw 'Terjadi kesalahan tidak terduga.';
    }
  }

  Future<User?> login({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return response.user;
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid credentials')) {
        throw 'Email atau kata sandi yang Anda masukkan salah.';
      }
      throw error.message;
    } on StateError {
      rethrow;
    } catch (_) {
      throw 'Terjadi kesalahan saat mencoba masuk.';
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return row;
  }

  Future<void> updateUserProfile({
    required String nama,
    required String nim,
    required String prodi,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final normalizedNim = nim.trim();
    try {
      await _client
          .from('profiles')
          .update({
            'nama': nama,
            'nim': normalizedNim.isEmpty ? null : normalizedNim,
            'prodi': prodi,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw 'NIM sudah terdaftar. Silakan gunakan NIM lain.';
      }
      rethrow;
    }

    await _client.auth.updateUser(UserAttributes(data: {'nama': nama}));
  }

  Future<void> logout() async {
    final client = SupabaseConfig.client;
    if (client != null) await client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      throw error.message;
    } on StateError {
      rethrow;
    } catch (_) {
      throw 'Terjadi kesalahan saat mengirim permintaan reset kata sandi.';
    }
  }

  Future<void> _upsertProfile({
    required String userId,
    required String nama,
    required String email,
    required String nim,
    required String prodi,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'nama': nama,
      'email': email,
      'nim': nim.isEmpty ? null : nim,
      'prodi': prodi,
    });
  }
}
