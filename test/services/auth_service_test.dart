import 'package:flutter_test/flutter_test.dart';
import 'package:uniplan/services/auth_service.dart';

void main() {
  group('AuthService tanpa inisialisasi Supabase', () {
    final service = AuthService();

    test('tidak menganggap pengguna terautentikasi', () {
      expect(service.currentUser, isNull);
    });

    test('profil kosong saat belum ada sesi', () async {
      expect(await service.getUserProfile(), isNull);
    });

    test('login menampilkan error inisialisasi yang jelas', () async {
      await expectLater(
        service.login(email: 'user@example.com', password: 'password'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('belum diinisialisasi'),
          ),
        ),
      );
    });

    test('reset kata sandi menampilkan error inisialisasi', () async {
      await expectLater(
        service.sendPasswordResetEmail('user@example.com'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
