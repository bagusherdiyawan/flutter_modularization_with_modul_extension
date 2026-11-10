# Upload key dan build Internal Testing

Package: `com.pos.modularization`. Upload key dibuat untuk aplikasi baru ini. Sertifikat self-signed upload adalah normal; Google Play App Signing akan mengelola app signing key yang berbeda.

## 1. Simpan key secara aman

Unduh arsip privat yang disediakan terpisah dari repository. Simpan backup terenkripsi di password manager/vault perusahaan. Jangan commit arsip, keystore, password, atau base64 ke Git. Jangan kirim isinya di chat atau issue. Kehilangan upload key memerlukan prosedur reset upload key melalui Play Console.

## 2. Isi GitHub Actions Secrets

Buka repository > Settings > Secrets and variables > Actions > New repository secret.
Buat empat secret berikut. Salin isi masing-masing file `.txt` dalam arsip privat dengan nama yang sama:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Untuk base64, salin satu baris nilainya saja; jangan unggah berkas JKS mentah sebagai nilai text.
Private key tidak dimasukkan ke artifact workflow.

## 3. Jalankan workflow khusus

Setelah perubahan kode tersedia pada GitHub, buka Actions > **Build Internal Testing AAB** > Run workflow > main.
Workflow manual ini membutuhkan keempat secret, gagal jika signing tidak lengkap, menjalankan tes, membangun AAB, dan memverifikasi signature terhadap sertifikat upload. Version code adalah 100 + nomor run workflow. Gunakan run baru untuk rilis baru; rerun run yang sama menghasilkan version code yang sama. Jika version code lebih tinggi sudah digunakan di Play, sesuaikan penomoran sebelum upload berikutnya.

Unduh artifact `smartpos-internal-testing-<nomor run>` dari run yang sukses, ekstrak, dan unggah `app-release.aab` ke Internal Testing. **Jangan mengambil AAB dari workflow Validate SmartPOS**: workflow validasi lama masih menggunakan debug signing.

## 4. Buat rilis Internal Testing

Buka aplikasi di Play Console > Testing > Internal testing. Atur tester, buat release, ikuti Play App Signing, lalu unggah AAB khusus Internal Testing. Untuk aplikasi baru, izinkan Google mengelola app signing key; jangan memilih opsi upload existing app signing key kecuali memang dibutuhkan dan dipahami.

Tambahkan release notes, selesaikan persyaratan Console yang muncul, lalu lakukan rollout internal. Bagikan tautan opt-in kepada tester, dan pasang aplikasi melalui Google Play. Pemeriksaan kebijakan/akun tetap berlaku; keberhasilan build bukan jaminan penerimaan Console.

Sertifikat publik `upload-certificate.pem` hanya diperlukan jika Console meminta upload certificate atau untuk verifikasi fingerprint. Berkas ini tidak berisi private key.

## Status

Key sudah dibuat dan diperiksa secara lokal. Workflow signing belum dijalankan di GitHub sampai secret diisi dan perubahan dipush. Tidak ada upload ke Play Console yang dilakukan otomatis.

## Target Android dan peringatan deobfuscation

Aplikasi dan kedua dynamic feature menggunakan compileSdk/targetSdk 36 serta minSdk 24. Workflow memasang Android SDK Platform 36 dan memakai AGP 8.10.1 dengan Gradle 8.12. Gunakan run workflow baru untuk memperbarui version code dan artifact; jangan mengunggah ulang bundle kode versi 104.

Peringatan deobfuscation di Play Console berbeda dari penolakan target SDK. Perintah build tidak memakai Dart --obfuscate, dan Flutter 3.32.8 menonaktifkan shrinking pada build deferred components ini. Karena itu file mapping R8 mungkin tidak dihasilkan. Jangan membuat mapping kosong atau mengaktifkan shrinking hanya untuk menghilangkan peringatan. Jika obfuscation ditambahkan di masa depan, simpan mapping/symbol yang benar dari build yang sama.

Target 36 mengaktifkan perubahan perilaku Android 16 yang relevan. Setelah build sukses, uji kasir, dialog, navigasi, Pulsa, dan EDC pada perangkat sebelum memperluas distribusi.
