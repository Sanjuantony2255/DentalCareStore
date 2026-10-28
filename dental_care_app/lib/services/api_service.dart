import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/invoice.dart';
import '../models/inventory_item.dart';

class ApiService {
  static const String githubCloudDataUrl =
      'https://raw.githubusercontent.com/Sanjuantony2255/DentalCareStore/main/clinic_data.json';
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

  /// Reschedules an appointment in the Google Cloud database
  static Future<bool> rescheduleAppointmentOnline(
    String appointmentId,
    String phone,
    String newDate,
    String newTime,
    String doctor,
    String notes,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(defaultScriptUrl),
        body: {
          'action': 'rescheduleAppointment',
          'appointmentId': appointmentId,
          'phone': phone,
          'newDate': newDate,
          'newTime': newTime,
          'doctor': doctor,
          'notes': notes,
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  /// Updates status in Google Apps Script (e.g. Completed / Cancelled / Upcoming)
  static Future<bool> updateAppointmentStatusOnline(
    String appointmentId,
    String newStatus,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(defaultScriptUrl),
        body: {
          'action': 'updateAppointmentStatus',
          'appointmentId': appointmentId,
          'status': newStatus,
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
          'date': invoice.date,
          'timestamp': invoice.date,
          'lastVisitDate': invoice.date,
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

  /// Dynamically locates the column index from header row based on keywords
  static int _findCol(List<String> headers, List<String> patterns, int fallback) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().trim();
      for (final p in patterns) {
        if (h.contains(p.toLowerCase())) return i;
      }
    }
    return fallback;
  }

  /// Safely retrieves a cell value from a row avoiding RangeError exceptions
  static String _safeCell(List<String> row, int index) {
    if (index >= 0 && index < row.length) {
      return row[index].trim();
    }
    return '';
  }

  /// Fetches live data from GitHub Cloud repository AND Google Sheet cloud
  static Future<Map<String, dynamic>> fetchCloudData() async {
    final List<Patient> patients = [];
    final List<Appointment> appointments = [];
    final List<Invoice> invoices = [];
    final List<InventoryItem> inventory = [];

    // Helper checks to filter out any dummy test data
    bool isDummyPatient(String name, String phone, String id) {
      final n = name.trim().toLowerCase();
      final p = phone.trim();
      return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
          p == '9845012345' || p == '9876543210' || p == '9998887776' ||
          id == 'PAT-1001' || id == 'PAT-9876543210';
    }

    bool isDummyAppointment(String id, String name, String phone) {
      final n = name.trim().toLowerCase();
      final p = phone.trim();
      return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
          p == '9845012345' || p == '9876543210' || p == '9998887776' ||
          id.contains('20261024-00');
    }

    bool isDummyInvoice(String id, String name) {
      final n = name.trim().toLowerCase();
      return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
          id == 'INV-2026-001' || id == 'INV-20261013-3604' || id == 'INV-20261013-3503';
    }

    // 1. Fetch GitHub Cloud Repository baseline (fastest global CDN)
    try {
      final res = await http.get(Uri.parse(githubCloudDataUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['patients'] is List) {
            for (final p in decoded['patients']) {
              final pat = Patient.fromJson(p);
              if (!isDummyPatient(pat.name, pat.phone, pat.id)) {
                patients.add(pat);
              }
            }
          }
          if (decoded['appointments'] is List) {
            for (final a in decoded['appointments']) {
              final apt = Appointment.fromJson(a);
              if (!isDummyAppointment(apt.id, apt.patientName, apt.phone)) {
                appointments.add(apt);
              }
            }
          }
          if (decoded['invoices'] is List) {
            for (final i in decoded['invoices']) {
              final inv = Invoice.fromJson(i);
              if (!isDummyInvoice(inv.id, inv.patientName)) {
                invoices.add(inv);
              }
            }
          }
          if (decoded['inventory'] is List) {
            for (final item in decoded['inventory']) {
              inventory.add(InventoryItem.fromJson(item));
            }
          }
        }
      }
    } catch (_) {}

    // 2. Fetch Google Apps Script live Patients
    final List<Patient> livePatients = [];
    try {
      final res = await http.get(Uri.parse('$defaultScriptUrl?action=getPatients')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['data'] is List) {
          for (final item in data['data']) {
            final name = item['fullName']?.toString().trim() ?? '';
            final phone = item['phone']?.toString().trim() ?? '';
            if (name.isEmpty && phone.isEmpty) continue;
            if (isDummyPatient(name, phone, '')) continue;

            final email = item['email']?.toString() ?? '';
            final dob = item['dob']?.toString() ?? '';
            final gender = item['gender']?.toString() ?? 'Male';
            final doctor = item['doctorConsulted']?.toString() ?? 'Dr. Jeswin Jose BDS';
            final medHistory = item['medicalHistory']?.toString() ?? 'None';
            final diseaseHistory = item['diseaseHistory']?.toString() ?? '';
            final latestVisit = item['latestVisit']?.toString() ?? '2026-10-14';
            final visitsCount = (item['visitsCount'] as num?)?.toInt() ?? 1;
            final totalBilled = (item['totalBilled'] as num?)?.toDouble() ?? 0.0;

            final List<VisitRecord> visits = [];
            if (item['visits'] is List) {
              for (final v in item['visits']) {
                if (v is Map) {
                  visits.add(VisitRecord(
                    date: v['date']?.toString() ?? v['timestamp']?.toString().split(' ').first ?? latestVisit,
                    doctor: v['doctor']?.toString() ?? v['doctorConsulted']?.toString() ?? doctor,
                    notes: v['notes']?.toString() ?? v['diseaseHistory']?.toString() ?? diseaseHistory,
                    invoiceId: v['invoiceId']?.toString() ?? v['invoiceNo']?.toString() ?? 'INV-SHEET',
                    amount: (v['amount'] as num?)?.toDouble() ?? (v['totalAmount'] as num?)?.toDouble() ?? 0.0,
                  ));
                }
              }
            }

            final parsedPatient = Patient(
              id: phone.isNotEmpty ? 'PAT-$phone' : 'PAT-${name.hashCode.abs()}',
              opNumber: 'OP-${(name.hashCode.abs() % 900) + 100}',
              name: name,
              phone: phone,
              email: email,
              dob: dob,
              gender: gender,
              doctor: doctor,
              medicalHistory: medHistory,
              diseaseHistory: diseaseHistory,
              registrationDate: latestVisit,
              totalVisits: visitsCount,
              totalBilled: totalBilled,
              visits: visits,
            );

            livePatients.add(parsedPatient);
          }
        }
      }
    } catch (_) {}

    if (livePatients.isNotEmpty) {
      patients.clear();
      patients.addAll(livePatients);
    } else {
      // Direct Google Sheet CSV Fallback for Patients
      try {
        final res = await http.get(Uri.parse(patientsSheetCsvUrl)).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          final rows = _parseCsv(res.body);
          if (rows.isNotEmpty) {
            final headers = rows[0];
            final hasHeader = headers.any((h) =>
                h.toLowerCase().contains('time') ||
                h.toLowerCase().contains('name') ||
                h.toLowerCase().contains('phone'));

            final colTime = _findCol(headers, ['timestamp', 'time', 'date'], 0);
            final colName = _findCol(headers, ['full name', 'patient name', 'name'], 1);
            final colPhone = _findCol(headers, ['phone', 'mobile', 'contact'], 2);
            final colEmail = _findCol(headers, ['email', 'mail'], 3);
            final colDob = _findCol(headers, ['dob', 'birth', 'age'], 4);
            final colGender = _findCol(headers, ['gender', 'sex'], 5);
            final colDoctor = _findCol(headers, ['doctor', 'attending', 'consulted'], 6);
            final colMedHist = _findCol(headers, ['medical'], 7);
            final colAllergies = _findCol(headers, ['allerg', 'drug'], 8);
            final colDisease = _findCol(headers, ['disease', 'procedure', 'complaint'], 9);
            final colTotal = _findCol(headers, ['total', 'amount'], 13);
            final colInv = _findCol(headers, ['invoice'], 16);

            final List<Patient> csvPatients = [];
            final startIdx = hasHeader ? 1 : 0;
            for (int i = startIdx; i < rows.length; i++) {
              final r = rows[i];
              if (r.isEmpty) continue;
              final timestamp = _safeCell(r, colTime);
              if (timestamp.toLowerCase().contains('timestamp')) continue;
              final name = _safeCell(r, colName);
              final phone = _safeCell(r, colPhone);
              if (name.isEmpty && phone.isEmpty) continue;
              if (isDummyPatient(name, phone, '')) continue;

              final email = _safeCell(r, colEmail);
              final dob = _safeCell(r, colDob);
              final gender = _safeCell(r, colGender).isNotEmpty ? _safeCell(r, colGender) : 'Male';
              final rawDoc = _safeCell(r, colDoctor);
              final doctor = rawDoc.isNotEmpty ? rawDoc : 'Dr. Jeswin Jose BDS';
              final medHistory = _safeCell(r, colMedHist).isNotEmpty ? _safeCell(r, colMedHist) : 'None';
              final drugAllergies = _safeCell(r, colAllergies).isNotEmpty ? _safeCell(r, colAllergies) : 'None';
              final disease = _safeCell(r, colDisease);
              final rawTotal = _safeCell(r, colTotal).replaceAll(RegExp(r'[^0-9.]'), '');
              final totalAmt = double.tryParse(rawTotal) ?? 0.0;
              final rawInv = _safeCell(r, colInv);
              final invNo = rawInv.isNotEmpty ? rawInv : 'INV-SHEET';

              final visitDate = timestamp.split(' ').first;
              final visit = VisitRecord(
                date: visitDate.isNotEmpty ? visitDate : '2026-10-14',
                doctor: doctor,
                notes: disease.isNotEmpty ? disease : 'Clinical Dental Checkup',
                invoiceId: invNo,
                amount: totalAmt,
              );

              final existingIdx = csvPatients.indexWhere((p) =>
                (phone.isNotEmpty && p.phone == phone) ||
                (name.isNotEmpty && p.name.toLowerCase() == name.toLowerCase())
              );

              if (existingIdx >= 0) {
                final ex = csvPatients[existingIdx];
                ex.visits.add(visit);
                csvPatients[existingIdx] = Patient(
                  id: ex.id,
                  opNumber: ex.opNumber,
                  name: ex.name,
                  phone: ex.phone,
                  email: ex.email,
                  dob: ex.dob,
                  gender: ex.gender,
                  doctor: ex.doctor,
                  medicalHistory: ex.medicalHistory,
                  drugAllergies: ex.drugAllergies,
                  diseaseHistory: ex.diseaseHistory,
                  registrationDate: ex.registrationDate,
                  totalVisits: ex.visits.length,
                  totalBilled: ex.totalBilled + totalAmt,
                  visits: ex.visits,
                );
              } else {
                csvPatients.add(Patient(
                  id: phone.isNotEmpty ? 'PAT-$phone' : 'PAT-${name.hashCode.abs()}',
                  opNumber: 'OP-${(name.hashCode.abs() % 900) + 100}',
                  name: name,
                  phone: phone,
                  email: email,
                  dob: dob,
                  gender: gender,
                  doctor: doctor,
                  medicalHistory: medHistory,
                  drugAllergies: drugAllergies,
                  diseaseHistory: disease,
                  registrationDate: visitDate,
                  totalVisits: 1,
                  totalBilled: totalAmt,
                  visits: [visit],
                ));
              }
            }
            if (csvPatients.isNotEmpty) {
              patients.clear();
              patients.addAll(csvPatients);
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fetch Google Sheet Appointments CSV directly + Apps Script status
    try {
      final res = await http.get(Uri.parse(appointmentsSheetCsvUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final rows = _parseCsv(res.body);
        if (rows.isNotEmpty) {
          final headers = rows[0];
          final hasHeader = headers.any((h) =>
              h.toLowerCase().contains('appointment') ||
              h.toLowerCase().contains('name') ||
              h.toLowerCase().contains('phone'));

          final colId = _findCol(headers, ['appointment', 'id', 'booking'], 0);
          final colName = _findCol(headers, ['patient', 'name'], 1);
          final colPhone = _findCol(headers, ['phone', 'mobile'], 2);
          final colDate = _findCol(headers, ['date', 'day'], 4);
          final colTime = _findCol(headers, ['time', 'slot'], 5);
          final colDoctor = _findCol(headers, ['doctor'], 6);
          final colReason = _findCol(headers, ['reason', 'procedure', 'purpose'], 7);
          final colStatus = _findCol(headers, ['status'], 8);
          final colNotes = _findCol(headers, ['note', 'remark'], 11);

          final startIdx = hasHeader ? 1 : 0;
          for (int i = startIdx; i < rows.length; i++) {
            final r = rows[i];
            if (r.isEmpty) continue;
            final aptId = _safeCell(r, colId);
            if (aptId.toLowerCase().contains('appointment') && hasHeader) continue;
            final pName = _safeCell(r, colName);
            final phone = _safeCell(r, colPhone);
            if (pName.isEmpty && phone.isEmpty) continue;
            if (isDummyAppointment(aptId, pName, phone)) continue;

            final rawDate = _safeCell(r, colDate);
            final dateStr = rawDate.isNotEmpty ? rawDate : '2026-10-14';
            final rawTime = _safeCell(r, colTime);
            final timeSlot = rawTime.isNotEmpty ? rawTime : '10:00 AM';
            final rawDoc = _safeCell(r, colDoctor);
            final doctor = rawDoc.isNotEmpty ? rawDoc : 'Dr. Jeswin Jose BDS';
            final rawReason = _safeCell(r, colReason);
            final reason = rawReason.isNotEmpty ? rawReason : 'General Consultation & Checkup';
            final rawStatus = _safeCell(r, colStatus);
            final status = rawStatus.isNotEmpty ? rawStatus : 'Upcoming';
            final notes = _safeCell(r, colNotes);

            final apt = Appointment(
              id: aptId,
              patientName: pName,
              phone: phone,
              doctor: doctor,
              date: dateStr,
              timeSlot: timeSlot.contains('AM') || timeSlot.contains('PM') ? timeSlot : '$timeSlot AM',
              reason: reason,
              status: status == 'Scheduled' ? 'Upcoming' : status,
              notes: notes,
            );

            final existingIdx = appointments.indexWhere((a) => a.id == apt.id);
            if (existingIdx >= 0) {
              appointments[existingIdx] = apt;
            } else {
              appointments.add(apt);
            }
          }
        }
      }
    } catch (_) {}

    // Apps Script appointments for latest statuses
    try {
      final res = await http.get(Uri.parse('$defaultScriptUrl?action=getAppointments&type=all')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['data'] is List) {
          for (final item in data['data']) {
            final aptId = item['appointmentId']?.toString().trim() ?? '';
            final pName = item['patientName']?.toString().trim() ?? '';
            final phone = item['phone']?.toString().trim() ?? '';
            if (aptId.isEmpty || isDummyAppointment(aptId, pName, phone)) continue;

            final existingIdx = appointments.indexWhere((a) => a.id == aptId);
            if (existingIdx >= 0) {
              if (item['status'] != null) {
                final st = item['status'].toString().trim();
                appointments[existingIdx].status = st == 'Scheduled' ? 'Upcoming' : st;
              }
            }
          }
        }
      }
    } catch (_) {}

    // 4. Fetch Google Sheet Invoices CSV & Accounts
    try {
      final res = await http.get(Uri.parse(invoicesSheetCsvUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final rows = _parseCsv(res.body);
        if (rows.isNotEmpty) {
          final headers = rows[0];
          final hasHeader = headers.any((h) =>
              h.toLowerCase().contains('invoice') ||
              h.toLowerCase().contains('name') ||
              h.toLowerCase().contains('bill'));

          final colId = _findCol(headers, ['invoice', 'inv', 'bill', 'id'], 0);
          final colDate = _findCol(headers, ['date', 'time'], 1);
          final colName = _findCol(headers, ['patient', 'name'], 2);
          final colPhone = _findCol(headers, ['phone', 'mobile'], 3);
          final colDoctor = _findCol(headers, ['doctor'], 4);
          final colConsult = _findCol(headers, ['consult'], 5);
          final colXray = _findCol(headers, ['xray', 'x-ray'], 6);
          final colPharm = _findCol(headers, ['pharm', 'med'], 7);
          final colTotal = _findCol(headers, ['total', 'amount'], 8);
          final colPayMode = _findCol(headers, ['mode', 'payment', 'method'], 9);

          final startIdx = hasHeader ? 1 : 0;
          for (int i = startIdx; i < rows.length; i++) {
            final r = rows[i];
            if (r.isEmpty) continue;

            final invId = _safeCell(r, colId);
            if (invId.toLowerCase().contains('invoice') && hasHeader) continue;

            final pName = _safeCell(r, colName);
            final phone = _safeCell(r, colPhone);
            if (pName.isEmpty && phone.isEmpty) continue;
            if (isDummyInvoice(invId, pName)) continue;

            String dateStr = _safeCell(r, colDate);
            if (dateStr.isEmpty) dateStr = '2026-10-14';
            final dMatch = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})').firstMatch(dateStr);
            if (dMatch != null) {
              final day = dMatch.group(1)!.padLeft(2, '0');
              final month = dMatch.group(2)!.padLeft(2, '0');
              final year = dMatch.group(3)!;
              dateStr = '$year-$month-$day';
            } else if (dateStr.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateStr)) {
              dateStr = dateStr.substring(0, 10);
            }

            final rawDoc = _safeCell(r, colDoctor);
            final doctor = rawDoc.isNotEmpty ? rawDoc : 'Dr. Jeswin Jose BDS';
            final consult = double.tryParse(_safeCell(r, colConsult).replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            final xray = double.tryParse(_safeCell(r, colXray).replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            final pharm = double.tryParse(_safeCell(r, colPharm).replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            final rawTot = double.tryParse(_safeCell(r, colTotal).replaceAll(RegExp(r'[^0-9.]'), ''));
            final total = (rawTot != null && rawTot > 0) ? rawTot : (consult + xray + pharm);
            final rawPayMode = _safeCell(r, colPayMode);
            final payMode = rawPayMode.isNotEmpty ? rawPayMode : 'Cash';

            final inv = Invoice(
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
            );

            final existingIdx = invoices.indexWhere((it) => it.id == inv.id);
            if (existingIdx >= 0) {
              invoices[existingIdx] = inv;
            } else {
              invoices.add(inv);
            }
          }
        }
      }
    } catch (_) {}

    // 5. Fetch Google Apps Script live Pharmacy Stock
    try {
      final res = await http.get(Uri.parse('$defaultScriptUrl?action=getPharmacyStock')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['data'] is List) {
          for (final it in data['data']) {
            final id = it['itemId']?.toString().trim() ?? '';
            final name = it['itemName']?.toString().trim() ?? '';
            if (id.isEmpty && name.isEmpty) continue;

            final invItem = InventoryItem(
              id: id.isNotEmpty ? id : 'MED-${inventory.length + 1001}',
              name: name,
              category: it['category']?.toString() ?? 'Medicines',
              batch: it['batchNo']?.toString() ?? 'AMX-2026-A1',
              expiryDate: it['expiryDate']?.toString() ?? '2027-12-31',
              unitPrice: (it['unitPrice'] as num?)?.toDouble() ?? 10.0,
              quantity: (it['quantity'] as num?)?.toInt() ?? 100,
              minStockThreshold: (it['minThreshold'] as num?)?.toInt() ?? 20,
            );

            final existingIdx = inventory.indexWhere((x) => x.id == invItem.id);
            if (existingIdx >= 0) {
              inventory[existingIdx] = invItem;
            } else {
              inventory.add(invItem);
            }
          }
        }
      }
    } catch (_) {}

    // Final strict filter: remove any dummy test data
    patients.removeWhere((p) => isDummyPatient(p.name, p.phone, p.id));
    appointments.removeWhere((a) => isDummyAppointment(a.id, a.patientName, a.phone));
    invoices.removeWhere((i) => isDummyInvoice(i.id, i.patientName));

    return {
      'patients': patients,
      'appointments': appointments,
      'invoices': invoices,
      'inventory': inventory,
    };
  }

  /// Alias for backward compatibility
  static Future<Map<String, dynamic>> fetchGoogleSheetData() async {
    return fetchCloudData();
  }
}
