import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../models/invoice.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/invoice_receipt_dialog.dart';
import '../constants/treatments.dart';

class RegistrationScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onNavigateToAppointments;
  final Patient? initialPatient;

  const RegistrationScreen({
    super.key,
    required this.storage,
    this.onNavigateToAppointments,
    this.initialPatient,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isRevisit = false;
  bool _isAlreadyRegistered = false;
  String? _suggestedOpNumber;
  String? _suggestedPatientName;
  DateTime _selectedDate = DateTime.now();
  final _dateController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _opController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _chiefComplaintController = TextEditingController();
  final _diseaseHistoryController = TextEditingController();
  final _drugAllergiesController = TextEditingController();
  final _consultationController = TextEditingController();
  final _xrayController = TextEditingController();
  final _pharmacyController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    if (widget.initialPatient != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _populatePatientData(widget.initialPatient!);
        }
      });
    }
  }

  String _gender = 'Male';
  String _doctor = kClinicDoctors[0];
  final _manualDoctorController = TextEditingController();
  String _medicalHistory = 'No Significant Medical History';
  String _paymentMode = 'UPI / Online';

  final _treatmentChargeController = TextEditingController();
  final List<Map<String, TextEditingController>> _customChargeRows = [];
  String? _selectedChargeDropdown;

  final List<String> _medicalHistoryOptions = [
    'No Significant Medical History',
    'Hypertension',
    'Diabetes',
    'Cardiac Condition',
    'Asthma',
    'Bleeding Disorders',
    'Pregnant / Lactating',
  ];

  final List<String> _paymentModes = [
    'Cash',
    'UPI / Online',
    'Card',
    'Payment Pending',
  ];

  @override
  void dispose() {
    _dateController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _opController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _treatmentController.dispose();
    _chiefComplaintController.dispose();
    _diseaseHistoryController.dispose();
    _drugAllergiesController.dispose();
    _manualDoctorController.dispose();
    _consultationController.dispose();
    _treatmentChargeController.dispose();
    _xrayController.dispose();
    _pharmacyController.dispose();
    _notesController.dispose();
    for (final row in _customChargeRows) {
      row['title']?.dispose();
      row['amount']?.dispose();
    }
    super.dispose();
  }

  Future<void> _selectRegistrationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), // allows selecting previous dates
      lastDate: DateTime(2100),
      helpText: 'SELECT DATE',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  double get _totalAmount {
    final c = double.tryParse(_consultationController.text) ?? 0.0;
    final t = double.tryParse(_treatmentChargeController.text) ?? 0.0;
    final x = double.tryParse(_xrayController.text) ?? 0.0;
    final p = double.tryParse(_pharmacyController.text) ?? 0.0;
    double customs = 0.0;
    for (final row in _customChargeRows) {
      customs += double.tryParse(row['amount']?.text ?? '') ?? 0.0;
    }
    return c + t + x + p + customs;
  }

  void _addCustomChargeRow([String title = '', String amount = '']) {
    setState(() {
      _customChargeRows.add({
        'title': TextEditingController(text: title),
        'amount': TextEditingController(text: amount),
      });
    });
  }

  void _removeCustomChargeRow(int index) {
    setState(() {
      if (index >= 0 && index < _customChargeRows.length) {
        final removed = _customChargeRows.removeAt(index);
        removed['title']?.dispose();
        removed['amount']?.dispose();
      }
    });
  }

  void _checkExistingPatient() {
    final cleanName = _nameController.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final qDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (qDigits.length >= 10 && cleanName.length >= 2) {
      final existing = widget.storage.patients.firstWhere(
        (p) {
          final pDigits = p.phone.replaceAll(RegExp(r'\D'), '');
          final pName = p.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
          final phoneMatch = pDigits.isNotEmpty &&
              (pDigits == qDigits || (pDigits.length >= 10 && qDigits.length >= 10 && pDigits.endsWith(qDigits.substring(qDigits.length - 10))));
          final nameMatch = pName.isNotEmpty && pName == cleanName;
          return phoneMatch && nameMatch;
        },
        orElse: () => Patient(id: '', opNumber: '', name: '', phone: '', gender: '', doctor: '', registrationDate: ''),
      );
      if (existing.id.isNotEmpty) {
        final op = existing.opNumber.isNotEmpty ? existing.opNumber : 'OP-${existing.id.replaceAll(RegExp(r'\D'), '')}';
        setState(() {
          _isAlreadyRegistered = true;
          _suggestedOpNumber = op;
          _suggestedPatientName = existing.name;
          _opController.text = op;
        });
        if (!_isRevisit) {
          _populatePatientData(existing);
        }
        return;
      }
    } else if (qDigits.length >= 10 && cleanName.isEmpty) {
      final matches = widget.storage.patients.where((p) {
        final pDigits = p.phone.replaceAll(RegExp(r'\D'), '');
        return pDigits.isNotEmpty && (pDigits == qDigits || (pDigits.length >= 10 && qDigits.length >= 10 && pDigits.endsWith(qDigits.substring(qDigits.length - 10))));
      }).toList();
      if (matches.length == 1 && !_isRevisit) {
        final p = matches.first;
        final op = p.opNumber.isNotEmpty ? p.opNumber : 'OP-${p.id.replaceAll(RegExp(r'\D'), '')}';
        setState(() {
          _isAlreadyRegistered = true;
          _suggestedOpNumber = op;
          _suggestedPatientName = p.name;
        });
        _populatePatientData(p);
        return;
      }
    }

    if (_isAlreadyRegistered) {
      setState(() {
        _isAlreadyRegistered = false;
        _suggestedOpNumber = null;
        _suggestedPatientName = null;
      });
    }
  }

  void _onPhoneChanged(String val) {
    _checkExistingPatient();
  }

  void _onNameChanged(String val) {
    _checkExistingPatient();
  }

  void _populatePatientData(Patient existing) {
    final op = existing.opNumber.isNotEmpty ? existing.opNumber : 'OP-${existing.id.replaceAll(RegExp(r'\D'), '')}';
    setState(() {
      _isRevisit = true;
      _isAlreadyRegistered = true;
      _suggestedOpNumber = op;
      _suggestedPatientName = existing.name;
      _nameController.text = existing.name;
      _phoneController.text = existing.phone;
      _opController.text = op;
      _ageController.text = existing.age > 0 ? existing.age.toString() : '';
      _emailController.text = existing.email;
      _addressController.text = existing.address;
      _gender = existing.gender.isNotEmpty ? existing.gender : 'Male';
      final existingDoc = existing.doctor.isNotEmpty ? existing.doctor : kClinicDoctors[0];
      if (kClinicDoctors.contains(existingDoc)) {
        _doctor = existingDoc;
      } else {
        _doctor = 'Other (Type Manually)';
        _manualDoctorController.text = existingDoc;
      }
      if (existing.diseaseHistory.contains(' - ')) {
        final parts = existing.diseaseHistory.split(' - ');
        _chiefComplaintController.text = parts[0].trim();
        _treatmentController.text = parts.sublist(1).join(' - ').trim();
      } else {
        _treatmentController.text = existing.diseaseHistory;
        _chiefComplaintController.text = '';
      }
      _diseaseHistoryController.text = existing.diseaseHistory;
      _drugAllergiesController.text = existing.drugAllergies == 'None' ? '' : existing.drugAllergies;
      if (_medicalHistoryOptions.contains(existing.medicalHistory)) {
        _medicalHistory = existing.medicalHistory;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Already registered patient recognized: ${existing.name} ($op)'),
        backgroundColor: AppTheme.primaryTeal,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openPatientLookupModal() {
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final qDigits = query.replaceAll(RegExp(r'\D'), '');

          final matched = widget.storage.patients.where((p) {
            if (query.isEmpty) return true;
            final pDigits = p.phone.replaceAll(RegExp(r'\D'), '');
            return p.name.toLowerCase().contains(query) ||
                p.phone.contains(query) ||
                (qDigits.length >= 3 && pDigits.contains(qDigits)) ||
                p.opNumber.toLowerCase().contains(query) ||
                p.doctor.toLowerCase().contains(query);
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Patient for Revisit',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search by Name, Phone, or OP #...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setModalState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: matched.isEmpty
                        ? const Center(child: Text('No matching registered patients found.'))
                        : ListView.separated(
                            itemCount: matched.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final p = matched[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primarySubtle,
                                  child: Text(
                                    p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                                  ),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${p.opNumber} • ${p.phone} • ${p.doctor}'),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _populatePatientData(p);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openTreatmentPickerModal() {
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filteredTreatments = kDentalTreatments.where((t) {
            if (query.isEmpty) return true;
            return t.toLowerCase().contains(query);
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Dental Treatment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search from ${kDentalTreatments.length} treatments (e.g. RCT, CROWN, ALIGNER)...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setModalState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredTreatments.isEmpty
                        ? const Center(child: Text('No treatments matched your search.'))
                        : ListView.separated(
                            itemCount: filteredTreatments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final treatment = filteredTreatments[idx];
                              final isSelected = _treatmentController.text == treatment;

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primaryTeal : AppTheme.primarySubtle,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.healing_outlined,
                                    size: 16,
                                    color: isSelected ? Colors.white : AppTheme.primaryDark,
                                  ),
                                ),
                                title: Text(
                                  treatment,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? AppTheme.primaryDark : const Color(0xFF0F172A),
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppTheme.primaryTeal, size: 20)
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isSelected ? AppTheme.primaryTeal : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _treatmentController.text = treatment;
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final selectedDateStr = _dateController.text.trim().isNotEmpty
        ? _dateController.text.trim()
        : DateFormat('yyyy-MM-dd').format(_selectedDate);
    final invId = 'INV-${now.year}-${DateFormat('MMddHHmm').format(now)}';

    final cleanName = _nameController.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final qDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final currentOp = _opController.text.trim();

    // Look up existing patient: by current OP or exact phone + full name match
    final existing = widget.storage.patients.firstWhere(
      (p) {
        if (currentOp.isNotEmpty && p.opNumber.trim().toLowerCase() == currentOp.toLowerCase()) {
          return true;
        }
        final pDigits = p.phone.replaceAll(RegExp(r'\D'), '');
        final pName = p.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        final phoneMatch = pDigits.isNotEmpty && qDigits.isNotEmpty &&
            (pDigits == qDigits || (pDigits.length >= 10 && qDigits.length >= 10 && pDigits.endsWith(qDigits.substring(qDigits.length - 10))));
        final nameMatch = pName.isNotEmpty && cleanName.isNotEmpty && pName == cleanName;
        return phoneMatch && nameMatch;
      },
      orElse: () => Patient(id: '', opNumber: '', name: '', phone: '', gender: '', doctor: '', registrationDate: ''),
    );

    String opNumber = _opController.text.trim();
    if (existing.id.isNotEmpty) {
      final foundOp = existing.opNumber.isNotEmpty ? existing.opNumber : 'OP-${existing.id.replaceAll(RegExp(r'\D'), '')}';
      opNumber = foundOp;
      _opController.text = foundOp;
      _isRevisit = true;
    } else if (opNumber.isEmpty) {
      final pfx = DateFormat('yyMM').format(now);
      final randomSuffix = 1000 + (now.millisecondsSinceEpoch % 9000);
      opNumber = 'OP-$pfx-$randomSuffix';
    }

    final patientId = (_isRevisit || existing.id.isNotEmpty) && opNumber.isNotEmpty
        ? 'PAT-$opNumber'
        : 'PAT-${DateFormat('ddHHmm').format(now)}';

    final effectiveDoctor = _doctor == 'Other (Type Manually)'
        ? (_manualDoctorController.text.trim().isNotEmpty
            ? _manualDoctorController.text.trim()
            : 'Attending Doctor')
        : _doctor;

    final combinedTreatments = [
      _chiefComplaintController.text.trim(),
      _treatmentController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' - ');
    final effectiveDisease = combinedTreatments.isNotEmpty
        ? combinedTreatments
        : _diseaseHistoryController.text.trim();

    final patient = Patient(
      id: patientId,
      opNumber: opNumber,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      gender: _gender,
      address: _addressController.text.trim(),
      doctor: effectiveDoctor,
      medicalHistory: _medicalHistory == 'No Significant Medical History' ? '' : _medicalHistory,
      drugAllergies: _drugAllergiesController.text.trim(),
      diseaseHistory: effectiveDisease,
      registrationDate: selectedDateStr,
    );

    final customChargesList = _customChargeRows
        .map((r) => CustomChargeItem(
              title: r['title']?.text.trim() ?? '',
              amount: double.tryParse(r['amount']?.text.trim() ?? '') ?? 0.0,
            ))
        .where((c) => c.title.isNotEmpty || c.amount > 0)
        .toList();

    final invoice = Invoice(
      id: invId,
      patientName: patient.name,
      phone: patient.phone,
      doctor: effectiveDoctor,
      date: selectedDateStr,
      consultationCharge: double.tryParse(_consultationController.text) ?? 0.0,
      treatmentCharge: double.tryParse(_treatmentChargeController.text) ?? 0.0,
      treatment: _treatmentController.text.trim().isNotEmpty
          ? _treatmentController.text.trim()
          : effectiveDisease,
      xrayCharge: double.tryParse(_xrayController.text) ?? 0.0,
      pharmacyCharge: double.tryParse(_pharmacyController.text) ?? 0.0,
      customCharges: customChargesList,
      totalAmount: _totalAmount,
      paymentMode: _paymentMode,
      notes: _notesController.text.trim(),
    );

    // Save locally
    await widget.storage.savePatient(patient);
    await widget.storage.saveInvoice(invoice);

    // Background sync attempt
    ApiService.syncRegistrationOnline(patient, invoice);

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    // Show Invoice Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoiceReceiptDialog(invoice: invoice),
    );

    // Reset Form for next patient
    _resetForm();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _isRevisit = false;
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _nameController.clear();
    _phoneController.clear();
    _opController.clear();
    _ageController.clear();
    _emailController.clear();
    _addressController.clear();
    _treatmentController.clear();
    _chiefComplaintController.clear();
    _diseaseHistoryController.clear();
    _drugAllergiesController.clear();
    _medicalHistory = 'No Significant Medical History';
    _notesController.clear();
    _consultationController.clear();
    _treatmentChargeController.clear();
    _xrayController.clear();
    _pharmacyController.clear();
    for (final row in _customChargeRows) {
      row['title']?.dispose();
      row['amount']?.dispose();
    }
    _customChargeRows.clear();
    _selectedChargeDropdown = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRevisit ? 'Patient Revisit & Consultation' : 'New Patient Registration',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Quick clinical admission, vitals & instant billing',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Revisit Toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isRevisit = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isRevisit ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_isRevisit
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '✨ New Patient',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: !_isRevisit ? AppTheme.primaryTeal : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isRevisit = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isRevisit ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _isRevisit
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '🔄 Revisit Consultation',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _isRevisit ? AppTheme.primaryTeal : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_isRevisit) ...[
                OutlinedButton.icon(
                  onPressed: _openPatientLookupModal,
                  icon: const Icon(Icons.person_search_rounded, color: AppTheme.primaryTeal),
                  label: const Text(
                    'Search & Select Returning Patient',
                    style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryTeal, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Section 1: Demographics
              _sectionTitle('1. Patient Demographics & Contact'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_isAlreadyRegistered && (_suggestedOpNumber?.isNotEmpty ?? false)) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.verified_user_rounded, color: Color(0xFF0F766E), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Already Registered Patient Detected',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Color(0xFF047857), fontSize: 12),
                                        children: [
                                          TextSpan(
                                            text: _suggestedPatientName != null && _suggestedPatientName!.isNotEmpty
                                                ? 'Patient "$_suggestedPatientName" is already registered. Suggested OP: '
                                                : 'Patient is already registered. Suggested OP: ',
                                          ),
                                          TextSpan(
                                            text: _suggestedOpNumber!,
                                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                                          ),
                                          const TextSpan(text: ' (Auto-filled)'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _suggestedOpNumber!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date *',
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primaryTeal),
                            onPressed: _selectRegistrationDate,
                          ),
                        ),
                        onTap: _selectRegistrationDate,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Phone Number *',
                          prefixIcon: Icon(Icons.phone_android, size: 20),
                          hintText: 'Enter 10-digit phone number',
                        ),
                        validator: (v) => (v == null || v.trim().length < 10) ? 'Enter valid 10-digit phone' : null,
                        onChanged: _onPhoneChanged,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Patient Full Name *',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                          hintText: 'Enter patient full name',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter patient name' : null,
                        onChanged: _onNameChanged,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Age (Years)',
                                prefixIcon: Icon(Icons.cake_outlined, size: 20),
                                hintText: '35',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: Icon(Icons.wc_outlined, size: 20),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _opController,
                              decoration: InputDecoration(
                                labelText: 'OP / Record Number',
                                prefixIcon: const Icon(Icons.tag, size: 20),
                                hintText: 'OP-401',
                                helperText: _isAlreadyRegistered && (_suggestedOpNumber?.isNotEmpty ?? false)
                                    ? 'Auto-filled suggested OP'
                                    : null,
                                helperStyle: const TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email (Optional)',
                                prefixIcon: Icon(Icons.email_outlined, size: 20),
                                hintText: 'patient@email.com',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Residential Address',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                          hintText: 'City, Street / Landmark',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: Clinical Information
              _sectionTitle('2. Medical & Clinical Assessment'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _doctor,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Attending Doctor *',
                          prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
                        ),
                        items: kClinicDoctors.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _doctor = v ?? kClinicDoctors[0]),
                      ),
                      if (_doctor == 'Other (Type Manually)') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _manualDoctorController,
                          decoration: const InputDecoration(
                            labelText: 'Type Doctor Name Manually *',
                            prefixIcon: Icon(Icons.person_add_alt_outlined, size: 20),
                            hintText: 'e.g. Dr. Jeswin Jose BDS',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter doctor name' : null,
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _medicalHistory,
                        decoration: const InputDecoration(
                          labelText: 'Systemic Medical Condition',
                          prefixIcon: Icon(Icons.favorite_border, size: 20),
                        ),
                        items: _medicalHistoryOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) => setState(() => _medicalHistory = v ?? 'No Significant Medical History'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _drugAllergiesController,
                        decoration: const InputDecoration(
                          labelText: 'Drug Allergies (e.g. Penicillin, NSAIDs)',
                          prefixIcon: Icon(Icons.warning_amber_rounded, size: 20),
                          hintText: 'Enter allergies (if any)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _chiefComplaintController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Chief Complaint',
                          prefixIcon: Icon(Icons.edit_note_outlined, size: 20),
                          hintText: 'Enter chief complaint (e.g. Toothache, Cavity, Bleeding gums)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Treatment',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                          InkWell(
                            onTap: _openTreatmentPickerModal,
                            child: const Text(
                              'Browse All 58 Treatments →',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'CONSULTATION',
                            'SCALING',
                            'RCT',
                            'COMPOSITE',
                            'CROWN PFM',
                            'POST & CORE',
                            'NORMAL EXTRACTION',
                            'CLEAR ALIGNERS',
                          ].map((t) {
                            final isSel = _treatmentController.text == t;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(t, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? AppTheme.primaryDark : const Color(0xFF334155))),
                                backgroundColor: isSel ? AppTheme.primarySubtle : const Color(0xFFF1F5F9),
                                side: BorderSide(color: isSel ? AppTheme.primaryTeal : const Color(0xFFCBD5E1)),
                                onPressed: () => setState(() => _treatmentController.text = t),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _treatmentController,
                        decoration: InputDecoration(
                          labelText: 'Treatment',
                          prefixIcon: const Icon(Icons.medical_services_outlined, size: 20),
                          hintText: 'Select treatment above or enter treatment',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.list_alt_rounded, color: AppTheme.primaryTeal),
                            tooltip: 'Browse treatments',
                            onPressed: _openTreatmentPickerModal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section 3: Billing & Charges
              _sectionTitle('3. Clinical Billing & Charges'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Charge dropdown: only contains treatment names; charge is in another option
                      DropdownButtonFormField<String>(
                        initialValue: _selectedChargeDropdown,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '🦷 Treatment / Procedure (Charge Dropdown)',
                          prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
                        ),
                        hint: const Text('-- Select Treatment Name --'),
                        items: kDentalTreatments.toSet().map((treatName) {
                          return DropdownMenuItem<String>(
                            value: treatName,
                            child: Text(
                              treatName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _selectedChargeDropdown = v;
                            _treatmentController.text = v;
                            if (kTreatmentSuggestedCharges.containsKey(v)) {
                              _treatmentChargeController.text =
                                  kTreatmentSuggestedCharges[v]!.toStringAsFixed(0);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      // Consultation Charge
                      TextFormField(
                        controller: _consultationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '🩺 Consultation Charge (₹)',
                          prefixIcon: Icon(Icons.currency_rupee, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _presetChip('Free (₹0)', 0, _consultationController),
                          _presetChip('₹200', 200, _consultationController),
                          _presetChip('₹350 (Std)', 350, _consultationController),
                          _presetChip('₹500 (Spl)', 500, _consultationController),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Treatment Charge
                      TextFormField(
                        controller: _treatmentChargeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _treatmentController.text.isNotEmpty
                              ? '🦷 Treatment Charge: ${_treatmentController.text} (₹)'
                              : '🦷 Treatment / Procedure Charge (₹)',
                          prefixIcon: const Icon(Icons.healing_outlined, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _presetChip('₹500', 500, _treatmentChargeController),
                          _presetChip('₹1,000', 1000, _treatmentChargeController),
                          _presetChip('₹2,500', 2500, _treatmentChargeController),
                          _presetChip('₹3,000', 3000, _treatmentChargeController),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // X-Ray Charge
                      TextFormField(
                        controller: _xrayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '🩻 X-Ray Examination Charge (₹)',
                          prefixIcon: Icon(Icons.camera_alt_outlined, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _presetChip('No X-Ray (₹0)', 0, _xrayController),
                          _presetChip('RVG Single (₹200)', 200, _xrayController),
                          _presetChip('Bite-wing (₹300)', 300, _xrayController),
                          _presetChip('OPG Panoramic (₹500)', 500, _xrayController),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Pharmacy Charge
                      TextFormField(
                        controller: _pharmacyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '💊 Pharmacy / Medicines Charge (₹)',
                          prefixIcon: Icon(Icons.medication_outlined, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _presetChip('No Meds (₹0)', 0, _pharmacyController),
                          _presetChip('₹100', 100, _pharmacyController),
                          _presetChip('₹200', 200, _pharmacyController),
                          _presetChip('₹350', 350, _pharmacyController),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Custom Charges Section (Add Manually like Treatment)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    '➕ Custom Charges (Add Manually):',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _addCustomChargeRow(),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('+ Add Charge', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                            if (_customChargeRows.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Tap "+ Add Charge" to add custom procedures, lab fees, or other charges manually.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ...List.generate(_customChargeRows.length, (idx) {
                              final row = _customChargeRows[idx];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: row['title'],
                                        decoration: InputDecoration(
                                          labelText: 'Charge Description #${idx + 1}',
                                          hintText: 'e.g. Scaling, Lab Fee',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: row['amount'],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Amount (₹)',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 22),
                                      tooltip: 'Remove',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeCustomChargeRow(idx),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Payment Mode
                      DropdownButtonFormField<String>(
                        initialValue: _paymentMode,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode',
                          prefixIcon: Icon(Icons.payments_outlined, size: 20),
                        ),
                        items: _paymentModes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setState(() => _paymentMode = v ?? 'Cash'),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Billing Notes / Remarks',
                          prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                          hintText: 'e.g. Paid in full, Next visit in 5 days',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total Calculation Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primarySubtle, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL DUE:',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              currency.format(_totalAmount),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitForm,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : (_isRevisit ? 'Complete Revisit & Generate Invoice' : 'Register Patient & Generate Invoice'),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF334155),
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _presetChip(String label, double amount, TextEditingController controller) {
    final curVal = double.tryParse(controller.text);
    final isSelected = curVal != null && curVal == amount && controller.text.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        controller.text = amount.toStringAsFixed(0);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryDark : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
