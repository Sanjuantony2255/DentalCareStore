# 🦷 Manjaly Dental Care - Mobile Clinic App (Flutter)

A modern, responsive, offline-first mobile healthcare application for **Manjaly Multi Speciality Dental Care & Surgery**, built with Flutter & Material 3.

---

## 🚀 Key Features

### 1. 📋 Patient Registration & Revisit
- Register new patients with full demographics (Name, Phone, Age, Gender, Address).
- Instant returning patient lookup via phone number.
- Record attending doctor, medical background, drug allergies, and chief dental complaints.
- Itemized charges calculation:
  - Doctor Consultation Charge (with 1-tap quick presets: Free, ₹200, ₹350, ₹500)
  - Dental X-Ray & RVG Examination (₹0, ₹200, ₹300, ₹500)
  - Pharmacy & Medicine charges
- Real-time automatic total calculation.
- Payment modes: **Cash**, **UPI / Online**, **Card**, **Payment Pending**.

### 2. 🧾 Instant Official Hospital Invoices
- Formatted with official clinic branding: **DENTAL CARE CLINIC & HOSPITAL - Manjaly Multi Speciality Dental Care**.
- Generates unique invoice codes (`INV-YYYY-XXXX`).
- One-tap invoice sharing via WhatsApp, SMS, or Email.

### 3. 📅 Appointments & Calendar Portal
- 4 dynamic views: **Today**, **Upcoming**, **Datewise Filter**, and **Full History**.
- Fast appointment booking modal with time slots and doctor assignment.
- Direct **Call Patient** phone action.
- Reschedule appointment with date/time pickers and reason log.
- One-tap status updates (Completed, Cancelled).

### 4. 👥 Registered Patients Directory
- Instant search by Name, Phone Number, or OP Record Number.
- Filter by Gender or Revisit status.
- Patient Medical Card with complete clinical visit timeline and lifetime billing totals.

### 5. 📊 Accounts & Revenue Dashboard
- 4 Core Metric cards: **Today's Collections**, **This Week**, **This Month**, and **Lifetime Revenue**.
- Dynamic period analysis filters.
- Revenue distribution by category with visual progress bars:
  - 🩺 Doctor Consultation
  - 🩻 Dental Radiology & X-Ray
  - 💊 Pharmacy / Medicines
- Payment mode distribution (Cash, UPI, Card, Pending).
- Itemized financial audit log.

### 6. 💊 Pharmacy & Dental Stock Inventory
- Real-time inventory overview: Total items, Low-stock alerts, Expiring soon (≤ 90 days), and Total valuation.
- Quick 1-tap `+` Restock and `-` Dispense buttons.
- Add new medicines, anesthetics, consumables, and dental materials.

---

## 🛡️ Zero Backend Dependency (Offline-First Architecture)

- **Self-Contained**: The application does NOT require any external backend server or database setup to run.
- **Local Persistence**: All patients, appointments, invoices, and inventory items persist locally on the device using `SharedPreferences`.
- **Pre-populated Demo Data**: Comes with realistic clinic seed data out of the box so you can test every feature immediately.
- **Optional Cloud Sync**: Pre-configured with an optional service layer for Google Apps Script Web App sync when online.

---

## 🛠️ How to Build the APK Locally

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0.0 or higher)
- Java JDK 17
- Android SDK (API 34)

### Commands
```bash
# 1. Navigate to mobile app directory
cd dental_care_app

# 2. Get dependencies
flutter pub get

# 3. Run on connected Android device / emulator
flutter run

# 4. Build release APK
flutter build apk --release
```

The compiled release APK will be located at:
`dental_care_app/build/app/outputs/flutter-apk/app-release.apk`

---

## 🤖 Automated GitHub Actions CI/CD Deployment

The repository includes `.github/workflows/build_apk.yml`. Every time you push code to GitHub:
1. GitHub Actions automatically checks out the repo and sets up Java 17 and Flutter.
2. Runs code analysis and unit tests.
3. Compiles the Android Release APK (`Manjaly-Dental-Care-v1.0.0.apk`).
4. Uploads the APK to the **GitHub Actions Artifacts** tab for instant download.
5. On version tags (e.g. `v1.0.0`), automatically creates a **GitHub Release** with the APK attached!
