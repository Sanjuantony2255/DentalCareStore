import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/invoice.dart';
import '../models/inventory_item.dart';
import 'api_service.dart';

class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final List<Patient> _patients = [];
  final List<Appointment> _appointments = [];
  final List<Invoice> _invoices = [];
  final List<InventoryItem> _inventory = [];

  bool _initialized = false;

  List<Patient> get patients => List.unmodifiable(_patients);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<Invoice> get invoices => List.unmodifiable(_invoices);
  List<InventoryItem> get inventory => List.unmodifiable(_inventory);

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final patientsJson = prefs.getString('manjaly_patients');
      final appointmentsJson = prefs.getString('manjaly_appointments');
      final invoicesJson = prefs.getString('manjaly_invoices');
      final inventoryJson = prefs.getString('manjaly_inventory');

      if (patientsJson != null && patientsJson.isNotEmpty) {
        final List list = jsonDecode(patientsJson);
        _patients.clear();
        _patients.addAll(list.map((e) => Patient.fromJson(e)));
      } else {
        _seedPatients();
      }

      if (appointmentsJson != null && appointmentsJson.isNotEmpty) {
        final List list = jsonDecode(appointmentsJson);
        _appointments.clear();
        _appointments.addAll(list.map((e) => Appointment.fromJson(e)));
      } else {
        _seedAppointments();
      }

      if (invoicesJson != null && invoicesJson.isNotEmpty) {
        final List list = jsonDecode(invoicesJson);
        _invoices.clear();
        _invoices.addAll(list.map((e) => Invoice.fromJson(e)));
      } else {
        _seedInvoices();
      }

      if (inventoryJson != null && inventoryJson.isNotEmpty) {
        final List list = jsonDecode(inventoryJson);
        _inventory.clear();
        _inventory.addAll(list.map((e) => InventoryItem.fromJson(e)));
      } else {
        _seedInventory();
      }
    } catch (e) {
      // In case of any error in prefs, fallback to demo seed
      _seedPatients();
      _seedAppointments();
      _seedInvoices();
      _seedInventory();
    }

    _initialized = true;
    notifyListeners();

    // Auto-sync with connected Google Sheet in background
    syncWithGoogleSheet();
  }

  /// Syncs app state directly with the connected Google Sheet
  Future<bool> syncWithGoogleSheet() async {
    try {
      final data = await ApiService.fetchGoogleSheetData();
      final sheetPatients = data['patients'] as List<Patient>? ?? [];
      final sheetAppointments = data['appointments'] as List<Appointment>? ?? [];
      final sheetInvoices = data['invoices'] as List<Invoice>? ?? [];

      bool changed = false;

      // Merge Patients from Google Sheet
      for (final sp in sheetPatients) {
        final idx = _patients.indexWhere((p) =>
            (p.phone.isNotEmpty && p.phone == sp.phone) ||
            p.name.toLowerCase() == sp.name.toLowerCase());
        if (idx >= 0) {
          if (sp.visits.isNotEmpty && _patients[idx].visits.isEmpty) {
            _patients[idx] = sp;
            changed = true;
          }
        } else {
          _patients.add(sp);
          changed = true;
        }
      }

      // Merge Appointments from Google Sheet
      for (final sa in sheetAppointments) {
        final idx = _appointments.indexWhere((a) => a.id == sa.id);
        if (idx < 0) {
          _appointments.add(sa);
          changed = true;
        }
      }

      // Merge Invoices from Google Sheet
      for (final si in sheetInvoices) {
        final idx = _invoices.indexWhere((i) => i.id == si.id);
        if (idx < 0) {
          _invoices.add(si);
          changed = true;
        }
      }

      if (changed) {
        await _persist();
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Google Sheet sync notice: $e');
      return false;
    }
  }

  // --- CRUD Operations ---

  Future<void> savePatient(Patient patient) async {
    final idx = _patients.indexWhere((p) => p.id == patient.id || (p.phone == patient.phone && p.name == patient.name));
    if (idx >= 0) {
      _patients[idx] = patient;
    } else {
      _patients.insert(0, patient);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> saveAppointment(Appointment apt) async {
    final idx = _appointments.indexWhere((a) => a.id == apt.id);
    if (idx >= 0) {
      _appointments[idx] = apt;
    } else {
      _appointments.insert(0, apt);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateAppointmentStatus(String id, String newStatus) async {
    final apt = _appointments.firstWhere((a) => a.id == id, orElse: () => Appointment(id: '', patientName: '', phone: '', doctor: '', date: '', timeSlot: ''));
    if (apt.id.isNotEmpty) {
      apt.status = newStatus;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> rescheduleAppointment(String id, String newDate, String newTime, String doctor, String notes) async {
    final apt = _appointments.firstWhere((a) => a.id == id, orElse: () => Appointment(id: '', patientName: '', phone: '', doctor: '', date: '', timeSlot: ''));
    if (apt.id.isNotEmpty) {
      apt.date = newDate;
      apt.timeSlot = newTime;
      apt.notes = notes;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> saveInvoice(Invoice invoice) async {
    _invoices.insert(0, invoice);

    // Also update or link to existing patient
    final pIdx = _patients.indexWhere((p) => p.phone == invoice.phone || p.name.toLowerCase() == invoice.patientName.toLowerCase());
    if (pIdx >= 0) {
      _patients[pIdx].totalVisits += 1;
      _patients[pIdx].totalBilled += invoice.totalAmount;
      _patients[pIdx].visits.insert(0, VisitRecord(
        date: invoice.date,
        doctor: invoice.doctor,
        notes: invoice.notes.isNotEmpty ? invoice.notes : 'Clinical consultation & billing',
        invoiceId: invoice.id,
        amount: invoice.totalAmount,
      ));
    }

    await _persist();
    notifyListeners();
  }

  Future<void> adjustStock(String itemId, int delta) async {
    final idx = _inventory.indexWhere((i) => i.id == itemId);
    if (idx >= 0) {
      final current = _inventory[idx].quantity;
      final updated = (current + delta).clamp(0, 99999);
      _inventory[idx].quantity = updated;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    final idx = _inventory.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _inventory[idx] = item;
    } else {
      _inventory.insert(0, item);
    }
    await _persist();
    notifyListeners();
  }

  // --- Financial Analytics Calculations ---

  Map<String, dynamic> getAccountsSummary(String period) {
    // Periods: 'today', 'week', 'month', 'all'
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    List<Invoice> filteredInvoices = [];

    if (period == 'today') {
      filteredInvoices = _invoices.where((i) => i.date == todayStr).toList();
    } else if (period == 'week') {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      filteredInvoices = _invoices.where((i) {
        try {
          final dt = DateTime.parse(i.date);
          return dt.isAfter(sevenDaysAgo) && dt.isBefore(now.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    } else if (period == 'month') {
      final monthPrefix = DateFormat('yyyy-MM').format(now);
      filteredInvoices = _invoices.where((i) => i.date.startsWith(monthPrefix)).toList();
    } else {
      filteredInvoices = List.from(_invoices);
    }

    double totalRevenue = 0.0;
    double consultationTotal = 0.0;
    double xrayTotal = 0.0;
    double pharmacyTotal = 0.0;

    double cashTotal = 0.0;
    double upiTotal = 0.0;
    double cardTotal = 0.0;
    double pendingTotal = 0.0;

    for (var inv in filteredInvoices) {
      totalRevenue += inv.totalAmount;
      consultationTotal += inv.consultationCharge;
      xrayTotal += inv.xrayCharge;
      pharmacyTotal += inv.pharmacyCharge;

      final mode = inv.paymentMode.toLowerCase();
      if (mode.contains('upi') || mode.contains('online')) {
        upiTotal += inv.totalAmount;
      } else if (mode.contains('card')) {
        cardTotal += inv.totalAmount;
      } else if (mode.contains('pending')) {
        pendingTotal += inv.totalAmount;
      } else {
        cashTotal += inv.totalAmount;
      }
    }

    // Overall metrics for the 4 stat cards
    double dailyTotal = 0;
    int dailyVisits = 0;
    double weeklyTotal = 0;
    int weeklyVisits = 0;
    double monthlyTotal = 0;
    int monthlyVisits = 0;
    double lifetimeTotal = 0;
    int lifetimeVisits = _invoices.length;

    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final monthPrefix = DateFormat('yyyy-MM').format(now);

    for (var inv in _invoices) {
      lifetimeTotal += inv.totalAmount;
      if (inv.date == todayStr) {
        dailyTotal += inv.totalAmount;
        dailyVisits++;
      }
      try {
        final dt = DateTime.parse(inv.date);
        if (dt.isAfter(sevenDaysAgo) && dt.isBefore(now.add(const Duration(days: 1)))) {
          weeklyTotal += inv.totalAmount;
          weeklyVisits++;
        }
      } catch (_) {}
      if (inv.date.startsWith(monthPrefix)) {
        monthlyTotal += inv.totalAmount;
        monthlyVisits++;
      }
    }

    return {
      'dailyTotal': dailyTotal,
      'dailyVisits': dailyVisits,
      'weeklyTotal': weeklyTotal,
      'weeklyVisits': weeklyVisits,
      'monthlyTotal': monthlyTotal,
      'monthlyVisits': monthlyVisits,
      'lifetimeTotal': lifetimeTotal,
      'lifetimeVisits': lifetimeVisits,
      // Active period breakdown
      'filteredRevenue': totalRevenue,
      'filteredVisits': filteredInvoices.length,
      'consultationTotal': consultationTotal,
      'xrayTotal': xrayTotal,
      'pharmacyTotal': pharmacyTotal,
      'cashTotal': cashTotal,
      'upiTotal': upiTotal,
      'cardTotal': cardTotal,
      'pendingTotal': pendingTotal,
      'invoices': filteredInvoices,
    };
  }

  // Stock summary
  Map<String, dynamic> getStockSummary() {
    int totalItems = _inventory.length;
    int lowStockCount = _inventory.where((i) => i.isLowStock).length;
    int expiringSoonCount = _inventory.where((i) => i.isExpiringSoon).length;
    double totalValuation = _inventory.fold(0.0, (acc, i) => acc + (i.unitPrice * i.quantity));

    return {
      'totalItems': totalItems,
      'lowStockCount': lowStockCount,
      'expiringSoonCount': expiringSoonCount,
      'totalValuation': totalValuation,
    };
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('manjaly_patients', jsonEncode(_patients.map((p) => p.toJson()).toList()));
      await prefs.setString('manjaly_appointments', jsonEncode(_appointments.map((a) => a.toJson()).toList()));
      await prefs.setString('manjaly_invoices', jsonEncode(_invoices.map((i) => i.toJson()).toList()));
      await prefs.setString('manjaly_inventory', jsonEncode(_inventory.map((i) => i.toJson()).toList()));
    } catch (e) {
      debugPrint('Persistence error: $e');
    }
  }

  // --- Seed Data Generator ---

  void _seedPatients() {
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _patients.clear();
    _patients.addAll([
      Patient(
        id: 'PAT-1001',
        opNumber: 'OP-401',
        name: 'Rajesh Kumar',
        phone: '9845012345',
        email: 'rajesh.k@gmail.com',
        dob: '1988-04-12',
        age: 38,
        gender: 'Male',
        address: 'MG Road, Bangalore',
        doctor: 'Dr. Sanju Antony',
        medicalHistory: 'Hypertension',
        drugAllergies: 'Penicillin',
        diseaseHistory: 'Molar Sensitivity & Cavity',
        registrationDate: '2026-09-10',
        totalVisits: 3,
        totalBilled: 2150.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Dr. Sanju Antony', notes: 'Root Canal filling checkup & cleaning', invoiceId: 'INV-2026-001', amount: 850.0),
          VisitRecord(date: '2026-10-05', doctor: 'Dr. Sanju Antony', notes: 'Composite restoration tooth 16', invoiceId: 'INV-2026-005', amount: 800.0),
          VisitRecord(date: '2026-09-10', doctor: 'Dr. Sanju Antony', notes: 'First consultation and RVG X-Ray', invoiceId: 'INV-2026-012', amount: 500.0),
        ],
      ),
      Patient(
        id: 'PAT-1002',
        opNumber: 'OP-402',
        name: 'Ananya Sharma',
        phone: '9741234567',
        email: 'ananya.s@yahoo.com',
        dob: '1995-08-23',
        age: 31,
        gender: 'Female',
        address: 'Indiranagar 1st Stage',
        doctor: 'Dr. Sanju Antony',
        medicalHistory: 'None',
        drugAllergies: 'None',
        diseaseHistory: 'Mild Gingivitis',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 750.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Dr. Sanju Antony', notes: 'Ultrasonic Scaling & Polishing', invoiceId: 'INV-2026-002', amount: 750.0),
        ],
      ),
      Patient(
        id: 'PAT-1003',
        opNumber: 'OP-403',
        name: 'Mohammed Farooq',
        phone: '9988776655',
        email: 'farooq.m@gmail.com',
        dob: '1979-11-04',
        age: 46,
        gender: 'Male',
        address: 'Frazer Town, Bangalore',
        doctor: 'Dr. Sanju Antony',
        medicalHistory: 'Type 2 Diabetes',
        drugAllergies: 'Aspirin',
        diseaseHistory: 'Missing Lower Molar, Periodontitis',
        registrationDate: '2026-10-15',
        totalVisits: 2,
        totalBilled: 3400.0,
        visits: [
          VisitRecord(date: '2026-10-18', doctor: 'Dr. Sanju Antony', notes: 'Crown fitting & occlusion check', invoiceId: 'INV-2026-003', amount: 2800.0),
          VisitRecord(date: '2026-10-15', doctor: 'Dr. Sanju Antony', notes: 'Impression & preparation', invoiceId: 'INV-2026-004', amount: 600.0),
        ],
      ),
      Patient(
        id: 'PAT-1004',
        opNumber: 'OP-404',
        name: 'Priya Nair',
        phone: '9845566778',
        email: 'priya.nair@outlook.com',
        dob: '2001-02-14',
        age: 25,
        gender: 'Female',
        address: 'Koramangala 4th Block',
        doctor: 'Dr. Sanju Antony',
        medicalHistory: 'Asthma',
        drugAllergies: 'None',
        diseaseHistory: 'Wisdom Tooth Impaction',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 1200.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Dr. Sanju Antony', notes: 'OPG X-Ray and Consultation for third molar', invoiceId: 'INV-2026-006', amount: 1200.0),
        ],
      ),
    ]);
  }

  void _seedAppointments() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
    final nextWeekStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 3)));

    _appointments.clear();
    _appointments.addAll([
      Appointment(
        id: 'APT-2001',
        patientName: 'Rajesh Kumar',
        phone: '9845012345',
        doctor: 'Dr. Sanju Antony',
        date: todayStr,
        timeSlot: '10:00 AM',
        reason: 'Root Canal Followup & Crown Cementation',
        status: 'Upcoming',
        notes: 'Review sensitivity in tooth 16',
      ),
      Appointment(
        id: 'APT-2002',
        patientName: 'Ananya Sharma',
        phone: '9741234567',
        doctor: 'Dr. Sanju Antony',
        date: todayStr,
        timeSlot: '11:30 AM',
        reason: 'Teeth Whitening Consultation',
        status: 'Completed',
        notes: 'Cleaning completed, shades assessed',
      ),
      Appointment(
        id: 'APT-2003',
        patientName: 'Mohammed Farooq',
        phone: '9988776655',
        doctor: 'Dr. Sanju Antony',
        date: tomorrowStr,
        timeSlot: '04:00 PM',
        reason: 'Implant Post-Op Review',
        status: 'Upcoming',
        notes: 'Ensure blood sugar fasting report is brought',
      ),
      Appointment(
        id: 'APT-2004',
        patientName: 'Priya Nair',
        phone: '9845566778',
        doctor: 'Dr. Sanju Antony',
        date: nextWeekStr,
        timeSlot: '02:30 PM',
        reason: 'Surgical Extraction of Impacted Wisdom Tooth',
        status: 'Upcoming',
        notes: 'Local anesthesia prep',
      ),
    ]);
  }

  void _seedInvoices() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    final threeDaysAgoStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 3)));

    _invoices.clear();
    _invoices.addAll([
      Invoice(
        id: 'INV-2026-001',
        patientName: 'Rajesh Kumar',
        phone: '9845012345',
        doctor: 'Dr. Sanju Antony',
        date: todayStr,
        consultationCharge: 350.0,
        xrayCharge: 200.0,
        pharmacyCharge: 300.0,
        totalAmount: 850.0,
        paymentMode: 'UPI / Online',
        notes: 'Routine cleaning and RVG radiograph',
      ),
      Invoice(
        id: 'INV-2026-002',
        patientName: 'Ananya Sharma',
        phone: '9741234567',
        doctor: 'Dr. Sanju Antony',
        date: todayStr,
        consultationCharge: 400.0,
        xrayCharge: 0.0,
        pharmacyCharge: 350.0,
        totalAmount: 750.0,
        paymentMode: 'Cash',
        notes: 'Ultrasonic scaling, prescription for gingivitis',
      ),
      Invoice(
        id: 'INV-2026-003',
        patientName: 'Mohammed Farooq',
        phone: '9988776655',
        doctor: 'Dr. Sanju Antony',
        date: yesterdayStr,
        consultationCharge: 500.0,
        xrayCharge: 300.0,
        pharmacyCharge: 2000.0,
        totalAmount: 2800.0,
        paymentMode: 'Card',
        notes: 'Zirconia crown fitting & bite test',
      ),
      Invoice(
        id: 'INV-2026-006',
        patientName: 'Priya Nair',
        phone: '9845566778',
        doctor: 'Dr. Sanju Antony',
        date: threeDaysAgoStr,
        consultationCharge: 400.0,
        xrayCharge: 500.0,
        pharmacyCharge: 300.0,
        totalAmount: 1200.0,
        paymentMode: 'UPI / Online',
        notes: 'OPG Full Jaw Panoramic X-Ray',
      ),
    ]);
  }

  void _seedInventory() {
    _inventory.clear();
    _inventory.addAll([
      InventoryItem(
        id: 'MED-101',
        name: 'Amoxicillin & Clavulanate 625mg',
        category: 'Medicines',
        batch: 'AMX-2026-88',
        expiryDate: '2027-06-30',
        unitPrice: 165.0,
        quantity: 85,
        minStockThreshold: 15,
      ),
      InventoryItem(
        id: 'MED-102',
        name: 'Lignocaine 2% + Adrenaline Cartridges',
        category: 'Anesthetics',
        batch: 'LIG-9041',
        expiryDate: '2027-01-15',
        unitPrice: 35.0,
        quantity: 120,
        minStockThreshold: 25,
      ),
      InventoryItem(
        id: 'MED-103',
        name: 'Microhybrid Dental Composite Kit (A2)',
        category: 'Dental Materials',
        batch: 'DCP-302',
        expiryDate: '2026-12-31',
        unitPrice: 1850.0,
        quantity: 4, // Low stock
        minStockThreshold: 5,
      ),
      InventoryItem(
        id: 'MED-104',
        name: 'Disposable Patient Dental Bibs (Pk of 100)',
        category: 'Consumables',
        batch: 'BIB-112',
        expiryDate: '2029-10-20',
        unitPrice: 320.0,
        quantity: 18,
        minStockThreshold: 10,
      ),
      InventoryItem(
        id: 'MED-105',
        name: 'Chlorhexidine 0.2% Antiseptic Mouthwash',
        category: 'Medicines',
        batch: 'CHX-703',
        expiryDate: '2026-11-15', // Expiring soon (<90 days)
        unitPrice: 120.0,
        quantity: 6, // Low stock + expiring soon
        minStockThreshold: 10,
      ),
      InventoryItem(
        id: 'MED-106',
        name: 'Ketorolac Tromethamine 10mg (Pain Relief)',
        category: 'Medicines',
        batch: 'KTR-554',
        expiryDate: '2027-08-10',
        unitPrice: 85.0,
        quantity: 50,
        minStockThreshold: 15,
      ),
    ]);
  }
}
