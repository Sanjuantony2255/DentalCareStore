import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/invoice.dart';

class ApiService {
  static const String spreadsheetId = '1MuzymftW2wzDV5C-ljLKXHo_NyqK6Xxp-PlI7pqbhls';
  static const String defaultScriptUrl =
      'https://script.google.com/macros/s/AKfycbyC1zFwfNFa8w-wLJGdEE9ladkNL2rZk-gIfx68CX76upxyQrI1Lar8Tb6BGEvLX4q0/exec';

  static const String patientsSheetCsvUrl =
      'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:csv';
  static const String appointmentsSheetCsvUrl =
      'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:csv&sheet=Appointments';
  static const String invoicesSheetCsvUrl =
      'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:csv&sheet=Invoices';

  /// Posts appointment to Google Apps Script / Google Calendar
  static Future<bool> syncAppointmentOnline(Appointment apt) async {
    try {
      final response = await http.post(
        Uri.parse(defaultScriptUrl),
        body: {
          'action': 'bookAppointment',
          'patientName': apt.patientName,
          'phone': apt.phone,
          'doctor': apt.doctor,
          'date': apt.date,
          'timeSlot': apt.timeSlot,
          'reason': apt.reason,
          'notes': apt.notes,
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  /// Posts patient registration and invoice to Google Apps Script & Google Sheet
  static Future<bool> syncRegistrationOnline(Patient patient, Invoice invoice) async {
    try {
      final response = await http.post(
        Uri.parse(defaultScriptUrl),
        body: {
          'action': 'registerPatient',
          'fullName': patient.name,
          'name': patient.name,
          'phone': patient.phone,
          'age': patient.age.toString(),
          'dob': patient.dob,
          'gender': patient.gender,
          'address': patient.address,
          'opNumber': patient.opNumber,
          'doctor': patient.doctor,
          'doctorConsulted': patient.doctor,
          'medicalHistory': patient.medicalHistory,
          'drugAllergies': patient.drugAllergies,
          'diseaseHistory': patient.diseaseHistory,
          'consultationCharge': invoice.consultationCharge.toString(),
          'xrayCharge': invoice.xrayCharge.toString(),
          'pharmacyCharge': invoice.pharmacyCharge.toString(),
          'totalAmount': invoice.totalAmount.toString(),
          'paymentMode': invoice.paymentMode,
          'invoiceNumber': invoice.id,
          'invoiceNo': invoice.id,
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  /// Parses CSV table data handling standard quoted cells and commas
  static List<List<String>> _parseCsv(String csv) {
    final List<List<String>> rows = [];
    final lines = const LineSplitter().convert(csv);

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final List<String> row = [];
      final matches = RegExp(r'(?:^|,)(?:"([^"]*(?:""[^"]*)*)"|([^",]*))').allMatches(line);
      for (final match in matches) {
        String cell = match.group(1) ?? match.group(2) ?? '';
        cell = cell.replaceAll('""', '"').trim();
        row.add(cell);
      }
      if (row.isNotEmpty) {
        rows.add(row);
      }
    }
    return rows;
  }

  /// Fetches live data from the connected Google Sheet
  static Future<Map<String, dynamic>> fetchGoogleSheetData() async {
    final List<Patient> patients = [];
    final List<Appointment> appointments = [];
    final List<Invoice> invoices = [];

    // 1. Fetch Patients Sheet
    try {
      final res = await http.get(Uri.parse(patientsSheetCsvUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final rows = _parseCsv(res.body);
        if (rows.length > 1) {
          // Skip header row
          for (int i = 1; i < rows.length; i++) {
            final r = rows[i];
            if (r.length < 3) continue;

            final name = r.length > 1 ? r[1].trim() : '';
            final phone = r.length > 2 ? r[2].trim() : '';
            if (name.isEmpty && phone.isEmpty) continue;

            final email = r.length > 3 ? r[3].trim() : '';
            final dob = r.length > 4 ? r[4].trim() : '';
            final gender = r.length > 5 && r[5].isNotEmpty ? r[5].trim() : 'Not Specified';
            final medHistory = r.length > 6 && r[6].isNotEmpty ? r[6].trim() : 'None';
            final diseaseHistory = r.length > 7 && r[7].isNotEmpty ? r[7].trim() : 'General Consultation';
            final lastVisit = r.length > 8 ? r[8].trim() : '';
            final doctor = r.length > 9 && r[9].isNotEmpty ? r[9].trim() : 'Dr. Sanju Antony';

            final consultCharge = r.length > 10 ? (double.tryParse(r[10].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final xrayCharge = r.length > 11 ? (double.tryParse(r[11].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final pharmCharge = r.length > 12 ? (double.tryParse(r[12].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final totalAmt = r.length > 13 ? (double.tryParse(r[13].replaceAll(RegExp(r'[^0-9.]'), '')) ?? (consultCharge + xrayCharge + pharmCharge)) : (consultCharge + xrayCharge + pharmCharge);
            final paymentMode = r.length > 14 && r[14].isNotEmpty ? r[14].trim() : 'UPI / Online';
            final invNo = r.length > 15 ? r[15].trim() : '';

            final patientId = phone.isNotEmpty ? 'PAT-$phone' : 'PAT-${name.hashCode.abs()}';
            final opNumber = 'OP-${(name.hashCode.abs() % 900) + 100}';

            final List<VisitRecord> visits = [];
            if (invNo.isNotEmpty || totalAmt > 0) {
              visits.add(VisitRecord(
                date: lastVisit.isNotEmpty ? lastVisit : '2026-10-14',
                doctor: doctor,
                notes: paymentMode.isNotEmpty ? '$diseaseHistory ($paymentMode)' : diseaseHistory,
                invoiceId: invNo.isNotEmpty ? invNo : 'INV-PREV',
                amount: totalAmt,
              ));
            }

            patients.add(Patient(
              id: patientId,
              opNumber: opNumber,
              name: name.isNotEmpty ? name : 'Patient',
              phone: phone,
              email: email,
              dob: dob,
              gender: gender,
              doctor: doctor,
              medicalHistory: medHistory,
              diseaseHistory: diseaseHistory,
              registrationDate: lastVisit.isNotEmpty ? lastVisit : '2026-10-14',
              totalVisits: visits.length > 1 ? visits.length : 1,
              totalBilled: totalAmt,
              visits: visits,
            ));
          }
        }
      }
    } catch (_) {}

    // 2. Fetch Appointments Sheet
    try {
      final res = await http.get(Uri.parse(appointmentsSheetCsvUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final rows = _parseCsv(res.body);
        for (final r in rows) {
          if (r.length < 3) continue;
          final aptId = r[0].trim();
          // Skip if header
          if (aptId.toLowerCase().contains('appointment') || aptId.toLowerCase().contains('id')) continue;

          final pName = r.length > 1 ? r[1].trim() : '';
          final phone = r.length > 2 ? r[2].trim() : '';
          if (pName.isEmpty && phone.isEmpty) continue;

          final date = r.length > 4 && r[4].isNotEmpty ? r[4].trim() : '2026-10-24';
          final time = r.length > 5 && r[5].isNotEmpty ? r[5].trim() : '10:00 AM';
          final doctor = r.length > 6 && r[6].isNotEmpty ? r[6].trim() : 'Dr. Sanju Antony';
          final reason = r.length > 7 && r[7].isNotEmpty ? r[7].trim() : 'CONSULTATION';
          final status = r.length > 8 && r[8].isNotEmpty ? r[8].trim() : 'Upcoming';
          final notes = r.length > 9 ? r[9].trim() : '';

          appointments.add(Appointment(
            id: aptId.isNotEmpty ? aptId : 'APT-${appointments.length + 1001}',
            patientName: pName,
            phone: phone,
            doctor: doctor,
            date: date,
            timeSlot: time,
            reason: reason,
            status: status == 'Scheduled' ? 'Upcoming' : status,
            notes: notes,
          ));
        }
      }
    } catch (_) {}

    // 3. Fetch Invoices Sheet
    try {
      final res = await http.get(Uri.parse(invoicesSheetCsvUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final rows = _parseCsv(res.body);
        if (rows.length > 1) {
          for (int i = 1; i < rows.length; i++) {
            final r = rows[i];
            if (r.isEmpty) continue;

            final invId = r[0].trim();
            if (invId.isEmpty || invId.toLowerCase().contains('invoice')) continue;

            final dateStr = r.length > 1 ? r[1].trim() : '2026-10-14';
            final pName = r.length > 2 ? r[2].trim() : 'Patient';
            final phone = r.length > 3 ? r[3].trim() : '';
            final doctor = r.length > 4 && r[4].isNotEmpty ? r[4].trim() : 'Dr. Sanju Antony';

            final consult = r.length > 5 ? (double.tryParse(r[5].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final xray = r.length > 6 ? (double.tryParse(r[6].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final pharm = r.length > 7 ? (double.tryParse(r[7].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final total = r.length > 8 ? (double.tryParse(r[8].replaceAll(RegExp(r'[^0-9.]'), '')) ?? (consult + xray + pharm)) : (consult + xray + pharm);
            final payMode = r.length > 9 && r[9].isNotEmpty ? r[9].trim() : 'Cash';

            invoices.add(Invoice(
              id: invId,
              patientName: pName,
              phone: phone,
              doctor: doctor,
              date: dateStr,
              consultationCharge: consult,
              xrayCharge: xray,
              pharmacyCharge: pharm,
              totalAmount: total,
              paymentMode: payMode,
            ));
          }
        }
      }
    } catch (_) {}

    return {
      'patients': patients,
      'appointments': appointments,
      'invoices': invoices,
    };
  }
}
