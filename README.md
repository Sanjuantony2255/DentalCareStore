# Patient Registration and Revisit + Billing & Invoices + Appointments & Calendar Portal

A responsive web application for patient registration, revisit consultations, billing & invoices, appointment scheduling, and Google Calendar sync with daily push notifications, backed by Google Sheets, Google Drive, and Google Apps Script.

## 📋 Features

### 1. Patient Registration & Revisit
- Capture patient demographics, date of birth, gender, disease history, and clinical visits.
- Automatically handles new registrations and return patient revisits.

### 2. Billing & Invoices
- **Clinical Charges**:
  - Consultation Charge
  - X-Ray Examination Charge
  - Pharmacy / Medicines Charge
- **Real-time Total Calculation**: Instant computation of total charges.
- **Payment Modes**: Cash, UPI / Online, Card, Payment Pending.
- **Dedicated Invoices Tab**: Automatically recorded in the `Invoices` sheet as well as patient visit history.
- **Google Drive Storage**: Invoices automatically stored as clean HTML documents in the `Patient Invoices` folder in Google Drive.
- **Print & Download**: 1-click printable receipt and downloadable standalone file.

### 3. Registered Patients Directory & Profiles (`patients.html`)
- **Directory Overview**: Browse all registered patients with total patient counter, total visits, and billing totals.
- **Filters & Search**: Instant real-time filtering by patient name, phone number, gender, doctor, or billing status.
- **View Patient**: Dedicated modal showing complete patient profile, medical history, past visits timeline, and billing receipts.
- **Quick Actions**: 1-click shortcuts to schedule an appointment or inspect complete clinical records.

### 4. Accounts & Revenue Dashboard (`accounts.html`)
- **Daily, Weekly, Monthly & Lifetime Collections**: Track revenue across periods with 1-click period filters.
- **Revenue by Category**:
  - 🩺 Doctor Consultation collections & average fee
  - 🩻 X-Ray & Radiology collections & scan volume
  - 💊 Pharmacy / Medicines collections & bill averages
  - Visual category progress bars with percentage distributions
- **Payment Mode Breakdown**: Collections for Cash, UPI / Online, Debit/Credit Card, and Pending payments.
- **Billing Transaction Ledger**: Itemized audit log of all clinical visits with patient names, phone numbers, and direct invoice links.
- **Export & Print**: Printable financial summary report and 1-click CSV download.

### 5. Pharmacy & Stock Management (`pharmacy.html`)
- **Inventory Overview**: Real-time counters for Total Items, Low Stock Alerts, Expiring Soon (≤ 90 days), and Total Stock Valuation.
- **Stock Catalog**: Item ID, medicine name, category, batch number, expiry date, unit price, stock quantity, and status.
- **Add Stock**: Modal to add new medicines, dental materials, anesthetics, and consumables.
- **Quick Adjustment**: Quick `+` restock and `-` dispense action buttons.
- **Filters & Search**: Filter by Low Stock, Expiring Soon, In Stock, or by medical category.

### 6. Patient Records & Invoice History (`search.html`)
- **Robust Search**: Search patient records by full name, phone number (with fuzzy 10/12-digit Indian country-code normalization), email, doctor name, or invoice number (e.g. `INV-...`).
- **Direct Invoice Opening**: When redirected from Registered Patients or Accounts, automatically searches and immediately opens the patient's invoice.
- **Hospital Name Header**: Prominently displays **DENTAL CARE CLINIC & HOSPITAL** at the very top of all invoices for both screen view and official black-and-white printing.
- **Show / Add Invoice**: Add or edit billing charges on demand.

### 7. Appointments & Google Calendar Integration (`appointments.html`)
- **Connected Calendar**: Directly integrated with **`sanjuantony01@gmail.com`** for real-time calendar syncing and push alerts.
- **Instant Email Alerts**: Direct email notification sent to `sanjuantony01@gmail.com` for each booked or rescheduled appointment with 1-click Google Calendar add button.
- **Google Calendar Sync**:
  - Top **Sync with Google Calendar** button to batch sync all appointments to `sanjuantony01@gmail.com` Google Calendar.
  - Direct **Calendar** button on each appointment card to open and add the appointment into Google Calendar on mobile or desktop with 1 click.
  - Automatically creates and updates Google Calendar events with **daily push notifications and reminders** (24 hours before, 1 hour before, 15 minutes before).
- **Upcoming Appointments View**: Dedicated "Upcoming" tab displaying all future appointments sorted by date.
- **Datewise Filtering**: Pick any date or use quick buttons (`Today`, `Tomorrow`, `+2 Days`, `+1 Week`) to instantly inspect daily schedules.
- **Reschedule Feature**: Reschedule any appointment with a new date, time, doctor, and notes, automatically updating both Google Sheets and Google Calendar.
- **Status Tracking**: Mark appointments as `Completed` or `Cancelled`.

---

## ⚙️ Google Apps Script & Google Sheet Setup Guide

### 1. Connecting your Google Sheet
1. Open your Google Sheet in your web browser.
2. In the top menu, click **Extensions** > **Apps Script**.
3. Replace the entire content in `Code.gs` with the updated code from [`Code.gs`](file:///c:/Program%20Files%20%28x86%29/BlueStacks%20X/audio/nn/New%20folder/DentalCareStore-main/Code.gs).
4. Save the project (`Ctrl + S`).

*(If using a standalone Apps Script project at `script.google.com`, paste your Spreadsheet ID into `var SPREADSHEET_ID = "YOUR_SHEET_ID_HERE";` at line 11 of `Code.gs`)*.

---

### 2. Deploying the Web App (Crucial Step)
To ensure the web app can upload, reschedule, sync to Google Calendar, and search records from any browser without permission errors:

1. In the Google Apps Script editor, click the blue **Deploy** button (top right) > **Manage deployments**.
2. Click the pencil icon to edit your existing deployment (or click **New deployment** > **Web app**).
3. Under **Version**, select **New version** (⚠️ VERY IMPORTANT: always select "New version" so the latest Code.gs is executed).
4. Configure the following settings:
   - **Execute as**: **`Me (<your-email>)`**
   - **Who has access**: **`Anyone`** *(⚠️ IMPORTANT: Must be "Anyone", NOT "Only myself" or "Anyone with a Google Account")*.
5. Click **Deploy**.
6. If Google asks to review permissions:
   - Click **Review permissions**.
   - Select your Google account.
   - Click **Advanced** > **Go to Project (unsafe)**.
   - Click **Allow** (Grants permission to save files to Google Drive, create Calendar events, and append to Sheets).
7. Copy the **Web App URL** ending in `/exec`.
8. Ensure this URL matches `SCRIPT_URL` in `script.js`, `search.js`, `appointments.js`, and `patients.js`.
# manjalydentalcare
