# klinik_sanitasi_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Login satu pintu

Warga dan petugas menggunakan form login yang sama. Aplikasi mengirim
`POST /api/v1/login` dengan body JSON `identifier` dan `password`. URL dasar
API dapat diatur saat menjalankan aplikasi:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
```

Respons login perlu memuat token autentikasi dan array `roles`, misalnya:

```json
{
  "token": "access-token",
  "roles": ["warga"],
  "user": {
    "name": "Nama Pengguna"
  }
}
```

Token dan daftar role disimpan pada `shared_preferences`. Role `petugas` atau
`admin` membuka dashboard petugas, sedangkan akun dengan role `warga` saja
membuka beranda aduan masyarakat.

## Struktur kode

- `lib/constants/`: warna dan konfigurasi aplikasi.
- `lib/models/`: model data.
- `lib/services/`: autentikasi dan komunikasi API.
- `lib/views/auth/`: halaman dan komponen autentikasi.
- `lib/views/public/`: beranda, artikel, pelaporan, pelacakan, dan navigasi warga.
- `lib/views/officer/`: dashboard dan detail kunjungan petugas.
- `lib/views/splash/`: pemeriksaan sesi dan navigasi awal.

Logo aplikasi disimpan di `assets/images/`. Tes alur aplikasi ada di
`test/app_flow_test.dart`; tes model dan layanan tetap berada di `test/`.
