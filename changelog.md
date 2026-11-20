# Changelog

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
