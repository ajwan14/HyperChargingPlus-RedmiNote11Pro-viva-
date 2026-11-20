# ⚡ Hyper Charging+ (Khusus Xiaomi Redmi Note 11 Pro 4G viva)

> [!IMPORTANT]
> 📱 **KHUSUS PERANGKAT: XIAOMI REDMI NOTE 11 PRO 4G (Codename: `viva`)**  
> Modul Magisk ini **KHUSUS & HANYA UNTUK XIAOMI REDMI NOTE 11 PRO 4G** (MediaTek Helio G96 MT6781, Baterai 5000mAh, 67W Xiaomi Mi Turbo Charge).  
> **JANGAN DIPASANG DI HP LAIN** karena kurva arus (6.2A / 67W) dan konfigurasi charging node kernel disetel presisi khusus untuk arsitektur PMIC & MediaTek Redmi Note 11 Pro 4G viva.

> [!NOTE]
> 🔗 **Repository Awal / Upstream Source:** [https://github.com/Demonx4y/Hyper-Charging-Plus](https://github.com/Demonx4y/Hyper-Charging-Plus)  
> Di-fork, direfaktorisasi, dan disempurnakan khusus untuk mengatasi isu cas lambat 67W, notifikasi stuck, dan battery drain pada Xiaomi Redmi Note 11 Pro 4G (`viva`).

![Hyper Charging+ Banner](banner.png)

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](#)
[![Device Exclusive](https://img.shields.io/badge/Device%20Exclusive-Redmi%20Note%2011%20Pro%204G%20(viva)-FF6900?logo=xiaomi&logoColor=white)](#)
[![SoC](https://img.shields.io/badge/Chipset-MediaTek%20Helio%20G96-0078D7)](#)
[![Battery & Charger](https://img.shields.io/badge/Battery-5000mAh%20%7C%2067W%20Turbo-red)](#)
[![Root Support](https://img.shields.io/badge/Root-Magisk%20%7C%20KernelSU%20%7C%20APatch-blue)](#)
[![License](https://img.shields.io/badge/License-GPLv3-green)](#)

---

## 🔋 Fitur Utama Khusus Redmi Note 11 Pro 4G (viva)

- **Optimasi Asli 67W Xiaomi & MediaTek**: Membuka profil fast charging melalui interface kernel MediaTek (`/proc/mtk_battery_cmd/current_cmd` dan `fast_charge`) tanpa nilai out-of-spec yang memicu failsafe driver.
- **Ladder Termal Anti-Flapping**: Tangga arus termal 6-tahap (6.2A hingga 1.2A) dilengkapi histeresis 0.8°C untuk mencegah pergantian profil terus-menerus.
- **Siklus Notifikasi Bersih**: Notifikasi live hanya aktif saat HP terhubung ke charger. Saat kabel dicabut, service APK dimatikan seketika dan notifikasi langsung hilang.
- **Nol Pemborosan Baterai Standby (100% Deep Sleep)**: Saat tidak dicas, interval polling diturunkan ke 10 detik dan semua panggilan *dumpsys* dihentikan. CPU HP bebas memasuki Deep Sleep.
- **Proteksi Baterai Anti Micro-Cycling**: Pengisian berhenti di 100% (atau batas konfigurasi pengguna) dan **tidak akan mengisi ulang sampai baterai turun ke 94%**, melindungi sel baterai dari degradasi akibat siklus 99%-100%.
- **Hardware Game Bypass**: Mode bypass MediaTek menahan panas saat bermain game sambil dicas.
- **Konfigurasi Pengguna**: File konfigurasi di `/data/adb/hypercharge/config.prop` untuk mengatur batas stop charge dan suhu cut-off.

---

## 🌡️ Tangga Termal 67W (viva)

| Rentang Suhu | Mode | Arus Target | Keterangan |
| :--- | :--- | :--- | :--- |
| < 38.0°C | **TURBO** | **6.20A** (6200mA) | Kecepatan penuh 67W saat baterai dingin |
| 38.0°C – 40.5°C | **HIGH** | **5.20A** (5200mA) | Pengisian cepat stabil |
| 40.5°C – 42.5°C | **BALANCED** | **4.20A** (4200mA) | Suhu hangat seimbang |
| 42.5°C – 44.5°C | **WARM** | **3.20A** (3200mA) | Mencegah penumpukan panas |
| 44.5°C – 46.5°C | **COOLING** | **2.00A** (2000mA) | Perlambatan suhu tinggi |
| 46.5°C – 47.9°C | **THROTTLE** | **1.20A** (1200mA) | Arus minimum pengaman |
| >= 48.0°C | **CUTOFF** | **0A** (Berhenti) | Cutoff darurat (pulih pada 44.0°C) |

*Tapering kapasitas baterai diterapkan di atas 85% (4.2A), 90% (3.2A), 95% (2.0A), dan 99% (1.0A).*

---

## ⚙️ Konfigurasi Kustom (`config.prop`)

File konfigurasi tersimpan di: `/data/adb/hypercharge/config.prop`

```properties
# Batas maksimal cas (60 - 100, default 100)
MAX_CHARGE_LIMIT=100

# Batas mulai cas kembali setelah penuh (default 94)
RECHARGE_THRESHOLD=94

# Suhu cut-off darurat (480 = 48.0°C)
MAX_TEMP_CUTOFF=480

# Suhu pemulihan cas (440 = 44.0°C)
RESTORE_TEMP=440

# Mode Game Bypass (1 = aktif, 0 = mati)
GAME_BYPASS_ENABLED=1
```

---

## 📦 Pemasangan

1. Unduh file rilis `.zip` dari menu **Releases**.
2. Buka aplikasi **Magisk**, **KernelSU**, atau **APatch** (juga bisa via TWRP / OrangeFox).
3. Masuk ke tab **Modules** > Klik **Install from storage**.
4. Pilih file zip modul, tunggu hingga proses selesai, lalu **Reboot**.
