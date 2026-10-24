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

  /// Fetches live data from GitHub Cloud repository AND Google Sheet cloud
  static Future<Map<String, dynamic>> fetchCloudData() async {
    final List<Patient> patients = [];
    final List<Appointment> appointments = [];
    final List<Invoice> invoices = [];
    final List<InventoryItem> inventory = [];

    // 1. Fetch GitHub Cloud Repository baseline (fastest global CDN)
    try {
      final res = await http.get(Uri.parse(githubCloudDataUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['patients'] is List) {
            for (final p in decoded['patients']) {
              patients.add(Patient.fromJson(p));
            }
          }
          if (decoded['appointments'] is List) {
            for (final a in decoded['appointments']) {
              appointments.add(Appointment.fromJson(a));
            }
          }
          if (decoded['invoices'] is List) {
            for (final i in decoded['invoices']) {
              invoices.add(Invoice.fromJson(i));
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
    try {
      final res = await http.get(Uri.parse('$defaultScriptUrl?action=getPatients')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['data'] is List) {
          for (final item in data['data']) {
            final name = item['fullName']?.toString().trim() ?? '';
            final phone = item['phone']?.toString().trim() ?? '';
            if (name.isEmpty && phone.isEmpty) continue;

            final existingIdx = patients.indexWhere((p) =>
                (phone.isNotEmpty && p.phone == phone) ||
                (name.isNotEmpty && p.name.toLowerCase() == name.toLowerCase()));

            final email = item['email']?.toString() ?? '';
            final dob = item['dob']?.toString() ?? '';
            final gender = item['gender']?.toString() ?? 'Male';
            final doctor = item['doctorConsulted']?.toString() ?? 'Dr. Sanju Antony';
            final medHistory = item['medicalHistory']?.toString() ?? 'None';
            final diseaseHistory = item['diseaseHistory']?.toString() ?? '';
            final latestVisit = item['latestVisit']?.toString() ?? '2026-10-24';
            final visitsCount = (item['visitsCount'] as num?)?.toInt() ?? 1;
            final totalBilled = (item['totalBilled'] as num?)?.toDouble() ?? 0.0;

            final List<VisitRecord> visits = [];
            if (item['visits'] is List) {
              for (final v in item['visits']) {
                if (v is Map) {
                  visits.add(VisitRecord(
                    date: v['date']?.toString() ?? latestVisit,
                    doctor: v['doctor']?.toString() ?? doctor,
                    notes: v['notes']?.toString() ?? diseaseHistory,
                    invoiceId: v['invoiceId']?.toString() ?? 'INV-CLOUD',
                    amount: (v['amount'] as num?)?.toDouble() ?? 0.0,
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

            if (existingIdx >= 0) {
              patients[existingIdx] = parsedPatient;
            } else {
              patients.add(parsedPatient);
            }
          }
        }
      }
    } catch (_) {}

    // 3. Fetch Google Apps Script live Appointments
    try {
      final res = await http.get(Uri.parse('$defaultScriptUrl?action=getAppointments&type=all')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['data'] is List) {
          for (final item in data['data']) {
            final aptId = item['appointmentId']?.toString().trim() ?? '';
            final pName = item['patientName']?.toString().trim() ?? '';
            final phone = item['phone']?.toString().trim() ?? '';
            if (pName.isEmpty && phone.isEmpty) continue;

            final apt = Appointment(
              id: aptId.isNotEmpty ? aptId : 'APT-${appointments.length + 1001}',
              patientName: pName,
              phone: phone,
              doctor: item['doctor']?.toString().trim().isNotEmpty == true ? item['doctor'].toString().trim() : 'Dr. Sanju Antony',
              date: item['date']?.toString().trim().isNotEmpty == true ? item['date'].toString().trim() : '2026-10-24',
              timeSlot: item['time']?.toString().trim().isNotEmpty == true ? item['time'].toString().trim() : '10:00 AM',
              reason: item['reason']?.toString().trim().isNotEmpty == true ? item['reason'].toString().trim() : 'CONSULTATION',
              status: item['status']?.toString().trim() == 'Scheduled' ? 'Upcoming' : (item['status']?.toString().trim() ?? 'Upcoming'),
              notes: item['notes']?.toString().trim() ?? '',
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

    // 4. Fetch Google Sheet Invoices CSV & Accounts
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

            final dateStr = r.length > 1 ? r[1].trim() : '2026-10-24';
            final pName = r.length > 2 ? r[2].trim() : 'Patient';
            final phone = r.length > 3 ? r[3].trim() : '';
            final doctor = r.length > 4 && r[4].isNotEmpty ? r[4].trim() : 'Dr. Sanju Antony';

            final consult = r.length > 5 ? (double.tryParse(r[5].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final xray = r.length > 6 ? (double.tryParse(r[6].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final pharm = r.length > 7 ? (double.tryParse(r[7].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) : 0.0;
            final total = r.length > 8 ? (double.tryParse(r[8].replaceAll(RegExp(r'[^0-9.]'), '')) ?? (consult + xray + pharm)) : (consult + xray + pharm);
            final payMode = r.length > 9 && r[9].isNotEmpty ? r[9].trim() : 'Cash';

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
