# AnyGamer

AnyGamer is a cross-platform Flutter application that transforms your mobile device into a highly customizable, low-latency virtual gamepad. Designed with immersive gaming in mind, the app supports multiple connection protocols and fully customizable HUD layouts.

## 🎮 Features

* **Multiple Controller Layouts:** Switch seamlessly between Xbox (A/B/X/Y) and PlayStation (Cross/Circle/Square/Triangle) configurations.


* **Advanced Control Mechanics:** Features pressure-sensitive triggers (LT/RT / L2/R2), clickable thumbsticks (L3/R3), and a responsive 8-way D-Pad.


* **Customizable UI & HUD:** Personalize your experience with an adjustable layout editor (drag to reposition buttons), visibility toggles for specific components, and dynamic accent colors (Cyan, Purple, Green, Orange, Red).


* **Precision Tuning:** Fine-tune thumbstick sensitivity and deadzones directly from the in-app settings overlay.


* **Multi-Protocol Connectivity:** Connect to your host machine via WiFi/TCP, Bluetooth (BLE), or USB Serial (includes built-in support for Arduino, FTDI, CP210x, CH340, and PL2303 receivers).


* **Haptic Feedback:** Integrated light and heavy haptic impacts for tactile button responses.



## 📸 Screenshots

| Xbox Layout | PlayStation Layout | Settings & Editor |
<img width="2408" height="1080" alt="Screenshot_20260626_234452" src="https://github.com/user-attachments/assets/3fde0ec7-c79a-4958-ba09-f7c3a207eaf2" />
<img width="2408" height="1080" alt="Screenshot_20260626_234422" src="https://github.com/user-attachments/assets/f4a5021a-e58a-46c9-a497-de8a7c1b7886" />
<img width="2408" height="1080" alt="Screenshot_20260626_234521" src="https://github.com/user-attachments/assets/4de668ab-52f1-49a7-904e-a48bc3f6a5b8" />



## 🚀 Getting Started

### Prerequisites

* **Flutter SDK:** Version 3.0 or higher (stable channel).


* **Android Development:** Android Studio, Android SDK 24+ (Target SDK 34).


* **iOS/macOS Development:** Xcode 15+, iOS 13.0+ / macOS 10.15+ deployment target.


---

### ⚙️ Installation

1. **Clone the Repository:**
```bash
git clone https://github.com/yourusername/gamepad_app.git
cd gamepad_app

```


2. **Fetch Dependencies:**
```bash
flutter pub get

```


3. **Run the App:**
```bash
flutter run

```



## 🔌 Connection Setup

CTRLFORGE offers three primary modes to bridge your mobile device to your host PC. Ensure your PC is running the corresponding host-side receiver application.

### 1. Wi-Fi / TCP Mode

* Open the CTRLFORGE **Settings** menu.
* Select the **WIFI** toggle.
* Enter your PC's local IP Address (e.g., `192.168.1.100`) and the designated Port (default is `5000`).
* Tap **CONNECT**. The app will also attempt UDP auto-discovery if supported by your receiver.

### 2. Bluetooth (BLE / SPP)

* Ensure your mobile device is paired with your PC via your phone's native Bluetooth settings.
* In the CTRLFORGE **Settings** menu, select the **BT** toggle.
* Select your paired PC from the **SELECT PAIRED DEVICE** list.
* The connection will establish automatically.

### 3. USB (ADB Tunnel)

* Enable **USB Debugging** in your Android Developer Options and connect your phone to the PC via a USB cable.
* On your PC terminal, forward the TCP port:
```bash
adb forward tcp:5000 tcp:5000

```


* In the app **Settings**, select the **USB** toggle and tap **CONNECT**.

## 🛠️ Tech Stack & Architecture

* **Framework:** Flutter (Dart)
* **State Management:** Provider (`LayoutNotifier`, `SettingsNotifier`, `ThemeNotifier`)
* **Data Persistence:** SharedPreferences
* **Networking:** `dart:io` (TCP/UDP sockets)
* **Hardware Integration:** `flutter_bluetooth_serial` (Classic SPP), `usb_serial` (USB Host/Accessory)

## 🤝 Contribution

Contributions, issues, and feature requests are welcome. Feel free to check the issues page if you want to contribute.

## 📝 License

This project is open-source and available under standard copyright (2026). See the underlying configuration files for specific plugin licenses.



