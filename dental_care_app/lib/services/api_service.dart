import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/invoice.dart';

class ApiService {
  static const String defaultScriptUrl =
      'https://script.google.com/macros/s/AKfycbyC1zFwfNFa8w-wLJGdEE9ladkNL2rZk-gIfx68CX76upxyQrI1Lar8Tb6BGEvLX4q0/exec';

  // Optional online sync with Google Apps Script Web App
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
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (_) {
      // Offline or network error - returns false to rely on local storage
      return false;
    }
  }

  static Future<bool> syncRegistrationOnline(Patient patient, Invoice invoice) async {
    try {
      final response = await http.post(
        Uri.parse(defaultScriptUrl),
        body: {
          'action': 'registerPatient',
          'name': patient.name,
          'phone': patient.phone,
          'age': patient.age.toString(),
          'dob': patient.dob,
          'gender': patient.gender,
          'doctor': patient.doctor,
          'medicalHistory': patient.medicalHistory,
          'drugAllergies': patient.drugAllergies,
          'diseaseHistory': patient.diseaseHistory,
          'consultationCharge': invoice.consultationCharge.toString(),
          'xrayCharge': invoice.xrayCharge.toString(),
          'pharmacyCharge': invoice.pharmacyCharge.toString(),
          'totalAmount': invoice.totalAmount.toString(),
          'paymentMode': invoice.paymentMode,
          'invoiceNumber': invoice.id,
        },
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (_) {
      return false;
    }
  }
}
