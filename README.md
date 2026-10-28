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

Satu instalasi aplikasi menyimpan satu sesi aktif pada perangkat tersebut.
Pengguna berbeda dapat login bersamaan dari perangkat masing-masing selama
backend tidak menghapus token sesi lain saat login. Jika beberapa perangkat
harus tetap login menggunakan akun yang sama, penerbitan dan penyimpanan banyak
token perlu didukung oleh backend; aplikasi Flutter tidak dapat mengubah
kebijakan penerbitan token server.

## API petugas

Dashboard petugas menggunakan endpoint `/api/v1/officer/dashboard`,
`/api/v1/officer/tasks`, `/api/v1/officer/reports/{id}/verify`,
`/api/v1/officer/inspections`, dan `/api/v1/officer/stbm-desa`. Setiap endpoint
terautentikasi menerima token sesi pada header `Authorization: Bearer <token>`.
Jika endpoint dashboard, tugas, verifikasi, atau data STBM mengembalikan 404
atau 405, aplikasi mencoba endpoint lama yang sesuai. Form IKL tetap dapat
menyimpan ringkasan hasil inspeksi melalui endpoint pembaruan kunjungan lama
ketika endpoint inspeksi belum tersedia.

Respons dashboard dapat membungkus data di dalam `data` dan menyediakan
`summary`, `officer`, serta daftar tugas. Ringkasan mendukung field
`aduan_baru_count` dan `jadwal_ikl_hari_ini_count`. Form inspeksi mengirim
`jadwal_id`, `jenis_sarana_air`, `jarak_sumber_pencemar`, indikator risiko
`p1`–`p5`, `intervensi_fisik`, `catatan_intervensi`,
`rekomendasi_sanitarian`, `status_kunjungan`, dan `catatan_petugas`.

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
