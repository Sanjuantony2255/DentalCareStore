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

  static bool isDummyPatient(String name, String phone, String id) {
    final n = name.trim().toLowerCase();
    final p = phone.trim();
    return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
        p == '9845012345' || p == '9876543210' || p == '9998887776' ||
        id == 'PAT-1001' || id == 'PAT-9876543210';
  }

  static bool isDummyAppointment(String id, String name, String phone) {
    final n = name.trim().toLowerCase();
    final p = phone.trim();
    return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
        p == '9845012345' || p == '9876543210' || p == '9998887776' ||
        id.contains('20261024-00');
  }

  static bool isDummyInvoice(String id, String name) {
    final n = name.trim().toLowerCase();
    return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
        id == 'INV-2026-001' || id == 'INV-20261013-3604' || id == 'INV-20261013-3503';
  }

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
        _seedRealClinicPatients();
      }

      if (appointmentsJson != null && appointmentsJson.isNotEmpty) {
        final List list = jsonDecode(appointmentsJson);
        _appointments.clear();
        _appointments.addAll(list.map((e) => Appointment.fromJson(e)));
      } else {
        _seedRealClinicAppointments();
      }

      if (invoicesJson != null && invoicesJson.isNotEmpty) {
        final List list = jsonDecode(invoicesJson);
        _invoices.clear();
        _invoices.addAll(list.map((e) => Invoice.fromJson(e)));
      } else {
        _seedRealClinicInvoices();
      }

      if (inventoryJson != null && inventoryJson.isNotEmpty) {
        final List list = jsonDecode(inventoryJson);
        _inventory.clear();
        _inventory.addAll(list.map((e) => InventoryItem.fromJson(e)));
      } else {
        _seedRealClinicInventory();
      }

      // Sanitize any previously cached dummy entries from local disk
      _patients.removeWhere((p) => isDummyPatient(p.name, p.phone, p.id));
      _appointments.removeWhere((a) => isDummyAppointment(a.id, a.patientName, a.phone));
      _invoices.removeWhere((i) => isDummyInvoice(i.id, i.patientName));
    } catch (e) {
      _seedRealClinicPatients();
      _seedRealClinicAppointments();
      _seedRealClinicInvoices();
      _seedRealClinicInventory();
    }

    _initialized = true;
    notifyListeners();

    // Auto-sync with connected GitHub Cloud & Google Sheet in background
    syncWithCloud();
  }

  /// Syncs app state directly with GitHub Cloud repository and Google Sheet
  Future<bool> syncWithCloud() async {
    try {
      final data = await ApiService.fetchCloudData();
      final cloudPatients = data['patients'] as List<Patient>? ?? [];
      final cloudAppointments = data['appointments'] as List<Appointment>? ?? [];
      final cloudInvoices = data['invoices'] as List<Invoice>? ?? [];
      final cloudInventory = data['inventory'] as List<InventoryItem>? ?? [];

      bool changed = false;

      // Purge any dummy data
      _patients.removeWhere((p) => isDummyPatient(p.name, p.phone, p.id));
      _appointments.removeWhere((a) => isDummyAppointment(a.id, a.patientName, a.phone));
      _invoices.removeWhere((i) => isDummyInvoice(i.id, i.patientName));

      // Sync Patients from Google Sheet
      if (cloudPatients.isNotEmpty) {
        final localCreatedPat = _patients.where((p) => p.id.startsWith('PAT-LOCAL-')).toList();
        _patients.clear();
        _patients.addAll(cloudPatients);
        for (final loc in localCreatedPat) {
          if (!_patients.any((p) => p.id == loc.id || (p.phone.isNotEmpty && p.phone == loc.phone))) {
            _patients.insert(0, loc);
          }
        }
        changed = true;
      }

      // Sync Appointments from Google Sheet
      if (cloudAppointments.isNotEmpty) {
        // Replace with live Google Sheet appointments while keeping unsynced local creations
        final localCreated = _appointments.where((a) => a.id.startsWith('APT-LOCAL-')).toList();
        _appointments.clear();
        _appointments.addAll(cloudAppointments);
        for (final loc in localCreated) {
          if (!_appointments.any((a) => a.id == loc.id)) {
            _appointments.insert(0, loc);
          }
        }
        changed = true;
      }

      // Sync Invoices from Google Sheet
      if (cloudInvoices.isNotEmpty) {
        final localCreatedInv = _invoices.where((i) => i.id.startsWith('INV-LOCAL-')).toList();
        _invoices.clear();
        _invoices.addAll(cloudInvoices);
        for (final loc in localCreatedInv) {
          if (!_invoices.any((i) => i.id == loc.id)) {
            _invoices.insert(0, loc);
          }
        }
        changed = true;
      }

      // Sync Inventory from Google Sheet
      if (cloudInventory.isNotEmpty) {
        _inventory.clear();
        _inventory.addAll(cloudInventory);
        changed = true;
      }

      if (changed || _patients.isNotEmpty) {
        await _persist();
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Cloud sync notice: $e');
      return false;
    }
  }

  /// Alias for backward compatibility
  Future<bool> syncWithGoogleSheet() async {
    return syncWithCloud();
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

    // Push to Google Cloud in background
    ApiService.syncAppointmentOnline(apt);
  }

  Future<void> updateAppointmentStatus(String id, String newStatus) async {
    final apt = _appointments.firstWhere((a) => a.id == id, orElse: () => Appointment(id: '', patientName: '', phone: '', doctor: '', date: '', timeSlot: ''));
    if (apt.id.isNotEmpty) {
      apt.status = newStatus;
      await _persist();
      notifyListeners();

      // Push update to Google Cloud
      ApiService.updateAppointmentStatusOnline(apt.id, newStatus);
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

      // Push reschedule to Google Cloud
      ApiService.rescheduleAppointmentOnline(apt.id, apt.phone, newDate, newTime, doctor, notes);
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

  // --- Real Clinic Baseline Dataset (Used if offline before first cloud sync) ---

  void _seedRealClinicPatients() {
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _patients.clear();
    _patients.addAll([
      Patient(
        id: 'PAT-133564456156',
        opNumber: 'OP-102',
        name: 'Gokul',
        phone: '133564456156',
        email: '',
        dob: '1994-06-12',
        age: 32,
        gender: 'Male',
        address: 'Clinic Outstation',
        doctor: 'JS',
        medicalHistory: 'None',
        drugAllergies: 'None',
        diseaseHistory: 'SCALING & DENTAL RADIOGRAPHS',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 1000.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'JS', notes: 'Consultation & X-Ray checkup', invoiceId: 'INV-20261014-9713', amount: 1000.0),
        ],
      ),
      Patient(
        id: 'PAT-8921399907-M',
        opNumber: 'OP-103',
        name: 'Manu',
        phone: '8921399907',
        email: '157 gorge rd east',
        dob: '2006-03-10',
        age: 20,
        gender: 'Male',
        address: '157 Gorge Rd East',
        doctor: 'sa',
        medicalHistory: 'None',
        drugAllergies: 'None',
        diseaseHistory: 'CROWN PFM',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 950.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'sa', notes: 'Crown fitting & occlusion review', invoiceId: 'INV-20261014-4626', amount: 950.0),
        ],
      ),
      Patient(
        id: 'PAT-7356511107-A',
        opNumber: 'OP-104',
        name: 'Anju',
        phone: '7356511107',
        email: '157 gorge rd east',
        dob: '2008-07-22',
        age: 18,
        gender: 'Female',
        address: '157 Gorge Rd East',
        doctor: 'Neha',
        medicalHistory: 'Thyroid Disorder',
        drugAllergies: 'None',
        diseaseHistory: 'CLEAR ALIGNERS Consultation',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 950.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Neha', notes: 'Orthodontic evaluation and scanning', invoiceId: 'INV-20261014-6363', amount: 950.0),
        ],
      ),
      Patient(
        id: 'PAT-8921399908',
        opNumber: 'OP-105',
        name: 'Albin',
        phone: '8921399908',
        email: '157 gorge rd north',
        dob: '1996-01-15',
        age: 30,
        gender: 'Male',
        address: '157 Gorge Rd North',
        doctor: 'Anu',
        medicalHistory: 'Kidney / Liver Disease',
        drugAllergies: 'None',
        diseaseHistory: 'NORMAL EXTRACTION',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 450.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Anu', notes: 'Post extraction checkup & dressing', invoiceId: 'INV-20261014-5916', amount: 450.0),
        ],
      ),
      Patient(
        id: 'PAT-7827789812',
        opNumber: 'OP-106',
        name: 'Akhil',
        phone: '7827789812',
        email: 'akhil@gmail.com',
        dob: '1998-11-20',
        age: 28,
        gender: 'Male',
        address: 'Town Square',
        doctor: 'Dr. Jeswin Jose BDS',
        medicalHistory: 'None',
        drugAllergies: 'None',
        diseaseHistory: 'COMPOSITE & BLEACHING',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 950.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Dr. Jeswin Jose BDS', notes: 'Aesthetic composite veneer and bleaching', invoiceId: 'INV-20261014-4185', amount: 950.0),
        ],
      ),
      Patient(
        id: 'PAT-7356511107-D',
        opNumber: 'OP-107',
        name: 'Deepak',
        phone: '7356511107',
        email: 'deepak@gmail.com',
        dob: '1996-02-01',
        age: 30,
        gender: 'Male',
        address: 'Clinic Vicinity',
        doctor: 'Dr. Jeswin Jose BDS',
        medicalHistory: 'None',
        drugAllergies: 'None',
        diseaseHistory: 'SCALING & POLISHING',
        registrationDate: nowStr,
        totalVisits: 2,
        totalBilled: 350.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Dr. Jeswin Jose BDS', notes: 'Ultrasonic scaling & polishing', invoiceId: 'INV-20261013-3882', amount: 300.0),
          VisitRecord(date: nowStr, doctor: 'js', notes: 'Consultation', invoiceId: 'INV-20261013-2386', amount: 50.0),
        ],
      ),
      Patient(
        id: 'PAT-8921399907-S',
        opNumber: 'OP-108',
        name: 'Sanju',
        phone: '8921399907',
        email: 'sanjuantony01@gmail.com',
        dob: '2001-02-02',
        age: 25,
        gender: 'Male',
        address: 'Manjaly House',
        doctor: 'Dr. Jeswin',
        medicalHistory: 'None',
        drugAllergies: 'None',
        diseaseHistory: 'DENTAL RADIOGRAPHS & RVG',
        registrationDate: nowStr,
        totalVisits: 2,
        totalBilled: 200.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'sa', notes: 'Dental radiograph series', invoiceId: 'INV-20261013-2595', amount: 100.0),
          VisitRecord(date: nowStr, doctor: 'ds', notes: 'Pharmacy medication delivery', invoiceId: 'INV-20261013-4516', amount: 100.0),
        ],
      ),
      Patient(
        id: 'PAT-8921399907-SAM',
        opNumber: 'OP-109',
        name: 'Sam',
        phone: '8921399907',
        email: 'sam@gmail.com',
        dob: '2001-02-02',
        age: 25,
        gender: 'Male',
        address: 'Central Street',
        doctor: 'Dr. JJ',
        medicalHistory: 'None',
        drugAllergies: 'None',
        diseaseHistory: 'CONSULTATION',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 350.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Dr. JJ', notes: 'Full oral examination', invoiceId: 'INV-20261024-101', amount: 350.0),
        ],
      ),
      Patient(
        id: 'PAT-9072467117',
        opNumber: 'OP-110',
        name: 'Jeswin Jose',
        phone: '9072467117',
        email: 'jeswin@gmail.com',
        dob: '1997-05-17',
        age: 29,
        gender: 'Male',
        address: 'High Street',
        doctor: 'Dr. Jeswin Jose BDS',
        medicalHistory: 'None',
        drugAllergies: 'None',
        diseaseHistory: 'SPECIALIST CONSULTATION & RVG',
        registrationDate: nowStr,
        totalVisits: 1,
        totalBilled: 300.0,
        visits: [
          VisitRecord(date: nowStr, doctor: 'Dr. Jeswin Jose BDS', notes: 'OPG Digital X-Ray', invoiceId: 'INV-20261013-4322', amount: 300.0),
        ],
      ),
    ]);
  }

  void _seedRealClinicAppointments() {
    _appointments.clear();
    _appointments.addAll([
      Appointment(
        id: 'APT-20261014-4821',
        patientName: 'Sam',
        phone: '8921399907',
        doctor: 'Dr. JJ',
        date: '2026-10-14',
        timeSlot: '10:00 AM',
        reason: 'General Consultation & Checkup',
        status: 'Scheduled',
        notes: '',
      ),
      Appointment(
        id: 'APT-20261013-2755',
        patientName: 'Sanju',
        phone: '7356511107',
        doctor: 'deepak',
        date: '2026-11-01',
        timeSlot: '10:00 AM',
        reason: 'General Consultation & Checkup',
        status: 'Cancelled',
        notes: '',
      ),
      Appointment(
        id: 'APT-20261016-8860',
        patientName: 'Deepak',
        phone: '7356511107',
        doctor: 'js',
        date: '2026-12-16',
        timeSlot: '10:00 AM',
        reason: 'General Consultation & Checkup',
        status: 'Rescheduled',
        notes: '',
      ),
      Appointment(
        id: 'APT-20261018-1081',
        patientName: 'Test',
        phone: '1234567890',
        doctor: 'sa',
        date: '2028-02-25',
        timeSlot: '10:00 AM',
        reason: 'Consultation & Checkup',
        status: 'Rescheduled',
        notes: '',
      ),
      Appointment(
        id: 'APT-20261014-1337',
        patientName: 'Sanju',
        phone: '8921399907',
        doctor: 'Ak',
        date: '2026-11-11',
        timeSlot: '10:00 AM',
        reason: 'Dental X-Ray & Diagnostics',
        status: 'Rescheduled',
        notes: '',
      ),
      Appointment(
        id: 'APT-20261013-2831',
        patientName: 'Deepak',
        phone: '7356511107',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-11-13',
        timeSlot: '10:00 AM',
        reason: 'General Consultation & Checkup',
        status: 'Rescheduled',
        notes: '',
      ),
      Appointment(
        id: 'APT-20261014-1667',
        patientName: 'Neha',
        phone: '3235646544',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2027-02-02',
        timeSlot: '10:00 AM',
        reason: 'General Consultation & Checkup',
        status: 'Rescheduled',
        notes: '',
      ),
    ]);
  }

  void _seedRealClinicInvoices() {
    _invoices.clear();
    _invoices.addAll([
      Invoice(
        id: 'INV-20261013-2386',
        patientName: 'Deepak',
        phone: '8921399907',
        doctor: 'js',
        date: '2026-10-13',
        consultationCharge: 50.0,
        xrayCharge: 0.0,
        pharmacyCharge: 0.0,
        totalAmount: 50.0,
        paymentMode: 'UPI / Online',
      ),
      Invoice(
        id: 'INV-20261013-2595',
        patientName: 'Sanju',
        phone: '8921399907',
        doctor: 'sa',
        date: '2026-10-13',
        consultationCharge: 0.0,
        xrayCharge: 100.0,
        pharmacyCharge: 0.0,
        totalAmount: 100.0,
        paymentMode: 'UPI / Online',
      ),
      Invoice(
        id: 'INV-20261013-4516',
        patientName: 'Sanju',
        phone: '8921399907',
        doctor: 'ds',
        date: '2026-10-13',
        consultationCharge: 0.0,
        xrayCharge: 0.0,
        pharmacyCharge: 100.0,
        totalAmount: 100.0,
        paymentMode: 'Pending',
      ),
      Invoice(
        id: 'INV-20261013-3882',
        patientName: 'Deepak',
        phone: '7356511107',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-13',
        consultationCharge: 300.0,
        xrayCharge: 0.0,
        pharmacyCharge: 0.0,
        totalAmount: 300.0,
        paymentMode: 'Cash',
      ),
      Invoice(
        id: 'INV-20261013-1783',
        patientName: 'Saran',
        phone: '7827789812',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-13',
        consultationCharge: 0.0,
        xrayCharge: 0.0,
        pharmacyCharge: 500.0,
        totalAmount: 500.0,
        paymentMode: 'Cash',
      ),
      Invoice(
        id: 'INV-20261013-4322',
        patientName: 'Jeswin jose',
        phone: '9072467117',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-13',
        consultationCharge: 200.0,
        xrayCharge: 100.0,
        pharmacyCharge: 0.0,
        totalAmount: 300.0,
        paymentMode: 'Cash',
      ),
      Invoice(
        id: 'INV-20261014-9713',
        patientName: 'Gokul',
        phone: '133564456156',
        doctor: 'JS',
        date: '2026-10-14',
        consultationCharge: 200.0,
        xrayCharge: 300.0,
        pharmacyCharge: 500.0,
        totalAmount: 1000.0,
        paymentMode: 'Cash',
      ),
      Invoice(
        id: 'INV-20261014-4626',
        patientName: 'Manu',
        phone: '8921399907',
        doctor: 'sa',
        date: '2026-10-14',
        consultationCharge: 500.0,
        xrayCharge: 250.0,
        pharmacyCharge: 200.0,
        totalAmount: 950.0,
        paymentMode: 'Cash',
      ),
      Invoice(
        id: 'INV-20261014-6363',
        patientName: 'Anju',
        phone: '7356511107',
        doctor: 'Neha',
        date: '2026-10-14',
        consultationCharge: 500.0,
        xrayCharge: 250.0,
        pharmacyCharge: 200.0,
        totalAmount: 950.0,
        paymentMode: 'Card',
      ),
      Invoice(
        id: 'INV-20261014-5916',
        patientName: 'Albin',
        phone: '8921399908',
        doctor: 'Anu',
        date: '2026-10-14',
        consultationCharge: 0.0,
        xrayCharge: 250.0,
        pharmacyCharge: 200.0,
        totalAmount: 450.0,
        paymentMode: 'Cash',
      ),
      Invoice(
        id: 'INV-20261014-4185',
        patientName: 'Akhil',
        phone: '7827789812',
        doctor: 'Dr. Jeswin Jose BDS',
        date: '2026-10-14',
        consultationCharge: 500.0,
        xrayCharge: 250.0,
        pharmacyCharge: 200.0,
        totalAmount: 950.0,
        paymentMode: 'Cash',
      ),
    ]);
  }

  void _seedRealClinicInventory() {
    _inventory.clear();
    _inventory.addAll([
      InventoryItem(
        id: 'MED-1001',
        name: 'Amoxicillin 500mg (Cap)',
        category: 'Antibiotics',
        batch: 'AMX-2026-A1',
        expiryDate: '2027-06-30',
        unitPrice: 8.50,
        quantity: 250,
        minStockThreshold: 50,
      ),
      InventoryItem(
        id: 'MED-1002',
        name: 'Aceclofenac + Paracetamol (Tab)',
        category: 'Analgesics',
        batch: 'ACP-2026-B4',
        expiryDate: '2027-10-15',
        unitPrice: 6.00,
        quantity: 320,
        minStockThreshold: 60,
      ),
      InventoryItem(
        id: 'MED-1003',
        name: 'Metronidazole 400mg (Tab)',
        category: 'Antibiotics',
        batch: 'MTZ-2026-09',
        expiryDate: '2026-12-31',
        unitPrice: 4.50,
        quantity: 180,
        minStockThreshold: 40,
      ),
      InventoryItem(
        id: 'MED-1004',
        name: 'Lidocaine 2% + Adrenaline (Vial)',
        category: 'Anesthesia',
        batch: 'LID-2025-C8',
        expiryDate: '2027-04-20',
        unitPrice: 45.00,
        quantity: 75,
        minStockThreshold: 20,
      ),
      InventoryItem(
        id: 'MED-1005',
        name: 'Chlorhexidine 0.2% Mouthwash 150ml',
        category: 'Antiseptic Oral',
        batch: 'CHX-2026-D1',
        expiryDate: '2027-08-30',
        unitPrice: 110.00,
        quantity: 45,
        minStockThreshold: 15,
      ),
      InventoryItem(
        id: 'MED-1006',
        name: 'Dental Composite Resin Shade A2',
        category: 'Filling Material',
        batch: 'RES-2025-X2',
        expiryDate: '2027-11-20',
        unitPrice: 850.00,
        quantity: 18,
        minStockThreshold: 5,
      ),
      InventoryItem(
        id: 'MED-1007',
        name: 'Eugenol Liquid 15ml',
        category: 'Sedative Dressing',
        batch: 'EUG-2025-E4',
        expiryDate: '2028-02-15',
        unitPrice: 120.00,
        quantity: 22,
        minStockThreshold: 5,
      ),
      InventoryItem(
        id: 'MED-1008',
        name: 'Cotton Rolls Pack 500s',
        category: 'Consumables',
        batch: 'COT-2026-01',
        expiryDate: '2029-01-01',
        unitPrice: 160.00,
        quantity: 35,
        minStockThreshold: 10,
      ),
      InventoryItem(
        id: 'MED-1009',
        name: 'Dental Disposable Needles 30G',
        category: 'Surgical Consumables',
        batch: 'NDL-2026-N9',
        expiryDate: '2028-06-30',
        unitPrice: 5.00,
        quantity: 400,
        minStockThreshold: 100,
      ),
      InventoryItem(
        id: 'MED-1010',
        name: 'Orthodontic Relief Wax Pack',
        category: 'Oral Hygiene',
        batch: 'WAX-2026-W3',
        expiryDate: '2028-12-31',
        unitPrice: 40.00,
        quantity: 60,
        minStockThreshold: 15,
      ),
      InventoryItem(
        id: 'MED-1011',
        name: 'new',
        category: 'Antibiotics',
        batch: 'BT-117149',
        expiryDate: '2027-10-13',
        unitPrice: 100.00,
        quantity: 50,
        minStockThreshold: 20,
      ),
    ]);
  }
}
