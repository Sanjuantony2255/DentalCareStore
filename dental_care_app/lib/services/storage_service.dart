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

  String _userRole = 'staff'; // Always opens in staff mode
  bool _initialized = false;

  List<Patient> get patients => List.unmodifiable(_patients);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<Invoice> get invoices => List.unmodifiable(_invoices);
  List<InventoryItem> get inventory => List.unmodifiable(_inventory);

  String get userRole => _userRole;
  bool get isAdmin => _userRole == 'admin';

  Future<void> setUserRole(String role) async {
    _userRole = (role == 'admin') ? 'admin' : 'staff';
    notifyListeners();
  }

  static bool isDummyPatient(String name, String phone, String id) {
    final n = name.trim().toLowerCase();
    final p = phone.trim();
    return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
        n == 'gokul' || n == 'manu' || n == 'anju' || n == 'albin' ||
        n == 'deepak' || n == 'sanju' || n == 'sam' || n == 'neha' || n == 'saran' ||
        p == '9845012345' || p == '9876543210' || p == '9998887776' ||
        p == '133564456156' || id == 'PAT-133564456156' || id == 'PAT-1001' || id == 'PAT-9876543210';
  }

  static bool isDummyAppointment(String id, String name, String phone) {
    final n = name.trim().toLowerCase();
    final p = phone.trim();
    return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
        n == 'gokul' || n == 'manu' || n == 'anju' || n == 'albin' ||
        n == 'deepak' || n == 'sanju' || n == 'sam' || n == 'neha' || n == 'saran' ||
        p == '9845012345' || p == '9876543210' || p == '9998887776' ||
        id.contains('20261024-00') || id == 'APT-20261014-4821' || id == 'APT-20261013-2755';
  }

  static bool isDummyInvoice(String id, String name) {
    final n = name.trim().toLowerCase();
    return n == 'rajesh kumar' || n == 'ramesh kumar' || n == 'test patient' ||
        n == 'gokul' || n == 'manu' || n == 'anju' || n == 'albin' ||
        n == 'deepak' || n == 'sanju' || n == 'sam' || n == 'neha' || n == 'saran' ||
        id == 'INV-2026-001' || id == 'INV-20261013-3604' || id == 'INV-20261013-3503' ||
        id == 'INV-20261013-2386' || id == 'INV-20261014-9713';
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      // App always opens in staff mode per clinic security requirements
      _userRole = 'staff';
      try {
        await prefs.remove('manjaly_user_role');
      } catch (_) {}

      final patientsJson = prefs.getString('manjaly_patients');
      final appointmentsJson = prefs.getString('manjaly_appointments');
      final invoicesJson = prefs.getString('manjaly_invoices');
      final inventoryJson = prefs.getString('manjaly_inventory');

      if (patientsJson != null && patientsJson.isNotEmpty) {
        final List list = jsonDecode(patientsJson);
        _patients.clear();
        for (final e in list) {
          final p = Patient.fromJson(e);
          if (!isDummyPatient(p.name, p.phone, p.id)) {
            _patients.add(p);
          }
        }
      } else {
        _patients.clear();
      }

      if (appointmentsJson != null && appointmentsJson.isNotEmpty) {
        final List list = jsonDecode(appointmentsJson);
        _appointments.clear();
        for (final e in list) {
          final a = Appointment.fromJson(e);
          if (!isDummyAppointment(a.id, a.patientName, a.phone)) {
            _appointments.add(a);
          }
        }
      } else {
        _appointments.clear();
      }

      if (invoicesJson != null && invoicesJson.isNotEmpty) {
        final List list = jsonDecode(invoicesJson);
        _invoices.clear();
        for (final e in list) {
          final i = Invoice.fromJson(e);
          if (!isDummyInvoice(i.id, i.patientName)) {
            _invoices.add(i);
          }
        }
      } else {
        _invoices.clear();
      }

      if (inventoryJson != null && inventoryJson.isNotEmpty) {
        final List list = jsonDecode(inventoryJson);
        _inventory.clear();
        _inventory.addAll(list.map((e) => InventoryItem.fromJson(e)));
      } else {
        _inventory.clear();
      }

      // Sanitize any previously cached dummy entries from local disk
      _patients.removeWhere((p) => isDummyPatient(p.name, p.phone, p.id));
      _appointments.removeWhere((a) => isDummyAppointment(a.id, a.patientName, a.phone));
      _invoices.removeWhere((i) => isDummyInvoice(i.id, i.patientName));
    } catch (e) {
      _patients.clear();
      _appointments.clear();
      _invoices.clear();
      _inventory.clear();
    }

    _initialized = true;
    notifyListeners();

    // Auto-sync with connected Google Sheet in background
    syncWithCloud();
  }

  /// Syncs app state directly with connected Google Sheet cloud database
  Future<bool> syncWithCloud() async {
    try {
      final data = await ApiService.fetchCloudData();
      final cloudPatients = data['patients'] as List<Patient>? ?? [];
      final cloudAppointments = data['appointments'] as List<Appointment>? ?? [];
      final cloudInvoices = data['invoices'] as List<Invoice>? ?? [];
      final cloudInventory = data['inventory'] as List<InventoryItem>? ?? [];

      // Purge any dummy data
      _patients.removeWhere((p) => isDummyPatient(p.name, p.phone, p.id));
      _appointments.removeWhere((a) => isDummyAppointment(a.id, a.patientName, a.phone));
      _invoices.removeWhere((i) => isDummyInvoice(i.id, i.patientName));

      // Sync Patients from Google Sheet - strictly reflect Google Sheet state
      final localCreatedPat = _patients.where((p) => p.id.startsWith('PAT-LOCAL-')).toList();
      _patients.clear();
      _patients.addAll(cloudPatients);
      for (final loc in localCreatedPat) {
        if (!_patients.any((p) => p.id == loc.id || (p.phone.isNotEmpty && p.phone == loc.phone))) {
          _patients.insert(0, loc);
        }
      }

      // Sync Appointments from Google Sheet
      final localCreated = _appointments.where((a) => a.id.startsWith('APT-LOCAL-')).toList();
      _appointments.clear();
      _appointments.addAll(cloudAppointments);
      for (final loc in localCreated) {
        if (!_appointments.any((a) => a.id == loc.id)) {
          _appointments.insert(0, loc);
        }
      }

      // Sync Invoices from Google Sheet
      final localCreatedInv = _invoices.where((i) => i.id.startsWith('INV-LOCAL-')).toList();
      _invoices.clear();
      _invoices.addAll(cloudInvoices);
      for (final loc in localCreatedInv) {
        if (!_invoices.any((i) => i.id == loc.id)) {
          _invoices.insert(0, loc);
        }
      }

      // Sync Inventory from Google Sheet
      _inventory.clear();
      _inventory.addAll(cloudInventory);

      await _persist();
      notifyListeners();
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
}
