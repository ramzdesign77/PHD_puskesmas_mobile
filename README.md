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
atau 405, aplikasi mencoba endpoint lama yang sesuai. Form IKL menyimpan seluruh hasil melalui endpoint inspeksi. Jika permintaan
gagal, aplikasi menampilkan pesan yang sesuai; detail kesalahan SQL tidak
ditampilkan ke petugas. Error skema seperti kolom jadwal yang tidak ditemukan
tetap harus diperbaiki pada backend dengan menyelaraskan query dan migrasi tabel;
aplikasi tidak dapat memperbaiki skema server. Aplikasi juga tidak membuat hasil
resmi dari catatan kunjungan lama.

Respons dashboard dapat membungkus data di dalam `data` dan menyediakan
`summary`, `officer`, serta daftar tugas. Ringkasan mendukung field
`aduan_baru_count` dan `jadwal_ikl_hari_ini_count`. Form inspeksi mengirim
`id_jadwal`, `jenis_sarana_air` (kode enum backend), `jarak_sumber_pencemar`
(bilangan bulat), `tanggal_inspeksi` (YYYY-MM-DD), lima boolean checklist
bernama lengkap, `intervensi_fisik`, `catatan_intervensi`,
`rekomendasi_sanitarian`, dan `catatan_petugas`. Foto opsional dikirim dalam
request multipart yang sama. Backend menentukan status akhir `selesai`.

## Alamat tersimpan warga

Form Alamat Saya dan Lokasi Kejadian memakai endpoint profil terautentikasi
yang sudah digunakan aplikasi: `GET /api/v1/profile` dan
`PUT /api/v1/profile`. Respons `data.user` perlu menyertakan `id_desa`, `rt`,
`rw`, dan `alamat_detail`; `desa` dapat disertakan sebagai objek dengan
`id_desa` dan `nama_desa`. Update alamat memakai `PUT` profil yang juga
menyertakan field profil terkini (`nama_lengkap`, `username`, `email`,
`no_telepon`) agar memenuhi validasi endpoint profil yang ada. Backend harus
memvalidasi desa dan format alamat terhadap skema yang berlaku, lalu menyimpan
perubahan hanya pada user dari token login. Implementasi endpoint dan migration
aditif tersedia pada backend Laravel `PHD_puskesmas`:
`database/migrations/2026_11_10_000000_add_saved_address_to_app_users_table.php`.
Jalankan migration dari root backend sebelum menggunakan fitur pada deployment
lain. Pengiriman laporan tetap menggunakan API laporan yang ada dan mengirim
lokasi yang dipilih pada form; memilih lokasi lain tidak memperbarui alamat
profil.

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

## Integrasi skor risiko IKL — 2 November 2026

Aturan proyek: skor 0 Aman, 1–2 Sedang, 3–5 Tinggi. Checklist mengikuti
backend: dinding sumur retak, penutup tidak rapat, lantai becek/retak,
SPAL tersumbat, dan air keruh/berbau. `lib/models/risk_score.dart` menyimpan
aturan untuk perkiraan langsung di form petugas. Hasil resmi dihitung server.

Petugas: login, buka Input IKL, pilih jadwal yang ditugaskan, isi formulir,
lalu Simpan Hasil IKL. Lima jawaban selalu dikirim. Skor/kategori tidak dikirim
sebagai input yang dapat dipercaya. ID jadwal disimpan terpisah dari ID laporan.
Intervensi, catatan, dan foto disimpan bersama inspeksi; foto berada di storage
privat server. Penyimpanan final menyelesaikan jadwal serta laporan terkait.

Warga: buka Pelacakan / Riwayat & Status Laporan, pilih tiket, lalu lihat
Hasil Inspeksi Petugas. Kartu menampilkan Aman/Sedang/Tinggi, skor, tanggal,
petugas, intervensi, dan rekomendasi dari `GET /api/laporan/{kode_tiket}`.
Tanpa hasil, kartu menampilkan pesan menunggu (tidak diasumsikan Aman).
Data diperbarui saat tab pelacakan dibuka atau halaman ditarik untuk refresh.
Hasil terakhir ikut tersimpan di cache; kegagalan refresh tetap diberitahukan.
Belum menggunakan push notification atau pembaruan WebSocket.

### Pemasangan

1. Terapkan perubahan Laravel beserta migrasi kolom tambahan terlebih dahulu.
2. Gabungkan file yang tercantum di bawah jika proyek lokal sudah lebih baru.
3. Jalankan `flutter pub get`.
4. Jalankan `flutter run --dart-define=API_BASE_URL=http://IP_KOMPUTER:8000/api`.
   Ganti IP_KOMPUTER dengan alamat komputer Laravel yang dapat dijangkau HP.
   Untuk Flutter Web di komputer server, gunakan http://127.0.0.1:8000/api.
5. Gunakan akun petugas aktif yang memiliki jadwal `terjadwal` dari admin.
6. Uji skor 0, 1, 2, 3, 4, 5 pada jadwal berbeda; kemudian buka tiket yang sama
   pada akun warga. Pengiriman kedua untuk jadwal selesai ditolak server.

### Pemeriksaan

```sh
flutter analyze
flutter test test/inspection_test.dart test/officer_api_service_test.dart test/tracking_view_test.dart
```

### File yang berubah pada integrasi ini

- `lib/models/risk_score.dart`
- `lib/models/ticket_status.dart`
- `lib/models/user_model.dart`
- `lib/models/visit_schedule.dart`
- `lib/services/api_service.dart`
- `lib/services/officer_api_service.dart`
- `lib/views/officer/officer_dashboard_view.dart`
- `lib/views/officer/officer_detail_view.dart`
- `lib/views/public/main_shell.dart`
- `lib/views/public/tracking_view.dart`
- `test/inspection_test.dart`
- `test/officer_api_service_test.dart`
- `test/tracking_view_test.dart`
