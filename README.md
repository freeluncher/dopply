# Dopply App

[![Flutter](https://img.shields.io/badge/Flutter-3.7.0-blue?logo=flutter)](https://flutter.dev)
[![Build](https://img.shields.io/github/actions/workflow/status/freeluncher/dopply_app/flutter.yml?branch=main&label=build)](../../actions)
[![License](https://img.shields.io/github/license/freeluncher/dopply_app)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-green)](../../)
[![Pub](https://img.shields.io/pub/v/flutter_blue_plus?label=flutter_blue_plus)](https://pub.dev/packages/flutter_blue_plus)
[![Coverage](https://img.shields.io/badge/coverage-auto-brightgreen)](coverage/lcov.info)
[![Issues](https://img.shields.io/github/issues/freeluncher/dopply_app)](../../issues)
[![Stars](https://img.shields.io/github/stars/freeluncher/dopply_app?style=social)](../../stargazers)
[![Forks](https://img.shields.io/github/forks/freeluncher/dopply_app?style=social)](../../network/members)
[![Last Commit](https://img.shields.io/github/last-commit/freeluncher/dopply_app)](../../commits/main)

---

Aplikasi monitoring detak jantung janin (Fetal BPM) berbasis Flutter, terintegrasi ESP32 BLE, dengan fitur multi-role: **Admin**, **Dokter**, dan **Pasien**. Mendukung monitoring real-time, manajemen user, dan update aplikasi via Google Drive.

---

## ✨ Fitur Utama
- **Pasien:**
  - Koneksi BLE ke ESP32 untuk monitoring BPM real-time
  - Riwayat monitoring
  - Ubah email & password
- **Dokter:**
  - Monitoring BPM pasien real-time
  - Riwayat & manajemen pasien
  - Tambah/pilih pasien
  - Ubah email & password
- **Admin:**
  - CRUD user (tambah, edit, hapus)
  - Lihat daftar user
  - Ubah email & password
- **In-App Update:**
  - Cek versi & update APK otomatis via Google Drive
- **Robust BLE:**
  - Koneksi BLE Flutter <-> ESP32 dengan retry, error handling, dan widget test

---

## 🛠️ Teknologi
- **Flutter** 3.7+
- **Riverpod** state management
- **flutter_blue_plus** (BLE)
- **ESP32 Arduino** (BLE server)
- **FastAPI** (backend, opsional)

---

## 🚀 Cara Build APK
1. Install dependencies:
   ```powershell
   flutter pub get
   ```
2. Build APK release:
   ```powershell
   flutter build apk --release
   ```
3. APK ada di:
   ```
   build\app\outputs\flutter-apk\app-release.apk
   ```

---

## 📡 Koneksi ke ESP32 (BLE)
- Pastikan ESP32 menyala & advertising BLE dengan nama **Dopply-FetalMonitor**
- Tekan **Connect ESP32** di aplikasi
- Jika sukses, data BPM tampil real-time
- Jika disconnect, ESP32 otomatis advertising ulang

---

## 📁 Struktur Folder Penting
- `lib/features/patient/` : Fitur pasien
- `lib/features/doctor/`  : Fitur dokter
- `lib/features/admin/`   : Fitur admin
- `lib/core/`             : Service, utilitas, widget global
- `lib/app/`              : Router & tema
- `android/` & `ios/`     : Konfigurasi native

---

## 👨‍💻 Kontributor
- Developer: [freeluncher]
- Untuk pertanyaan/bantuan, hubungi via email/WA sesuai kesepakatan.

---

## ⚡️ Cara Setup & Install di Lokal

### 1. Clone Repository
Jika belum punya git, install dulu [Git](https://git-scm.com/downloads).

```bash
git clone https://github.com/freeluncher/dopply_app.git
cd dopply_app
```

### 2. Install Flutter SDK
Pastikan sudah install [Flutter](https://docs.flutter.dev/get-started/install) minimal versi 3.7.0.

```bash
flutter --version
```

### 3. Install Dependencies
Jalankan perintah berikut di root project:

```bash
flutter pub get
```

### 4. Setup Android/iOS (Opsional)
- **Android:**
  - Buka folder `android/` di Android Studio jika ingin build native.
  - File `local.properties` akan dibuat otomatis saat build, atau bisa di-generate manual jika perlu.
- **iOS:**
  - Buka folder `ios/` di Xcode.
  - Jalankan `pod install` di folder `ios/` jika ada error dependency.

### 5. Jalankan Project
- **Android:**
  ```bash
  flutter run -d android
  ```
- **iOS:**
  ```bash
  flutter run -d ios
  ```
- **Web:**
  ```bash
  flutter run -d chrome
  ```

### 6. Build APK/IPA (Release)
- **Android APK:**
  ```bash
  flutter build apk --release
  ```
- **iOS IPA:**
  ```bash
  flutter build ios --release
  ```

### 7. Troubleshooting
- Jika error dependency, jalankan:
  ```bash
  flutter clean
  flutter pub get
  ```
- Jika error pada Android Studio/VS Code, restart IDE.
- Jika error R8/proguard, cek `proguard-rules.pro` dan tambahkan aturan yang diperlukan.

### 8. Environment & Secrets
- Jika menggunakan file `.env` atau konfigurasi rahasia, pastikan file tersebut tidak di-commit ke repo (lihat `.gitignore`).
- Untuk API endpoint, cek file konfigurasi di `lib/core/`.
