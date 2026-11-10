# Uji Google Play Feature Delivery melalui Internal App Sharing

Package aplikasi: `com.pos.modularization`. Label: SmartPOS.
Target percobaan: membuktikan pemasangan modul Pulsa dan simulator EDC melalui Google Play, bukan pembayaran bank nyata.

## Persiapan artifact

Dari root checkout:

```bash
./tool/cloud.sh flutter analyze
./tool/cloud.sh flutter test
./tool/cloud.sh flutter build appbundle --release
python3 tool/check_deferred.py --aab build/app/outputs/bundle/release/app-release.aab
```

Build membutuhkan akses ke `storage.googleapis.com`, selain registry toolchain.
File untuk diunggah hanya tersedia jika build berhasil: `build/app/outputs/bundle/release/app-release.aab`.
Jangan menganggap file dari build lama sebagai hasil perubahan terbaru.
Signing debug saat ini khusus untuk pengujian Internal App Sharing, bukan untuk rilis produksi/Internal Testing yang menggunakan upload key.

## Unggah

1. Masuk Play Console menggunakan akun yang memiliki akses Internal App Sharing.
2. Buka Internal app sharing pada area pengujian aplikasi (nama/lokasi menu bisa berbeda menurut akun), atau halaman uploader resmi https://play.google.com/console/internal-app-sharing .
3. Atur akses penguji, unggah AAB, tunggu pemrosesan selesai, lalu salin tautan instalasi.
4. Bila Console menolak artifact, simpan pesan kesalahannya agar penyebabnya dapat diperiksa; jangan mengganti signing key atau applicationId secara sembarang.

## Pasang pada HP

1. Gunakan Android dengan Play Store dan akun penguji yang diizinkan.
2. Aktifkan Internal app sharing pada pengaturan Play Store. Bila opsi belum terlihat, ketuk Play Store version tujuh kali di Settings > About, lalu cari opsi pada pengaturan pengembang Play Store.
3. Untuk pengujian awal, hapus instalasi demo lama dengan package yang sama jika ada. Ini menghapus data demo lokal.
4. Buka tautan dan pasang melalui Google Play. Jangan memasang APK via adb untuk skenario delivery ini.

## Skenario penerimaan

- Buka kasir: tombol tunai tersedia, fitur tambahan belum aktif.
- Aktifkan EDC pada konfigurasi toko: belum memanggil loadLibrary.
- Klik EDC, pilih Batal pada dialog: tidak memulai pemuatan modul.
- Klik lagi, pilih Unduh: minta Google Play memasang komponen jika belum tersedia, lalu tampilkan simulator EDC.
- Buka lagi dalam sesi yang sama: dialog persetujuan tidak muncul setelah modul berhasil dimuat.
- Setelah proses aplikasi dimulai ulang, dialog dapat muncul kembali karena status persetujuan hanya dalam memori; Play menggunakan split yang sudah terpasang sehingga tidak harus mengunduh ulang.
- Ulangi untuk Pulsa dan buka halaman katalog simulasi.
- Pada instalasi bersih, uji pertama kali tanpa koneksi: error harus tampil dan retry online harus dapat dilakukan. Jangan menjadikan indikator loading sebagai satu-satunya bukti unduhan.

## Bukti split pada perangkat

Dengan USB debugging dan adb, setelah instalasi base dan setelah pemuatan masing-masing fitur, simpan hasil:

```bash
adb shell pm path com.pos.modularization
```

Bandingkan path APK split untuk `edcComponent` dan `pulsaComponent`. Nama/path akhir ditentukan packaging Google Play. Jika fitur sudah ikut terpasang sebelum digunakan, investigasi artifact dan metode instalasi; jangan menyimpulkan on-demand berhasil hanya karena halaman terbuka.

## Status persiapan 10 November 2026

Package ID dan dialog persetujuan telah diperbarui. Analyzer bersih dan 12 tes lulus.
Akses runtime cloud ke storage.googleapis.com masih menolak koneksi baru dengan HTTP 403 meskipun domain ada pada draft konfigurasi. AAB baru belum dinyatakan siap unggah. Perubahan domain harus diterapkan melalui pengaturan lingkungan, bukan hanya disetujui lewat chat.
