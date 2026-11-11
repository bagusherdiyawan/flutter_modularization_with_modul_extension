# Perbaikan kompatibilitas Play Feature Delivery

## Bukti

Laporan perangkat Samsung SM-S711B API 36, kode versi 106, menunjukkan EDC masih pada tahap loading, belum ada split EDC terpasang, dan proses berhenti dengan native crash. Tidak ada Java stack. Laporan ini belum merupakan stack trace yang mengidentifikasi exception asli.

Pemeriksaan independen menemukan ketidakcocokan ABI yang nyata:

- Flutter 3.32.8 engine source dibuild menggunakan `com.google.android.play:core:1.8.0`.
- Bytecode `PlayStoreDeferredComponentManager` dalam flutter.jar memanggil `SplitInstallManager.startInstall(...)` yang mengembalikan `com.google.android.play.core.tasks.Task`.
- Aplikasi memakai `feature-delivery:2.1.0`, yang mengembalikan `com.google.android.gms.tasks.Task`.
- Return type adalah bagian descriptor metode JVM; perbedaan ini dapat menyebabkan linkage error pada pemanggilan instalasi dari JNI dan penghentian proses. Dart try/catch tidak dapat menjamin penanganan abort native.

Ketidakcocokan tersebut sudah dibuktikan melalui javap, tetapi hasil perbaikan pada perangkat tetap harus diuji. Jangan menyatakan ini satu-satunya penyebab sebelum retest.

## Implementasi

`SmartPosApplication` mewarisi SplitCompatApplication dan menginjeksi DeferredComponentManager melalui FlutterInjector, titik ekstensi yang disediakan Flutter. Manifest base menggunakan application tersebut.

`SmartPosDeferredComponentManager` diadaptasi dari implementasi resmi Flutter 3.32.8 dan dikompilasi sebagai source aplikasi terhadap Feature Delivery 2.1.0. Adapter berada di source set `src/main/modernPlay`; bukan mengganti engine atau menambahkan Play Core lama. Lisensi BSD Flutter disertakan di sebelah source.

Perubahan tambahan menangani splitSourceDirs yang null dan nama APK Play yang berawalan `split_<component>`. Mapping loading-unit dan batas deferred Dart tidak diubah. Adapter perlu ditinjau ulang saat Flutter atau Feature Delivery diperbarui, termasuk dukungan konfirmasi sistem Play yang belum ditingkatkan dari perilaku adapter upstream.

## Validasi

- Source adapter Java berhasil dikompilasi terhadap Android SDK lokal dan dependency resmi Google.
- Bytecode baru memakai GMS Tasks dan tidak memiliki referensi Tasks Play Core lama.
- Task Gradle `:app:verifyDeferredManagerAbi` memeriksa bytecode adapter yang benar-benar dihasilkan release build. Task menjadi dependency `bundleRelease`, sehingga berjalan di dalam satu pemanggilan `flutter build appbundle`. Workflow tidak memanggil ulang Gradle tanpa properti deferred-components.
- Keberhasilan kompilasi lokal bukan bukti download modul pada perangkat. Full AAB/CI serta retest Play harus selesai sebelum klaim crash teratasi.

## Retest

Buat run baru Build Internal Testing AAB dari main, pastikan langkah pemeriksaan ABI lulus, unggah artifact bertanda tangan ke Play Internal Testing, dan update lewat Play Store. Jangan mengganti upload key atau applicationId.

Coba EDC dan Pulsa. Jika masih crash, buka kembali Diagnosis modul dan salin laporan. Build baru menampilkan `adapter=feature-delivery-2.1-gms-v2`. Periksa apakah split EDC sekarang muncul. Logcat native tetap diperlukan bila proses abort berlanjut tanpa Java stack.

## Urutan build dan baseline

Pemanggilan `./gradlew :app:verifyDeferredManagerAbi` secara terpisah sebelumnya ikut menjalankan `compileFlutterBuildRelease`. Flutter Gradle Plugin 3.32.8 menetapkan deferred-components=false jika properti tidak dikirim. Build kedua ini berbeda dari build deferred awal dan dapat menginvalidasi output build Flutter, termasuk baseline yang dipantau sebagai output validator.

Verifikasi ABI kini menjadi bagian dependency bundleRelease pada build Flutter yang sama. Baseline diperiksa sebelum dan sesudah build; pemisahan kode, isi AAB, dan tanda tangan tetap diperiksa. Tidak ada pemulihan baseline otomatis, pengabaian validasi, atau penerimaan baseline baru secara diam-diam.

## Modul sudah terpasang tetapi pemuatan menggantung (kode versi 108)

Laporan perangkat menunjukkan kedua split beserta library ARM64 ada, checkpoint Dart masih `loading`, dan proses terakhir berhenti karena remove task (reason 10), bukan crash baru. Adapter kini memuat aset/library langsung bila getInstalledModules sudah memuat komponen. Session 0 juga diselesaikan tanpa menunggu event INSTALLED baru.

Pending request diregistrasikan sebelum startInstall, sehingga event INSTALLED yang mendahului success callback tetap dapat diproses melalui moduleNames. Unit-unit yang menunggu instalasi komponen yang sama diselesaikan tanpa instalasi berulang; pembatalan dan kegagalan memberi tahu Dart. Adapter juga merekam nativeState, session, byte count, dan tahap pemuatan library secara lokal.

Sembilan skenario callback regresi JVM dan satu regresi path APK menjalankan DeferredInstallCoordinator produksi melalui `python3 tool/test_deferred_install.py`. Kedua workflow menjalankannya sebelum build. Ini menguji koordinasi callback, bukan menggantikan uji Google Play dan perangkat. Bila masih menggantung, diagnosis v2 adapter akan menunjukkan apakah proses berhenti pada event Play, pemuatan aset, atau pengajuan library ke FlutterJNI.

### Path dlopen dalam APK

Adapter upstream membentuk `apk!lib/ABI/library.so`, sedangkan pemuatan ZIP oleh linker Android memerlukan `apk!/lib/ABI/library.so`. Adapter kini menggunakan helper DeferredLibraryPath dengan separator yang benar. Regresi membuat ZIP APK berisi entri library dan memastikan path helper dapat dipecah menurut sintaks linker untuk menemukan entri yang benar.

Source JNI Flutter memanggil dlopen langsung. Bila semua path gagal, jalur LoadLoadingUnitFailure pada versi engine ini belum menyampaikan kegagalan ke Dart secara lengkap (TODO pada PlatformViewAndroid). Karena itu kesalahan path bisa tampak sebagai loading tanpa akhir, bukan hanya pesan error. Perbaikan path dilakukan tanpa mengubah engine. Keberhasilan pemuatan tetap harus dibuktikan pada perangkat.
