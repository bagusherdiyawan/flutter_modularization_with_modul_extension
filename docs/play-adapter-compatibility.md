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
- Task Gradle `:app:verifyDeferredManagerAbi` memeriksa bytecode adapter yang benar-benar dihasilkan release build. Kedua workflow menjalankan task ini sebelum mengunggah artifact.
- Keberhasilan kompilasi lokal bukan bukti download modul pada perangkat. Full AAB/CI serta retest Play harus selesai sebelum klaim crash teratasi.

## Retest

Buat run baru Build Internal Testing AAB dari main, pastikan langkah pemeriksaan ABI lulus, unggah artifact bertanda tangan ke Play Internal Testing, dan update lewat Play Store. Jangan mengganti upload key atau applicationId.

Coba EDC dan Pulsa. Jika masih crash, buka kembali Diagnosis modul dan salin laporan. Build baru menampilkan `adapter=feature-delivery-2.1-gms-v1`. Periksa apakah split EDC sekarang muncul. Logcat native tetap diperlukan bila proses abort berlanjut tanpa Java stack.
