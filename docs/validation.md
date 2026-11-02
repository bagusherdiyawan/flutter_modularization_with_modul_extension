# Hasil validasi implementasi

Validasi pada 2 November 2026 menggunakan Flutter 3.32.8 / Dart 3.8.1,
AGP 8.7.3, Gradle 8.12, dan JDK 21 pada toolchain container ber-digest tetap.

## Lulus

- `flutter pub get --enforce-lockfile`: dependency lockfile dapat diulang.
- `dart format --output=none --set-exit-if-changed lib test`: tidak ada perubahan.
- `flutter analyze`: no issues found.
- `flutter test --reporter expanded --concurrency=2`: **11 tes lulus**.
  Mencakup kasir reguler/tunai, aktivasi fitur tanpa download, deferred gateway,
  error/retry Pulsa dan EDC, lifecycle disposal, pilihan nominal, validasi nomor
  HP/PLN, hasil simulasi, dan pembatalan EDC.
- `python3 tool/check_deferred.py --loading-units`: batas import, aset, konfigurasi
  split Android, loading unit terpisah, dan mapping manifest konsisten.
- `flutter build appbundle --release`: **prebuild validation dan gen_snapshot
  validation lulus**. Compiler menghasilkan unit 2 untuk tiga library EDC dan
  unit 3 untuk dua library Pulsa. Baseline di root dihasilkan oleh compiler.
- Gradle wrapper diverifikasi dengan SHA-256 resmi; checksum distribusi dipin.

## Terblokir / belum dijalankan

Build AAB **belum berhasil**: resolusi dependensi `io.flutter:*_release` dari
`https://storage.googleapis.com/download.flutter.io/` ditolak proxy lingkungan
(HTTP 403). Ini terjadi setelah kompilasi AOT dan validasi loading unit selesai.
Domain `storage.googleapis.com` telah disimpan dalam draft pengaturan jaringan;
simpan perubahan pengaturan lingkungan untuk menerapkannya, lalu ulangi build.
Jangan melewati validasi deferred components atau verifikasi TLS.

Karena AAB belum terbentuk, `tool/check_deferred.py --aab`, `bundletool validate`,
instalasi split pada perangkat, dan Google Play Internal Testing **belum diuji**.
Workflow GitHub Actions disertakan untuk build dan pemeriksaan AAB, tetapi status
run CI harus diperiksa pada commit yang relevan; dokumen ini bukan klaim CI lulus.
SDK EDC vendor, backend Pulsa, signing produksi, dan akun Play tidak disertakan.
