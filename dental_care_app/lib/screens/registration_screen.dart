import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../models/invoice.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/invoice_receipt_dialog.dart';

class RegistrationScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onNavigateToAppointments;

  const RegistrationScreen({
    super.key,
    required this.storage,
    this.onNavigateToAppointments,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isRevisit = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _opController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _diseaseHistoryController = TextEditingController();
  final _drugAllergiesController = TextEditingController();

  String _gender = 'Male';
  String _doctor = 'Dr. Sanju Antony';
  String _medicalHistory = 'None';
  String _paymentMode = 'UPI / Online';

  final _consultationController = TextEditingController(text: '350');
  final _xrayController = TextEditingController(text: '0');
  final _pharmacyController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  bool _isSubmitting = false;

  final List<String> _doctorsList = [
    'Dr. Sanju Antony',
    'Dr. Sarah Mathew (Orthodontist)',
    'Dr. Jacob Thomas (Endodontist)',
  ];

  final List<String> _medicalHistoryOptions = [
    'None',
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
    _nameController.dispose();
    _phoneController.dispose();
    _opController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _diseaseHistoryController.dispose();
    _drugAllergiesController.dispose();
    _consultationController.dispose();
    _xrayController.dispose();
    _pharmacyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    final c = double.tryParse(_consultationController.text) ?? 0.0;
    final x = double.tryParse(_xrayController.text) ?? 0.0;
    final p = double.tryParse(_pharmacyController.text) ?? 0.0;
    return c + x + p;
  }

  void _onPhoneChanged(String val) {
    if (val.trim().length >= 10) {
      final existing = widget.storage.patients.firstWhere(
        (p) => p.phone.contains(val.trim()),
        orElse: () => Patient(id: '', opNumber: '', name: '', phone: '', gender: '', doctor: '', registrationDate: ''),
      );
      if (existing.id.isNotEmpty && !_isRevisit) {
        setState(() {
          _isRevisit = true;
          _nameController.text = existing.name;
          _opController.text = existing.opNumber;
          _ageController.text = existing.age > 0 ? existing.age.toString() : '';
          _emailController.text = existing.email;
          _addressController.text = existing.address;
          _gender = existing.gender;
          _doctor = existing.doctor;
          _diseaseHistoryController.text = existing.diseaseHistory;
          _drugAllergiesController.text = existing.drugAllergies;
          if (_medicalHistoryOptions.contains(existing.medicalHistory)) {
            _medicalHistory = existing.medicalHistory;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found returning patient: ${existing.name} (${existing.opNumber})'),
            backgroundColor: AppTheme.primaryTeal,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final invId = 'INV-${now.year}-${DateFormat('MMddHHmm').format(now)}';
    final patientId = _isRevisit && _opController.text.isNotEmpty
        ? 'PAT-${_opController.text}'
        : 'PAT-${DateFormat('ddHHmm').format(now)}';
    final opNumber = _opController.text.trim().isNotEmpty
        ? _opController.text.trim()
        : 'OP-${now.day}${now.hour}${now.minute}';

    final patient = Patient(
      id: patientId,
      opNumber: opNumber,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      gender: _gender,
      address: _addressController.text.trim(),
      doctor: _doctor,
      medicalHistory: _medicalHistory,
      drugAllergies: _drugAllergiesController.text.trim().isEmpty ? 'None' : _drugAllergiesController.text.trim(),
      diseaseHistory: _diseaseHistoryController.text.trim().isEmpty ? 'Dental Checkup' : _diseaseHistoryController.text.trim(),
      registrationDate: todayStr,
    );

    final invoice = Invoice(
      id: invId,
      patientName: patient.name,
      phone: patient.phone,
      doctor: patient.doctor,
      date: todayStr,
      consultationCharge: double.tryParse(_consultationController.text) ?? 0.0,
      xrayCharge: double.tryParse(_xrayController.text) ?? 0.0,
      pharmacyCharge: double.tryParse(_pharmacyController.text) ?? 0.0,
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
    _nameController.clear();
    _phoneController.clear();
    _opController.clear();
    _ageController.clear();
    _emailController.clear();
    _addressController.clear();
    _diseaseHistoryController.clear();
    _drugAllergiesController.clear();
    _notesController.clear();
    _consultationController.text = '350';
    _xrayController.text = '0';
    _pharmacyController.text = '0';
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
                      color: AppTheme.primaryTeal.withOpacity(0.25),
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
                        color: Colors.white.withOpacity(0.18),
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
                                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]
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
                                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]
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

              // Section 1: Demographics
              _sectionTitle('1. Patient Demographics & Contact'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Phone Number *',
                          prefixIcon: Icon(Icons.phone_android, size: 20),
                          hintText: 'e.g. 9845012345',
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
                          hintText: 'e.g. Rajesh Kumar',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter patient name' : null,
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
                              value: _gender,
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
                              decoration: const InputDecoration(
                                labelText: 'OP / Record Number',
                                prefixIcon: Icon(Icons.tag, size: 20),
                                hintText: 'OP-401',
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
                        value: _doctor,
                        decoration: const InputDecoration(
                          labelText: 'Attending Doctor *',
                          prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
                        ),
                        items: _doctorsList.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) => setState(() => _doctor = v ?? _doctorsList[0]),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _medicalHistory,
                        decoration: const InputDecoration(
                          labelText: 'Systemic Medical Condition',
                          prefixIcon: Icon(Icons.favorite_border, size: 20),
                        ),
                        items: _medicalHistoryOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) => setState(() => _medicalHistory = v ?? 'None'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _drugAllergiesController,
                        decoration: const InputDecoration(
                          labelText: 'Drug Allergies (e.g. Penicillin, NSAIDs)',
                          prefixIcon: Icon(Icons.warning_amber_rounded, size: 20),
                          hintText: 'None or specify',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _diseaseHistoryController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Chief Complaint / Treatment History',
                          prefixIcon: Icon(Icons.edit_note_outlined, size: 20),
                          hintText: 'e.g. Tooth sensitivity, Root canal followup, Cavity restoration',
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
                        children: [
                          _presetChip('Free (₹0)', 0, _consultationController),
                          _presetChip('₹200', 200, _consultationController),
                          _presetChip('₹350 (Std)', 350, _consultationController),
                          _presetChip('₹500 (Spl)', 500, _consultationController),
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
                      const SizedBox(height: 14),

                      // Payment Mode
                      DropdownButtonFormField<String>(
                        value: _paymentMode,
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
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        controller.text = amount.toStringAsFixed(0);
        setState(() {});
      },
      visualDensity: VisualDensity.compact,
    );
  }
}
