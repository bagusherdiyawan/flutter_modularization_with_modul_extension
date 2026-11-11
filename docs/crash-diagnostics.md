# Diagnosis crash setelah menekan Unduh

Popup Android yang menyarankan clear cache bukan diagnosis akar masalah. Jangan menganggap cache sebagai penyebab tanpa log.

Build diagnosis menambahkan ikon bug di kanan atas halaman kasir:

1. Pasang update dari Play Internal Testing, tanpa menghapus data aplikasi.
2. Tekan ikon bug > Salin diagnosis, lalu simpan laporan awal.
3. Buka EDC > Unduh untuk mengulangi masalah.
4. Jika aplikasi tertutup, buka kembali > ikon bug > Salin diagnosis.
5. Kirim laporan sebelum dan sesudah, serta kode versi. Periksa isi laporan sebelum membagikan.

Laporan berisi versi aplikasi, model/Android/ABI, mapping loading unit, nama split dan library deferred yang terpasang, checkpoint pemuatan terakhir, serta Java stack terakhir jika tertangkap. Pada Android 11+ juga tersedia ringkasan riwayat proses berhenti. Tidak ada upload log otomatis, token, nomor pelanggan, atau data pembayaran yang sengaja dikumpulkan. Data diagnosis disimpan di private SharedPreferences. Timestamp adalah milidetik sejak Unix epoch.

Keterbatasan: crash native/SIGABRT tidak ditangkap handler Java. Ringkasan process exit bukan stack trace native; jika diperlukan gunakan `adb logcat -b crash -d`. Status `loading` hanya berarti checkpoint terakhir sebelum masuk pemuatan library; itu tidak membuktikan unduhan sudah dimulai atau selesai. Pemuatan mencakup pemasangan dan pemuatan kode, sehingga keduanya masih perlu dibedakan melalui log.

Perubahan ini adalah instrumentasi diagnosis, bukan perbaikan akar crash yang sudah terbukti. Perilaku pengiriman modul tetap sama. Jangan menonaktifkan deferred components, mengubah signing key, atau menghapus cache untuk menyamarkan crash.
