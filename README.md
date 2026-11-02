# SmartPOS — Flutter Deferred Components

Contoh aplikasi kasir Android dengan fitur **Pulsa/PPOB** dan **EDC** yang dikirim
sebagai Google Play Dynamic Feature Modules. Dibangun dari
[panduan implementasi](docs/design_reference.md).

## Perilaku aplikasi

- Toko reguler: kasir dan struk tunai demo tersedia di base. Total keranjang contoh
  Rp 150.000; belum ada manajemen inventori, printer Bluetooth, atau backend.
- Aktifkan fitur melalui sakelar konfigurasi toko. Mengaktifkan sakelar tidak
  mengunduh modul; tombol fitur memanggil `loadLibrary()` saat digunakan.
- Pulsa: pilih nominal atau token PLN, masukkan nomor pelanggan, validasi input,
  dan tampilkan konfirmasi simulasi. Tidak ada request provider atau pemotongan saldo.
- EDC: tampilkan proses simulasi, pembatalan, dan hasil bertanda `isSimulation`.
  Tidak ada pembayaran bank nyata atau SDK vendor yang disertakan.
- Loading mengunci interaksi kasir; kegagalan pemuatan menampilkan pesan dan dapat
  dicoba ulang. Callback asinkron memeriksa lifecycle halaman.

Konfigurasi toko hanya dalam memori. Produksi harus mengambil entitlement dari
backend dan memvalidasi otorisasi transaksi di server. Ukuran base 15 MB dalam
panduan merupakan ilustrasi, bukan hasil pengukuran proyek ini.

## Toolchain

- Flutter **3.32.8** / Dart **3.8.x** (`.fvmrc`).
- JDK **17** (Gradle 8.12 juga mendukung JDK 21).
- Android SDK Platform **35**, build tools, NDK **26.3.11579264**.
- AGP **8.7.3**, Kotlin **2.1.0**, Play Feature Delivery **2.1.0**, minSdk **23**.

Gunakan Flutter dari PATH atau `fvm flutter`. Android SDK/lisensinya harus tersedia
(`flutter doctor -v` dan `flutter doctor --android-licenses`). `local.properties`
dibuat lokal oleh Flutter; jangan commit SDK path atau signing key.

```bash
flutter --version
flutter pub get --enforce-lockfile
python3 tool/check_deferred.py
flutter analyze
flutter test
flutter run                     # Android emulator/device: pengembangan biasa
flutter build appbundle --release
python3 tool/check_deferred.py --aab build/app/outputs/bundle/release/app-release.aab
git diff --exit-code -- deferred_components_loading_units.yaml android/app/src/main/AndroidManifest.xml
```

Debug/widget tests tidak membuktikan instalasi split dari Play. `flutter build
appbundle` mengaktifkan deferred components dari `pubspec.yaml`. Jangan menggunakan
`--no-deferred-components` untuk menguji hasil delivery.

## Struktur dan isolasi

```text
lib/core/contracts/              kontrak hasil pembayaran bersama
lib/core/services/               konfigurasi toko dan gateway deferred
lib/features/pos_cashier/        UI base
lib/features/edc_module/         entry, dialog, simulator EDC
lib/features/pulsa_module/       entry dan dashboard Pulsa/PPOB
android/edcComponent/            dynamic feature + SDK vendor opsional
android/pulsaComponent/          dynamic feature Pulsa
assets/{core,edc_assets,pulsa_assets}/
```

Hanya `DeferredFeatureModules` di base mengimpor entry fitur dengan `deferred as`.
Jangan mengekspor atau mengimpor kode fitur secara eager dari base atau fitur lain.
Import biasa di dalam fitur yang sama aman. Import langsung pada `test/` hanya
berlaku pada entrypoint tes dan tidak ikut aplikasi rilis.

Setiap komponen Gradle menyertakan `deferred_libs` dan `deferred_assets` yang
**dihasilkan Flutter**. Manifest komponen memakai judul resource milik base,
`dist:on-demand`, dan `dist:fusing`. Mapping loading unit di manifest base serta
`deferred_components_loading_units.yaml` harus berasal dari compiler dan di-commit.
Jangan menebak ID loading unit. Bila pembagian berubah, Flutter akan gagal validasi
serta menulis konfigurasi yang disarankan di
`build/android_deferred_components_setup_files/`. Tinjau perubahan kode dan unit,
perbarui mapping dari output compiler, lalu build ulang. Jangan menerima perubahan
baseline otomatis di CI.

`tool/check_deferred.py` memeriksa batas import, deklarasi aset dan Android.
Dengan `--aab`, pemeriksaan juga memastikan library Dart `.part.so` serta aset
masing-masing fitur ada pada split yang benar dan tidak ada di base.

## Pengujian delivery Android

1. Build release AAB. Signing saat ini memakai debug key **khusus pengembangan**;
   siapkan applicationId dan upload keystore sendiri sebelum publikasi produksi.
2. Dengan Android ber-Google Play Services tersambung, gunakan bundletool resmi:

   ```bash
   java -jar bundletool.jar build-apks \
     --bundle=build/app/outputs/bundle/release/app-release.aab \
     --output=smartpos.apks --local-testing
   java -jar bundletool.jar install-apks --apks=smartpos.apks
   ```

3. Mulai dari instalasi bersih. Pastikan kasir tunai dapat dibuka. Aktifkan Pulsa,
   buka tombol fiturnya, amati download lalu tampilnya katalog. Ulangi untuk EDC.
   Uji mode offline sebelum modul pertama dimuat: pesan gagal harus muncul, dan
   retry setelah online harus berhasil. Modul yang sudah terpasang tidak perlu
   diunduh ulang. Menonaktifkan sakelar tidak menghapus split yang sudah terpasang.
4. Uji di Play Console Internal Testing/Internal App Sharing untuk memvalidasi
   delivery dari Google Play sesungguhnya. Distribusi lewat APK biasa/debug tidak
   setara dengan skenario ini. Publikasi Play dan pengujian perangkat dilakukan
   terpisah; tidak otomatis dilakukan oleh build atau workflow GitHub.

## SDK EDC nyata

Letakkan AAR berlisensi **hanya** di `android/edcComponent/libs/` (diabaikan Git).
`fileTree` komponen tersebut akan menyertakannya. Implementasikan adapter native
serta MethodChannel yang diregistrasikan setelah split terpasang, lalu ganti
`EdcService`. Jangan menambahkan dependensi vendor atau referensi kelas vendor pada
base. Penambahan AAR saja belum membuat simulator menjadi pembayaran nyata.
Pastikan pembatalan dan timeout diterapkan menurut protokol vendor sebelum
mengaktifkan transaksi sungguhan.

## CI

GitHub Actions menjalankan pemeriksaan isolasi, analyzer, widget/unit tests,
release app bundle, pemeriksaan isi AAB, dan pemeriksaan perubahan loading-unit
baseline. AAB serta laporan tes diunggah sebagai artifact; hasil CI harus dicek
pada commit yang relevan. Tidak ada deployment Play otomatis.

## Lingkungan cloud ini

Toolchain siap pakai tersedia melalui `tool/cloud.sh`, menggunakan image
`ghcr.io/cirruslabs/flutter:3.32.8` yang dipin dengan digest. Helper memulai ulang
container bila diperlukan, memakai checkout yang sama, serta memasang CA publik
proxy cloud ke trust store tanpa menonaktifkan TLS.

```bash
./tool/cloud.sh flutter pub get --enforce-lockfile
./tool/cloud.sh flutter analyze
./tool/cloud.sh flutter test
./tool/cloud.sh flutter build appbundle --release
python3 tool/check_deferred.py --aab build/app/outputs/bundle/release/app-release.aab
```

Pada container baru, pasang NDK dan build tools dengan `sdkmanager` melalui proxy
yang disediakan lingkungan sebelum build. Docker harus tersedia pada socket lokal;
proses container harus dimulai lagi setelah pemulihan snapshot. Untuk mesin lokal
tanpa proxy cloud, gunakan toolchain Flutter/Android biasa seperti di atas.
