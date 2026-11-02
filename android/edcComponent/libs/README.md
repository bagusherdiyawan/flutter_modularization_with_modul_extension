Tempatkan `vendor_edc_sdk.aar` yang berlisensi di direktori ini. File AAR diabaikan
Git dan hanya dipaketkan oleh `edcComponent`, bukan `app`. Tidak ada SDK vendor
pada contoh ini. Menambahkan AAR belum mengaktifkan pembayaran nyata: implementasikan
adapter native/MethodChannel dan registrasinya setelah split terpasang, ganti
`EdcService`, serta uji kegagalan, timeout, dan pembatalan sesuai kontrak vendor.
