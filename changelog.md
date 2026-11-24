# Changelog

---

## Hyper Charging+ v2.1.1-viva (Redmi Note 11 Pro 4G Edition)

Pembaruan penyempurnaan fitur auto-update in-app Magisk, pembersihan notifikasi saat cabut charger, serta kenaikan plafon termal 67W Turbo Charge.

### Fitur Baru & Perbaikan Kritis:
- **Magisk In-App Auto-Update Terintegrasi**:
  - Penambahan metadata `updateJson` resmi yang terhubung ke repositori publik `ajwan14/Hyper-Charging-Release`.
  - Notifikasi dan tombol **Update** langsung muncul otomatis di aplikasi Magisk jika ada rilis versi baru.
- **Pembersihan Notifikasi Instan Saat Cabut Charger**:
  - Memperbaiki bug deteksi kabel yang sebelumnya membaca `/sys/class/power_supply/battery/present` (selalu 1 pada semua HP).
  - Menambahkan listener event Android OS `ACTION_POWER_DISCONNECTED` langsung di dalam companion APK Java (`ChargeNotificationService.java`). Notifikasi langsung lenyap seketika (1 milidetik) begitu kabel dicabut.
  - Memperbaiki deteksi arus pemakaian baterai (*discharging*) agar tidak terbaca sebagai arus pengisian.
- **Plafon Kecepatan 67W Turbo Charge Dinaikkan (6.5A Output)**:
  - Ambang batas kecepatan puncak Turbo dinaikkan dari 38.0°C ke **41.0°C** dengan batas arus hingga **6500mA (6.5A)**.
  - Pengisian daya jauh lebih cepat dan tidak mudah turun ke kecepatan rendah di suhu ruangan tropis.
  - Enforcer loop dipercepat ke 1.2 detik untuk mencegah daemon Xiaomi `mi_thermald` membatasi arus cas secara diam-diam.
  - Penambahan properti performa `persist.vendor.quickcharge=1` dan `ro.vendor.charging.boost=true`.
- **Optimalisasi Notifikasi MIUI / HyperOS**:
  - Target SDK companion APK disesuaikan ke API 33 untuk memotong batasan background execution Android 14/15.
  - Ikon notifikasi menggunakan aset PNG multi-density (`R.mipmap.ic_launcher`) yang kompatibel 100% dengan SystemUI semua ROM.
  - Channel notifikasi diatur ke `IMPORTANCE_DEFAULT` + `PRIORITY_HIGH` agar tidak dilipat/disembunyikan oleh HyperOS ke folder "Notifikasi Tidak Penting".

---

## Hyper Charging+ v2.1-viva (Redmi Note 11 Pro 4G Edition)

Pembaruan khusus yang dirancang dan disempurnakan untuk **Xiaomi Redmi Note 11 Pro 4G (`viva`, Helio G96 MT6781, 5000mAh, 67W Xiaomi Turbo Charge)**.

### Perbaikan Kritis & Optimasi
- **Mengatasi Cas Lambat (67W Restored)**: Menghilangkan target arus 12.65A yang memicu failsafe driver MediaTek ke 1A. Menerapkan profil arus 67W Xiaomi terukur (6.2A max) melalui jalur MediaTek MTK (`/proc/mtk_battery_cmd/current_cmd`, `fast_charge`, dan pelepasan limit thermal Xiaomi).
- **Notifikasi Stuck & Palsu Teratasi**: Layanan APK `com.hypercharge.service` otomatis dihentikan total (`am stopservice`) saat charger dicabut. Notifikasi langsung hilang bersih dari status bar.
- **Eliminasi Total Battery Drain (0% Idle Standby)**: Saat tidak dicas, loop tidur diperpanjang ke 10 detik, *dumpsys* dimatikan, dan subshell enforcer 0.3s dihapus total. CPU dapat memasuki Deep Sleep 100%.
- **Penamaan File Magisk Standar**: Mengubah semua nama file utama ke huruf kecil resmi (`customize.sh`, `module.prop`, `service.sh`) agar terdeteksi sempurna di filesystem Linux/Android ext4.
- **Proteksi Baterai Anti Micro-Cycling**: Menambahkan batas histeresis pengisian (setelah penuh, tidak akan mengecas lagi hingga kapasitas turun ke 94%), melindungi kesehatan sel baterai jangka panjang.
- **Kompatibilitas Universal**: Menambahkan dukungan otomatis untuk Magisk, KernelSU, dan APatch pada `update-binary` dan permission installer.
- **File Konfigurasi Pengguna**: Menambahkan `/data/adb/hypercharge/config.prop` untuk kustomisasi batas charge dan batas suhu tanpa harus mengedit kode script.

---

## Hyper Charging+ v2.0
...
