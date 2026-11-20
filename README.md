# UniPlan

UniPlan adalah aplikasi Flutter untuk membantu mahasiswa mengelola jadwal kuliah, catatan materi, tugas, dan pengingat alarm perkuliahan.

Aplikasi menggunakan pendekatan **offline-first**: data jadwal dan catatan disimpan di SQLite pada perangkat, lalu disinkronkan ke Supabase ketika session pengguna tersedia.

## Fitur

### Autentikasi

- Registrasi dengan email, kata sandi, nama, NIM, dan program studi.
- Login, logout, dan reset kata sandi melalui Supabase Auth.
- Pemeriksaan session ketika aplikasi dibuka.
- Pengelolaan profil pengguna.
- Dukungan konfirmasi email dari pengaturan Supabase.

### Jadwal kuliah

- Melihat jadwal hari ini dan jadwal berdasarkan kalender/tanggal.
- Menambah, mengedit, dan menghapus jadwal.
- Menyimpan mata kuliah, dosen, ruangan, hari, tanggal, dan jam kuliah.
- Mengaktifkan atau menonaktifkan alarm per jadwal.
- Memilih pengingat 5, 10, 15, atau 30 menit sebelum kuliah.
- Tombol simpan dikunci saat proses berjalan untuk mencegah data ganda akibat spam tap.

### Catatan dan tugas

- Menambahkan catatan atau tugas berdasarkan mata kuliah.
- Mengelompokkan catatan berdasarkan mata kuliah dan minggu/pertemuan.
- Mencari berdasarkan mata kuliah, judul, atau isi.
- Memfilter kategori `catatan` atau `tugas`.
- Mengedit dan menghapus catatan.
- Proteksi duplicate-submit pada kedua dialog tambah/edit catatan.

### Notifikasi dan preferensi

- Notifikasi alarm mingguan untuk jadwal kuliah.
- Nada dering bawaan dan file audio kustom dari perangkat.
- Pengujian nada dering dari pengaturan.
- Tema terang, gelap, atau mengikuti sistem.
- Sinkronisasi ulang alarm ketika jadwal berubah.

### Branding

- Logo utama menggunakan [`assets/logo.png`](assets/logo.png).
- Logo digunakan pada splash screen dan halaman aplikasi.
- Ikon launcher Android dan iOS dibuat dari aset logo tersebut.

## Teknologi

| Komponen | Teknologi |
| --- | --- |
| Framework | Flutter |
| Bahasa | Dart |
| State management auth | `flutter_bloc` |
| Autentikasi/cloud | Supabase Auth dan Supabase Postgres |
| Database lokal | SQLite melalui `sqflite` |
| Notifikasi | `flutter_local_notifications` |
| Zona waktu | `timezone` |
| Preferensi | `shared_preferences` |
| Pemilihan file | `file_picker` |
| Audio | `audioplayers` |
| Ikon aplikasi | `flutter_launcher_icons` |

## Struktur proyek

```text
uniplan/
├── assets/logo.png                       # Logo utama
├── lib/
│   ├── bloc/auth/auth_bloc.dart          # Event, state, dan proses auth
│   ├── models/                           # Model jadwal dan catatan
│   ├── pages/
│   │   ├── auth/                         # Login, registrasi, reset password
│   │   ├── home/                         # Beranda
│   │   ├── notes/                        # Catatan dan tugas
│   │   ├── schedule/                     # Kalender dan form jadwal
│   │   └── settings/                     # Profil, tema, alarm, logout
│   ├── services/
│   │   ├── auth_service.dart             # Auth dan profil
│   │   ├── database_service.dart         # SQLite dan sinkronisasi
│   │   ├── notification_service.dart     # Alarm dan nada dering
│   │   └── supabase_config.dart           # Konfigurasi Supabase
│   ├── widgets/                          # Komponen UI reusable
│   └── main.dart                         # Entry point aplikasi
├── supabase/schema.sql                   # Schema, trigger, dan RLS
├── test/                                 # Unit test dan widget test
├── pubspec.yaml                          # Dependency dan aset
└── README.md
```

## Arsitektur aplikasi

### Startup

1. Flutter menyiapkan binding aplikasi.
2. Supabase diinisialisasi dengan batas waktu startup.
3. `runApp` dijalankan setelah proses Supabase selesai atau gagal.
4. Notifikasi diinisialisasi secara non-blocking setelah UI tampil.
5. `AuthBloc` memeriksa session pengguna.
6. Splash screen tampil sekitar dua detik.
7. Session aktif membuka halaman utama; selain itu aplikasi membuka halaman login.

### Autentikasi dengan BLoC

[`lib/bloc/auth/auth_bloc.dart`](lib/bloc/auth/auth_bloc.dart) menjadi pusat state autentikasi. Halaman mengirim event ke BLoC dan tidak mengelola proses Supabase secara langsung.

Event:

- `AuthStarted`: memeriksa session saat startup.
- `AuthLoginRequested`: meminta login.
- `AuthRegisterRequested`: meminta registrasi.
- `AuthLogoutRequested`: meminta logout.

State:

- `AuthInitial`: state awal.
- `AuthLoading`: proses sedang berjalan.
- `AuthAuthenticated`: user berhasil login.
- `AuthUnauthenticated`: tidak ada user aktif.
- `AuthRegistrationSuccess`: registrasi berhasil, dengan atau tanpa session langsung.
- `AuthFailure`: proses gagal dan membawa pesan error.

`AuthService` menangani komunikasi dengan Supabase, sedangkan `AuthBloc` mengatur state yang dibaca halaman login, registrasi, dan aplikasi utama. Listener session Supabase hanya dibuat satu kali untuk mencegah loop rebuild splash screen.

### Offline-first

```text
UI
 │
 ▼
DatabaseService
 ├── SQLite lokal: baca/tulis data
 └── Supabase: push data lokal dan ambil data cloud saat session aktif
```

Data lokal menggunakan `userId`. Saat belum login, identitas lokalnya adalah `guest_user`. Saat login, data dipisahkan menggunakan ID user Supabase.

## Database

Database SQLite menggunakan nama `studyplan_v6.db` dan versi schema `4`.

### Tabel `jadwal`

Menyimpan ID lokal, ID Supabase, user, mata kuliah, dosen, ruangan, hari, tanggal, jam mulai, jam selesai, status alarm, dan daftar menit pengingat.

### Tabel `catatan`

Menyimpan ID lokal, ID Supabase, user, relasi jadwal, mata kuliah, minggu/pertemuan, judul, isi, tanggal, waktu, tipe, dan waktu pembuatan.

### Pencegahan data ganda

Operasi tambah/edit menggunakan state loading lokal. Tombol simpan langsung dinonaktifkan, menampilkan spinner, mengabaikan tap tambahan, lalu aktif kembali ketika proses selesai atau gagal. Proteksi ini diterapkan pada form jadwal dan kedua jalur dialog tambah/edit catatan.

## Supabase

Schema berada di [`supabase/schema.sql`](supabase/schema.sql) dan membuat tabel:

- `profiles`
- `jadwal`
- `catatan`

Semua tabel mengaktifkan Row Level Security (RLS). Policy membatasi pengguna agar hanya dapat membaca atau mengubah record dengan `user_id` miliknya sendiri.

Trigger `handle_new_user` membuat atau memperbarui profil setelah user baru dibuat di `auth.users`. Data `nama`, `nim`, dan `prodi` berasal dari metadata registrasi aplikasi.

### Menyiapkan Supabase

1. Buat project di Supabase.
2. Buka **SQL Editor**.
3. Jalankan [`supabase/schema.sql`](supabase/schema.sql).
4. Buka **Authentication → Providers → Email**.
5. Aktifkan provider Email.
6. Untuk development tanpa email konfirmasi, matikan **Confirm email**.
7. Pastikan URL dan publishable/anon key pada [`lib/services/supabase_config.dart`](lib/services/supabase_config.dart) sesuai project.

Jangan memasukkan `service_role` key ke aplikasi Flutter. Key tersebut hanya boleh digunakan pada server yang aman.

## Menjalankan proyek

### Persyaratan

- Flutter SDK dengan Dart `^3.13.5`.
- Android Studio atau Xcode sesuai platform.
- Perangkat Android/iOS atau emulator.
- Project Supabase untuk autentikasi dan sinkronisasi cloud.

### Instalasi dan run

```powershell
cd C:\uniplan
flutter pub get
flutter devices
flutter run
```

Device tertentu:

```powershell
flutter run -d <device-id>
```

Chrome:

```powershell
flutter run -d chrome
```

### Troubleshooting splash screen

Jika aplikasi berhenti pada logo, gunakan cold restart:

```powershell
flutter clean
flutter pub get
flutter run
```

Jika logo lama masih muncul, uninstall aplikasi dari perangkat lalu jalankan kembali. Startup menulis log `Supabase initialization started` dan `Supabase initialization completed` untuk diagnosis.

## Pengujian

Menjalankan seluruh test:

```powershell
flutter test
```

Test tertentu:

```powershell
flutter test test\pages\login_page_test.dart
flutter test test\pages\catatan_page_test.dart
flutter test test\pages\schedule_pages_test.dart
```

Test berdasarkan nama:

```powershell
flutter test test\pages\login_page_test.dart --plain-name "menampilkan validasi saat login tanpa input"
```

Analisis kode dan coverage:

```powershell
flutter analyze
flutter test --coverage
```

Test mencakup model, autentikasi, database lokal, login, jadwal, catatan, pengaturan, dialog, widget, dan notifikasi. Test database menggunakan SQLite FFI sehingga tidak membutuhkan koneksi Supabase nyata.

## Ikon dan aset

Logo utama berada di [`assets/logo.png`](assets/logo.png) dan dideklarasikan di [`pubspec.yaml`](pubspec.yaml):

```yaml
flutter:
  assets:
    - assets/logo.png
```

Setelah mengganti logo, buat ulang ikon native:

```powershell
dart run flutter_launcher_icons
```

Kemudian build ulang atau uninstall aplikasi dari perangkat agar cache launcher dan splash tidak menampilkan gambar lama.

## Catatan pengembangan

- Gunakan `AuthBloc` untuk perubahan state autentikasi baru.
- Gunakan `AuthService` untuk Auth dan `DatabaseService` untuk jadwal/catatan.
- Pertahankan RLS ketika menambah tabel atau query Supabase.
- Semua operasi async tambah/edit/hapus harus memiliki guard loading agar aman dari spam tap.
- Gunakan formatter Dart setelah mengubah file `.dart`.
- Jalankan `flutter analyze` dan test yang relevan sebelum membuat build rilis.
