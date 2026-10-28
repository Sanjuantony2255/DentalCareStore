import 'package:flutter_test/flutter_test.dart';
import 'package:dental_care_app/models/patient.dart';
import 'package:dental_care_app/models/appointment.dart';
import 'package:dental_care_app/models/invoice.dart';
import 'package:dental_care_app/services/storage_service.dart';
import 'package:dental_care_app/constants/treatments.dart';
import 'package:dental_care_app/widgets/invoice_receipt_dialog.dart';

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
        doctor: 'Dr. Jeswin Jose BDS',
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
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-24',
        consultationCharge: 350.0,
        treatmentCharge: 1000.0,
        treatment: 'SCALING & POLISHING',
        xrayCharge: 200.0,
        pharmacyCharge: 450.0,
        customCharges: [
          CustomChargeItem(title: 'Lab Fee', amount: 500.0),
          CustomChargeItem(title: 'Anesthesia Kit', amount: 200.0),
        ],
        totalAmount: 2700.0,
        paymentMode: 'UPI / Online',
      );

      expect(invoice.totalAmount, 2700.0);
      expect(invoice.treatment, 'SCALING & POLISHING');
      expect(invoice.treatmentCharge, 1000.0);
      expect(invoice.customCharges.length, 2);
      expect(invoice.customCharges[0].title, 'Lab Fee');
      expect(invoice.customCharges[0].amount, 500.0);

      final sum = invoice.consultationCharge +
          invoice.treatmentCharge +
          invoice.xrayCharge +
          invoice.pharmacyCharge +
          invoice.customCharges.fold(0.0, (acc, c) => acc + c.amount);
      expect(sum, 2700.0);

      // JSON serialization & deserialization check
      final json = invoice.toJson();
      final fromJson = Invoice.fromJson(json);
      expect(fromJson.treatment, 'SCALING & POLISHING');
      expect(fromJson.treatmentCharge, 1000.0);
      expect(fromJson.customCharges.length, 2);
      expect(fromJson.customCharges[1].title, 'Anesthesia Kit');
      expect(fromJson.customCharges[1].amount, 200.0);
      expect(fromJson.totalAmount, 2700.0);
    });

    test('Appointment model properties', () {
      final apt = Appointment(
        id: 'APT-TEST-01',
        patientName: 'John Doe',
        phone: '9988776655',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-25',
        timeSlot: '11:00 AM',
        reason: 'Tooth extraction review',
      );

      expect(apt.status, 'Upcoming');
      apt.status = 'Completed';
      expect(apt.status, 'Completed');
    });

    test('StorageService initializes clean and manages records', () async {
      final storage = StorageService();
      await storage.initialize();

      expect(storage.patients.isEmpty, true);
      expect(storage.appointments.isEmpty, true);
      expect(storage.invoices.isEmpty, true);
      expect(storage.inventory.isEmpty, true);
    });

    test('Search matching finds records by name, normalized phone, and OP number', () async {
      final storage = StorageService();
      await storage.initialize();

      // Add a test patient record to test search functionality
      final testPatient = Patient(
        id: 'PAT-TEST-001',
        opNumber: 'OP-102',
        name: 'Gokul Test',
        phone: '133564456156',
        gender: 'Male',
        doctor: 'Dr. Jeswin Jose BDS',
        registrationDate: '2026-10-24',
        medicalHistory: 'None',
        totalVisits: 1,
        totalBilled: 1000.0,
      );
      await storage.savePatient(testPatient);

      final testInvoice = Invoice(
        id: 'INV-20261014-9713',
        patientName: 'Gokul Test',
        phone: '133564456156',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-14',
        consultationCharge: 1000.0,
        totalAmount: 1000.0,
        paymentMode: 'Cash',
      );
      await storage.saveInvoice(testInvoice);

      final testApt = Appointment(
        id: 'APT-TEST-001',
        patientName: 'Gokul Test',
        phone: '133564456156',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-25',
        timeSlot: '10:00 AM',
        reason: 'General Consultation & Checkup',
      );
      await storage.saveAppointment(testApt);

      // Search by name
      final nameMatches = storage.patients.where(
        (p) => p.name.toLowerCase().contains('gokul'),
      ).toList();
      expect(nameMatches.isNotEmpty, true);
      expect(nameMatches.first.name, 'Gokul Test');

      // Search by normalized phone digits (e.g. searching '133564456156')
      const qDigits = '133564456156';
      final phoneMatches = storage.patients.where(
        (p) => p.phone.replaceAll(RegExp(r'\D'), '').contains(qDigits),
      ).toList();
      expect(phoneMatches.isNotEmpty, true);
      expect(phoneMatches.first.name, 'Gokul Test');

      // Search by OP number
      final opMatches = storage.patients.where(
        (p) => p.opNumber.toLowerCase().contains('op-102'),
      ).toList();
      expect(opMatches.isNotEmpty, true);
      expect(opMatches.first.name, 'Gokul Test');

      // Search invoice by ID
      final invMatches = storage.invoices.where(
        (i) => i.id.toLowerCase().contains('inv-20261014-9713'),
      ).toList();
      expect(invMatches.isNotEmpty, true);

      // Search appointment by procedure
      final aptMatches = storage.appointments.where(
        (a) => a.reason.toLowerCase().contains('consultation'),
      ).toList();
      expect(aptMatches.isNotEmpty, true);
    });

    test('All requested clinic dental treatments are registered', () {
      expect(kDentalTreatments.contains('POST & CORE'), true);
      expect(kDentalTreatments.contains('CROWN METAL'), true);
      expect(kDentalTreatments.contains('CROWN PFM'), true);
      expect(kDentalTreatments.contains('CROWN PFZ'), true);
      expect(kDentalTreatments.contains('EMAX CROWN, VENEER, INLAY'), true);
      expect(kDentalTreatments.contains('SCALING'), true);
      expect(kDentalTreatments.contains('RCT'), true);
      expect(kDentalTreatments.contains('CLEAR ALIGNERS'), true);
      expect(kDentalTreatments.contains('DENTAL IMPLANTS'), true);
      expect(kDentalTreatments.length, greaterThanOrEqualTo(50));
    });

    test('Invoice PDF generation produces valid non-empty PDF bytes', () async {
      final invoice = Invoice(
        id: 'INV-TEST-002',
        patientName: 'John Patient',
        phone: '9845012345',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-27',
        consultationCharge: 300.0,
        treatmentCharge: 2500.0,
        treatment: 'ROOT CANAL TREATMENT - RCT',
        xrayCharge: 200.0,
        pharmacyCharge: 150.0,
        customCharges: [
          CustomChargeItem(title: 'Crown Preparation', amount: 1500.0),
        ],
        totalAmount: 4650.0,
        paymentMode: 'UPI / Online',
      );

      final pdfBytes = await InvoiceReceiptDialog.generateInvoicePdfBytes(invoice);
      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length, greaterThan(100));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 4)), '%PDF');
    });

    test('StorageService userRole toggles between Admin and Staff', () async {
      final storage = StorageService();
      expect(storage.userRole, 'staff');
      expect(storage.isAdmin, false);

      await storage.setUserRole('admin');
      expect(storage.userRole, 'admin');
      expect(storage.isAdmin, true);

      await storage.setUserRole('staff');
      expect(storage.userRole, 'staff');
      expect(storage.isAdmin, false);
    });
  });
}
