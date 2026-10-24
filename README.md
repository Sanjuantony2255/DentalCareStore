# 🦷 Manjaly Multi Speciality Dental Care & Clinic Portal

A modern, comprehensive healthcare platform consisting of:
1. **Flutter Mobile Application (`dental_care_app`)**: Android APK with offline-first client architecture, patient records, appointment scheduling, billing calculator, official hospital invoices, revenue analytics, and pharmacy inventory.
2. **Web Clinic Portal**: Full responsive web portal backed by Google Apps Script and Google Sheets.
3. **Automated GitHub CI/CD**: Automatic Android Release APK compilation & distribution via GitHub Actions.

---

## 📱 Flutter Mobile Application (`dental_care_app`)

### ✨ Features
- **📋 Patient Registration & Revisit**: Add new patients or lookup returning patients via phone number with OP record tracking.
- **💳 Instant Billing & Receipts**: Auto-calculated consultation, radiology/X-ray, and pharmacy charges with printable receipt modals.
- **📅 Appointments Portal**: Today's schedule, upcoming consultations, and datewise filtering.
- **👥 Patients Directory**: Full clinical history timeline, past visit records, and telephone calling action.
- **📊 Accounts & Revenue**: Daily, weekly, monthly, and lifetime collections with category bars and transaction ledgers.
- **💊 Pharmacy & Inventory**: Real-time stock levels, expiring/low-stock alerts, and fast restock buttons.
- **⚡ Zero-Backend & Offline-Ready**: Persists all records locally using high-speed local storage, preloaded with seed records, with non-blocking Google Sheets sync when online.

### 🚀 Building the APK Locally
```bash
# Navigate to flutter project
cd dental_care_app

# Fetch dependencies
flutter pub get

# Run on connected phone or emulator
flutter run

# Build the release APK
flutter build apk --release --android-skip-build-dependency-validation
```
The compiled APK will be created at:
`dental_care_app/build/app/outputs/flutter-apk/app-release.apk`

---

## 🌐 Web Clinic Portal

A responsive web application for patient registration, revisit consultations, billing & invoices, appointment scheduling, and Google Calendar sync with daily push notifications, backed by Google Sheets, Google Drive, and Google Apps Script.

### 📋 Features
1. **Patient Registration & Revisit**: Capture patient demographics, date of birth, gender, disease history, and clinical visits.
2. **Billing & Invoices**: Consultation, X-Ray, pharmacy medicine charges, payment modes, and printable receipts.
3. **Registered Patients Directory**: (`patients.html`): Filter by name, phone, doctor, or billing status.
4. **Accounts & Revenue Dashboard**: (`accounts.html`): Daily, weekly, monthly, and lifetime collection analysis.
5. **Pharmacy & Stock Management**: (`pharmacy.html`): Inventory management and alerts.
6. **Appointments & Google Calendar Portal**: (`appointments.html`): View schedules and sync appointments.

---

## 📂 Project Structure

```
DentalCareStore/
├── .github/
│   └── workflows/
│       └── build_apk.yml          # GitHub Actions APK build & release CI/CD
├── .gitignore                     # Repository-wide ignore rules
├── build_apk.bat                  # 1-click Windows APK build script
├── dental_care_app/               # Flutter Mobile Application
│   ├── android/                   # Android native configuration (Gradle, Manifest)
│   ├── assets/images/             # Clinic logo and seal
│   ├── lib/
│   │   ├── main.dart              # App entry point
│   │   ├── theme/app_theme.dart   # Teal/Emerald healthcare branding
│   │   ├── models/                # Patient, Appointment, Invoice, Inventory models
│   │   ├── services/              # Offline storage service & API client
│   │   ├── screens/               # 6 core clinic screens
│   │   └── widgets/               # Reusable stat cards & invoice receipt dialogs
│   ├── test/                      # Unit tests for CI verification
│   └── pubspec.yaml               # Flutter package configuration
├── index.html                     # Web Portal Registration
├── appointments.html              # Web Portal Appointments
├── patients.html                  # Web Portal Patients Directory
├── search.html                    # Web Portal Search Records
├── accounts.html                  # Web Portal Accounts Dashboard
├── pharmacy.html                  # Web Portal Pharmacy
├── Code.gs                        # Google Apps Script Backend
└── README.md
```
