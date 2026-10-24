import 'package:flutter_test/flutter_test.dart';
import 'package:dental_care_app/models/patient.dart';
import 'package:dental_care_app/models/appointment.dart';
import 'package:dental_care_app/models/invoice.dart';
import 'package:dental_care_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dental Care App Models & Service Unit Tests', () {
    test('Patient model serialization and deserialization', () {
      final patient = Patient(
        id: 'PAT-TEST-1',
        opNumber: 'OP-999',
        name: 'Test Patient',
        phone: '9845000000',
        gender: 'Male',
        doctor: 'Dr. Sanju Antony',
        registrationDate: '2026-10-24',
        medicalHistory: 'None',
        totalVisits: 2,
        totalBilled: 1500.0,
      );

      final json = patient.toJson();
      final fromJson = Patient.fromJson(json);

      expect(fromJson.name, 'Test Patient');
      expect(fromJson.phone, '9845000000');
      expect(fromJson.totalBilled, 1500.0);
    });

    test('Invoice calculation and charge validation', () {
      final invoice = Invoice(
        id: 'INV-TEST-001',
        patientName: 'Test Patient',
        phone: '9845000000',
        doctor: 'Dr. Sanju Antony',
        date: '2026-10-24',
        consultationCharge: 350.0,
        xrayCharge: 200.0,
        pharmacyCharge: 450.0,
        totalAmount: 1000.0,
        paymentMode: 'UPI / Online',
      );

      expect(invoice.totalAmount, 1000.0);
      expect(invoice.consultationCharge + invoice.xrayCharge + invoice.pharmacyCharge, 1000.0);
    });

    test('Appointment model properties', () {
      final apt = Appointment(
        id: 'APT-TEST-01',
        patientName: 'John Doe',
        phone: '9988776655',
        doctor: 'Dr. Sanju Antony',
        date: '2026-10-25',
        timeSlot: '11:00 AM',
        reason: 'Tooth extraction review',
      );

      expect(apt.status, 'Upcoming');
      apt.status = 'Completed';
      expect(apt.status, 'Completed');
    });

    test('StorageService initializes seed data', () async {
      final storage = StorageService();
      await storage.initialize();

      expect(storage.patients.isNotEmpty, true);
      expect(storage.appointments.isNotEmpty, true);
      expect(storage.invoices.isNotEmpty, true);
      expect(storage.inventory.isNotEmpty, true);
    });

    test('Search matching finds records by name, normalized phone, and OP number', () async {
      final storage = StorageService();
      await storage.initialize();

      // Search by name
      final nameMatches = storage.patients.where(
        (p) => p.name.toLowerCase().contains('rajesh'),
      ).toList();
      expect(nameMatches.isNotEmpty, true);
      expect(nameMatches.first.name, 'Rajesh Kumar');

      // Search by normalized phone digits (e.g. searching '9845012345' or '98450')
      const qDigits = '9845012345';
      final phoneMatches = storage.patients.where(
        (p) => p.phone.replaceAll(RegExp(r'\D'), '').contains(qDigits),
      ).toList();
      expect(phoneMatches.isNotEmpty, true);
      expect(phoneMatches.first.name, 'Rajesh Kumar');

      // Search by OP number
      final opMatches = storage.patients.where(
        (p) => p.opNumber.toLowerCase().contains('op-401'),
      ).toList();
      expect(opMatches.isNotEmpty, true);
      expect(opMatches.first.name, 'Rajesh Kumar');

      // Search invoice by ID
      final invMatches = storage.invoices.where(
        (i) => i.id.toLowerCase().contains('inv-2026-001'),
      ).toList();
      expect(invMatches.isNotEmpty, true);

      // Search appointment by procedure
      final aptMatches = storage.appointments.where(
        (a) => a.reason.toLowerCase().contains('root canal'),
      ).toList();
      expect(aptMatches.isNotEmpty, true);
    });
  });
}
