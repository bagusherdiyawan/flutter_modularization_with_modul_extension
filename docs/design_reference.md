# Dokumentasi Teknis: Implementasi Flutter Deferred Components
**Studi Kasus: Aplikasi Point of Sales (POS) dengan Modul On-Demand (EDC & Pulsa/PPOB)**

---

## 1. Gambaran Umum & Skenario Real Case

### Skenario Bisnis (*Real Case*)
Anda membangun aplikasi kasir bernama **SmartPOS**. Anda memiliki ribuan *merchant* (toko) dengan karakteristik berbeda:
1. **Toko Reguler (70% User):** Hanya butuh fitur kasir dasar (input barang, hitung kembalian, cetak struk Bluetooth standar). Mereka memakai HP Android biasa dan sensitif terhadap ukuran aplikasi.
2. **Toko Agen Digital (20% User):** Butuh fitur jualan **Pulsa, Paket Data, dan Token Listrik (PPOB)** yang memiliki banyak aset ikon operator dan halaman form khusus.
3. **Toko Retail Modern (10% User):** Memiliki mesin **EDC fisik** dan membutuhkan modul integrasi EDC (beserta *Native SDK* `.aar` dari vendor bank/mesin EDC yang ukurannya cukup besar).

### Tujuan Arsitektur
* Saat toko mengunduh **SmartPOS** dari Google Play Store, mereka hanya mengunduh **Base APK** (ukuran $\approx 15\text{ MB}$).
* Jika toko mengaktifkan fitur **Pulsa** atau **EDC** di pengaturan akun mereka, aplikasi akan meminta Google Play mengunduh modul tersebut secara *on-the-fly* (tanpa keluar dari aplikasi).
* Jika toko tidak pernah memakai EDC atau Pulsa, modul tersebut **tidak akan pernah diunduh** ke HP mereka.

---

## 2. Struktur Direktori Proyek

Agar pemisahan modul berjalan mulus dan tidak terjadi kebocoran dependensi (*dependency leak*), struktur proyek harus dirancang terisolasi seperti berikut:

```text
smart_pos/
├── android/
│   ├── app/                                  # Base Module Android
│   │   ├── src/main/AndroidManifest.xml
│   │   └── build.gradle
│   ├── edcComponent/                         # Dynamic Feature Module: EDC
│   │   ├── libs/
│   │   │   └── vendor_edc_sdk.aar            # Native SDK EDC ditaruh di sini (bukan di app/)
│   │   ├── src/main/AndroidManifest.xml
│   │   └── build.gradle
│   ├── pulsaComponent/                       # Dynamic Feature Module: Pulsa
│   │   ├── src/main/AndroidManifest.xml
│   │   └── build.gradle
│   ├── build.gradle
│   └── settings.gradle
├── assets/
│   ├── core/                                 # Aset aplikasi utama
│   ├── edc_assets/                           # Aset khusus EDC (panduan colok mesin, dll)
│   └── pulsa_assets/                         # Aset khusus Pulsa (logo Telkomsel, PLN, dll)
├── lib/
│   ├── core/
│   │   ├── contracts/                        # Interface komunikasi antar modul
│   │   │   └── payment_result.dart
│   │   └── services/
│   │       └── store_config_service.dart
│   ├── features/
│   │   ├── pos_cashier/                      # Fitur inti (selalu ikut di Base APK)
│   │   │   └── cashier_page.dart
│   │   ├── edc_module/                       # TERISOLASI: Hanya di-import pakai 'deferred as'
│   │   │   ├── edc_entry.dart
│   │   │   ├── edc_service.dart
│   │   │   └── edc_payment_dialog.dart
│   │   └── pulsa_module/                     # TERISOLASI: Hanya di-import pakai 'deferred as'
│   │       ├── pulsa_entry.dart
│   │       └── pulsa_dashboard_page.dart
│   └── main.dart
├── deferred_components_loading_units.yaml    # Dihasilkan otomatis oleh Flutter saat validasi
└── pubspec.yaml
```

---

## 3. Langkah-Langkah Implementasi

### Langkah 1: Konfigurasi `pubspec.yaml`
Buka `pubspec.yaml` dan daftarkan `deferred-components` di bawah blok `flutter:`. Pastikan aset khusus modul juga didaftarkan di dalam komponennya masing-masing.

```yaml
name: smart_pos
description: Aplikasi POS Modular dengan Deferred Components.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0

flutter:
  uses-material-design: true

  # Aset inti yang selalu dibawa sejak awal instalasi
  assets:
    - assets/core/

  # Definisi Modul On-Demand (Deferred Components)
  deferred-components:
    - name: pulsaComponent
      libraries:
        - package:smart_pos/features/pulsa_module/pulsa_entry.dart
      assets:
        - assets/pulsa_assets/

    - name: edcComponent
      libraries:
        - package:smart_pos/features/edc_module/edc_entry.dart
      assets:
        - assets/edc_assets/
```

---

### Langkah 2: Konfigurasi Android Native (`android/`)

Agar Google Play Store mengenali pecahan modul Anda, Anda harus membuat *Dynamic Feature Module* di level Gradle Android.

#### A. Edit `android/settings.gradle`
Daftarkan nama komponen sama persis dengan yang ada di `pubspec.yaml`:

```groovy
include ':app', ':pulsaComponent', ':edcComponent'
```

#### B. Edit `android/app/build.gradle`
Tambahkan dependensi Google Play Feature Delivery dan deklarasikan `dynamicFeatures`:

```groovy
android {
    namespace "com.example.smart_pos"
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.example.smart_pos"
        minSdkVersion 23
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    // Daftarkan modul dinamis di sini
    dynamicFeatures = [':pulsaComponent', ':edcComponent']
}

dependencies {
    // Wajib untuk mengunduh komponen dari Play Store saat runtime
    implementation "com.google.android.play:feature-delivery:2.1.0"
}
```

#### C. Update `android/app/src/main/AndroidManifest.xml`
Ubah `android:name` pada tag `<application>` agar menggunakan `PlayStoreDeferredComponentManager` milik Flutter:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.smart_pos">

    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:label="SmartPOS"
        android:name="io.flutter.embedding.android.FlutterPlayStoreSplitApplication"
        android:icon="@mipmap/ic_launcher">
        <!-- Activity utama seperti biasa -->
    </application>
</manifest>
```

#### D. Buat Folder Modul `android/pulsaComponent/` & `android/edcComponent/`
Buat folder baru `android/pulsaComponent/` dan isi dengan 2 file berikut:

1. **`android/pulsaComponent/build.gradle`**:
```groovy
plugins {
    id "com.android.dynamic-feature"
}

android {
    namespace "com.example.smart_pos.pulsaComponent"
    compileSdkVersion 34

    defaultConfig {
        minSdkVersion 23
    }
}

dependencies {
    implementation project(":app")
}
```

2. **`android/pulsaComponent/src/main/AndroidManifest.xml`**:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:dist="http://schemas.android.com/apk/distribution"
    package="com.example.smart_pos.pulsaComponent">

    <dist:module
        dist:instant="false"
        dist:title="Modul Pulsa dan PPOB">
        <dist:delivery>
            <!-- on-demand berarti TIDAK diunduh saat install awal -->
            <dist:on-demand />
        </dist:delivery>
        <dist:fusing dist:include="true" />
    </dist:module>
</manifest>
```

*(Lakukan hal yang sama untuk `android/edcComponent/`. Jika modul EDC membutuhkan file `.aar` dari bank/vendor, masukkan `implementation files('libs/vendor_edc_sdk.aar')` di dalam `android/edcComponent/build.gradle` agar SDK tersebut ikut terpisah dari aplikasi utama).*

---

### Langkah 3: Implementasi Kode Dart (Real Case)

Aturan terpenting di Dart: **Jangan pernah mengimpor file apa pun dari dalam folder `edc_module` atau `pulsa_module` tanpa kata kunci `deferred as`**.

#### 1. Buat Kontrak Data Bersama (`lib/core/contracts/payment_result.dart`)
File ini berada di `core/` sehingga boleh diakses oleh Base APK maupun modul EDC.

```dart
class EdcPaymentResult {
  final bool isSuccess;
  final String approvalCode;
  final String cardNumberMasked;
  final String errorMessage;

  EdcPaymentResult({
    required this.isSuccess,
    this.approvalCode = '',
    this.cardNumberMasked = '',
    this.errorMessage = '',
  });
}
```

#### 2. Buat Pintu Masuk Modul Pulsa (`lib/features/pulsa_module/pulsa_entry.dart`)
Semua halaman dan logika bisnis pulsa dibungkus melalui satu pintu masuk (*entry point*).

```dart
import 'package:flutter/material.dart';

class PulsaEntryPoint extends StatelessWidget {
  final String storeId;

  const PulsaEntryPoint({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Pulsa & PPOB'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ID Toko Aktif: $storeId', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Nomor HP Pelanggan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(label: const Text('Rp 10.000'), selected: true, onSelected: (_) {}),
                ChoiceChip(label: const Text('Rp 25.000'), selected: false, onSelected: (_) {}),
                ChoiceChip(label: const Text('Rp 50.000'), selected: false, onSelected: (_) {}),
                ChoiceChip(label: const Text('Token PLN 20k'), selected: false, onSelected: (_) {}),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Memproses pengisian pulsa ke server...')),
                );
              },
              child: const Text('Beli Pulsa Sekarang'),
            )
          ],
        ),
      ),
    );
  }
}
```

#### 3. Buat Pintu Masuk Modul EDC (`lib/features/edc_module/edc_entry.dart`)
Modul ini menangani komunikasi dengan mesin EDC dan mengembalikan `EdcPaymentResult` ke halaman kasir utama.

```dart
import 'package:flutter/material.dart';
import '../../core/contracts/payment_result.dart';

class EdcEntryPoint {
  /// Menampilkan dialog instruksi gesek kartu dan memanggil SDK EDC
  static Future<EdcPaymentResult?> processEdcPayment(
    BuildContext context, {
    required int amount,
    required String invoiceNumber,
  }) async {
    return showDialog<EdcPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EdcProcessingDialog(
        amount: amount,
        invoiceNumber: invoiceNumber,
      ),
    );
  }
}

class _EdcProcessingDialog extends StatefulWidget {
  final int amount;
  final String invoiceNumber;

  const _EdcProcessingDialog({
    required this.amount,
    required this.invoiceNumber,
  });

  @override
  State<_EdcProcessingDialog> createState() => _EdcProcessingDialogState();
}

class _EdcProcessingDialogState extends State<_EdcProcessingDialog> {
  String _statusText = 'Menghubungkan ke mesin EDC...';

  @override
  void initState() {
    super.initState();
    _simulateEdcCommunication();
  }

  Future<void> _simulateEdcCommunication() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _statusText = 'Silakan Gesek / Tap Kartu pada Mesin EDC\nNominal: Rp ${widget.amount}');

    // Di dunia nyata, ini memanggil MethodChannel ke SDK .aar di folder android/edcComponent
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    Navigator.of(context).pop(
      EdcPaymentResult(
        isSuccess: true,
        approvalCode: 'APP-992817',
        cardNumberMasked: '4111-XXXX-XXXX-1234',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pembayaran Mesin EDC'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_statusText, textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(
              EdcPaymentResult(isSuccess: false, errorMessage: 'Dibatalkan oleh kasir'),
            );
          },
          child: const Text('Batalkan'),
        ),
      ],
    );
  }
}
```

#### 4. Panggil Modul secara Dinamis di Halaman Utama Kasir (`lib/features/pos_cashier/cashier_page.dart`)
Di sinilah keajaiban `deferred as` dan `loadLibrary()` bekerja.

```dart
import 'package:flutter/material.dart';
import '../../core/contracts/payment_result.dart';

// PENTING: Gunakan 'deferred as' agar modul tidak ikut ter-bundle di Base APK
import '../pulsa_module/pulsa_entry.dart' deferred as pulsa_module;
import '../edc_module/edc_entry.dart' deferred as edc_module;

class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  // Simulasi konfigurasi dari backend untuk toko yang sedang login
  bool _storeUsesPulsa = true;
  bool _storeUsesEdc = true;

  bool _isDownloadingModule = false;
  String _downloadMessage = '';

  /// Fungsi untuk mengunduh & membuka modul Pulsa
  Future<void> _openPulsaFeature() async {
    setState(() {
      _isDownloadingModule = true;
      _downloadMessage = 'Menyiapkan modul Pulsa & PPOB...';
    });

    try {
      // Meminta Play Store mengunduh modul pulsaComponent jika belum terinstal
      await pulsa_module.loadLibrary();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => pulsa_module.PulsaEntryPoint(storeId: 'STORE-JOGJA-01'),
        ),
      );
    } catch (e) {
      _showError('Gagal mengunduh modul Pulsa: $e');
    } finally {
      if (mounted) setState(() => _isDownloadingModule = false);
    }
  }

  /// Fungsi untuk mengunduh & menjalankan pembayaran via Mesin EDC
  Future<void> _payWithEdc(int totalBill) async {
    setState(() {
      _isDownloadingModule = true;
      _downloadMessage = 'Mengunduh driver & modul Mesin EDC...';
    });

    try {
      // Meminta Play Store mengunduh modul edcComponent saat pertama kali dipakai
      await edc_module.loadLibrary();

      if (!mounted) return;
      setState(() => _isDownloadingModule = false);

      // Panggil fungsi dari modul EDC yang sudah berhasil diunduh
      final EdcPaymentResult? result = await edc_module.EdcEntryPoint.processEdcPayment(
        context,
        amount: totalBill,
        invoiceNumber: 'INV-20261101-001',
      );

      if (result != null && result.isSuccess) {
        _showSuccess(
          'Pembayaran EDC Berhasil!\nApproval Code: ${result.approvalCode}\nKartu: ${result.cardNumberMasked}',
        );
      } else if (result != null) {
        _showError('Transaksi Gagal: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) setState(() => _isDownloadingModule = false);
      _showError('Gagal memuat modul EDC: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transaksi Sukses'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cetak Struk')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SmartPOS Kasir Utama')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Simulasi pengaturan fitur toko
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Konfigurasi Fitur Toko Ini:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SwitchListTile(
                          title: const Text('Aktifkan Fitur Jualan Pulsa (PPOB)'),
                          value: _storeUsesPulsa,
                          onChanged: (val) => setState(() => _storeUsesPulsa = val),
                        ),
                        SwitchListTile(
                          title: const Text('Toko Memiliki Mesin EDC'),
                          value: _storeUsesEdc,
                          onChanged: (val) => setState(() => _storeUsesEdc = val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Total Keranjang Belanja: Rp 150.000', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Tombol Bayar Tunai (Selalu ada di Base APK)
                ElevatedButton.icon(
                  icon: const Icon(Icons.money),
                  label: const Text('Bayar Tunai (Reguler)'),
                  onPressed: () => _showSuccess('Pembayaran Tunai Rp 150.000 Berhasil.'),
                ),
                const SizedBox(height: 12),

                // Tombol Bayar EDC (Hanya muncul jika toko pakai EDC, modul diunduh saat diklik)
                if (_storeUsesEdc)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Bayar Pakai Mesin EDC (On-Demand Module)'),
                    onPressed: () => _payWithEdc(150000),
                  ),

                const Divider(height: 40),

                // Menu Produk Digital / Pulsa (Hanya muncul jika toko mengaktifkan fitur Pulsa)
                if (_storeUsesPulsa)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bolt),
                    label: const Text('Buka Menu Pulsa & Token PLN (On-Demand Module)'),
                    onPressed: _openPulsaFeature,
                  ),
              ],
            ),
          ),

          // Loading Overlay saat Google Play sedang mengunduh modul
          if (_isDownloadingModule)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_downloadMessage, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

---

## 4. Proses Build, Validasi Loading Units, & Cara Testing

### A. Validasi Loading Units (`deferred_components_loading_units.yaml`)
Saat Anda menjalankan perintah build untuk pertama kali:

```bash
flutter build appbundle
```

Flutter akan menganalisis seluruh *dependency tree* Dart Anda dan menghasilkan file bernama **`deferred_components_loading_units.yaml`** di *root* project Anda.
* Buka file tersebut dan pastikan kode untuk `pulsa_module` dan `edc_module` terdaftar sebagai *loading unit* terpisah.
* **Simpan (commit) file `deferred_components_loading_units.yaml` ke Git.** Jika di kemudian hari ada anggota tim programmer Anda yang tidak sengaja mengimpor file EDC tanpa `deferred as`, proses build akan memberi *warning* bahwa ada perubahan *loading unit* (kode bocor ke Base APK).

### B. Cara Menguji (Testing) Tanpa Menunggu Rilis Resmi Play Store
Karena `flutter run` biasa akan menginstal semuanya sekaligus untuk kemudahan *debugging*, Anda memiliki 2 cara untuk menguji pengunduhan modul selayaknya di dunia nyata:

1. **Menggunakan `bundletool` (Testing Lokal Simulasi Split APK):**
   Unduh `bundletool` dari GitHub Google, lalu jalankan perintah berikut pada file `.aab` hasil build:
   ```bash
   java -jar bundletool.jar build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=smartpos.apks --local-testing
   java -jar bundletool.jar install-apks --apks=smartpos.apks
   ```
   Mode `--local-testing` akan menyimulasikan proses unduh Google Play dari penyimpanan lokal perangkat Anda sehingga Anda bisa mengetes alur *loading* `loadLibrary()`.

2. **Menggunakan Google Play Internal App Sharing / Internal Testing Track (Paling Akurat):**
   Unggah file `app-release.aab` ke **Google Play Console -> Internal Testing** atau **Internal App Sharing**. Bagikan tautannya ke HP testing Anda, instal dari Play Store, lalu klik tombol **Bayar Pakai Mesin EDC** atau **Buka Menu Pulsa**. Anda akan melihat modul terunduh langsung dari server Google Play dalam hitungan detik.

---

## 5. Checklist Keberhasilan Implementasi

- [ ] Tidak ada satu pun file di dalam `lib/features/edc_module/` atau `lib/features/pulsa_module/` yang diimpor secara langsung (tanpa `deferred as`) oleh `lib/main.dart` atau halaman utama lainnya.
- [ ] Kelas model data yang dipakai bersama (seperti `EdcPaymentResult`) sudah ditaruh di folder netral (`lib/core/contracts/`).
- [ ] File `.aar` khusus mesin EDC ditaruh di `android/edcComponent/libs/`, **bukan** di `android/app/libs/`.
- [ ] Pengguna target dipastikan menginstal aplikasi melalui **Google Play Store** (perangkat memiliki *Google Play Services*).