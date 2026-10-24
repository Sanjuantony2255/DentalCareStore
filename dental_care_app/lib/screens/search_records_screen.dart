import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/patient.dart';
import '../models/invoice.dart';
import '../models/appointment.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/invoice_receipt_dialog.dart';
import '../widgets/empty_state_view.dart';

class SearchRecordsScreen extends StatefulWidget {
  final StorageService storage;
  final Function(String name, String phone)? onBookAppointment;
  final Function(Patient patient)? onSelectPatientForRevisit;

  const SearchRecordsScreen({
    super.key,
    required this.storage,
    this.onBookAppointment,
    this.onSelectPatientForRevisit,
  });

  @override
  State<SearchRecordsScreen> createState() => _SearchRecordsScreenState();
}

class _SearchRecordsScreenState extends State<SearchRecordsScreen> {
  final _searchController = TextEditingController();
  String _activeFilter = 'all'; // 'all', 'patients', 'invoices', 'appointments'

  final List<String> _quickSuggestions = [
    'Rajesh Kumar',
    'Ananya Sharma',
    '9845012345',
    'OP-401',
    'INV-2026-001',
    'RCT',
    'CROWN PFM',
    'POST & CORE',
    'SCALING',
    'CLEAR ALIGNERS',
    'DENTAL IMPLANTS',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot initiate call to $phone')),
      );
    }
  }

  void _openInvoice(Invoice inv) {
    showDialog(
      context: context,
      builder: (_) => InvoiceReceiptDialog(invoice: inv),
    );
  }

  void _showPatientDetails(Patient patient) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with OP Number and Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      patient.opNumber.isNotEmpty ? patient.opNumber : patient.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Patient Avatar & Name
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryTeal,
                    child: Text(
                      patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${patient.age > 0 ? '${patient.age} yrs • ' : ''}${patient.gender} • Registered ${patient.registrationDate}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Contact & Fast Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callPhone(patient.phone),
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text(patient.phone),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (widget.onBookAppointment != null) {
                          widget.onBookAppointment!(patient.name, patient.phone);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Book Visit'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Medical Profile Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _metaRow('Attending Doctor', patient.doctor),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _metaRow('Medical Conditions', patient.medicalHistory),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _metaRow('Drug Allergies', patient.drugAllergies, isAlert: patient.drugAllergies.toLowerCase() != 'none'),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _metaRow('Dental Complaint', patient.diseaseHistory),
                    if (patient.address.isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _metaRow('Address', patient.address),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stats Row (Visits & Billed)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Visits', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            '${patient.totalVisits}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lifetime Billed', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            currency.format(patient.totalBilled),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Past Visits Timeline
              const Text(
                'Clinical Visit History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),

              if (patient.visits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No recorded previous visits.', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: patient.visits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final visit = patient.visits[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.primarySubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: AppTheme.primaryTeal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      visit.date,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    Text(
                                      currency.format(visit.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppTheme.primaryTeal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Doctor: ${visit.doctor}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  visit.notes,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                ),
                                if (visit.invoiceId.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Invoice: ${visit.invoiceId}',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppointmentActions(Appointment apt) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  apt.patientName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Text(
              '${apt.timeSlot} • ${apt.date} • ${apt.doctor}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Reason: ${apt.reason}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.phone, color: AppTheme.primaryTeal),
              title: Text('Call Patient (${apt.phone})'),
              onTap: () {
                Navigator.pop(ctx);
                _callPhone(apt.phone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
              title: const Text('Mark as Completed'),
              onTap: () async {
                await widget.storage.updateAppointmentStatus(apt.id, 'Completed');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appointment marked as Completed')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
              title: const Text('Cancel Appointment'),
              onTap: () async {
                await widget.storage.updateAppointmentStatus(apt.id, 'Cancelled');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appointment cancelled')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, {bool isAlert = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return AnimatedBuilder(
      animation: widget.storage,
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final qDigits = query.replaceAll(RegExp(r'\D'), '');

        final allPatients = widget.storage.patients;
        final allInvoices = widget.storage.invoices;
        final allAppointments = widget.storage.appointments;

        // 1. Matched Patients
        final matchedPatients = allPatients.where((p) {
          if (query.isEmpty) return false;
          final pDigits = p.phone.replaceAll(RegExp(r'\D'), '');
          return p.name.toLowerCase().contains(query) ||
              p.phone.contains(query) ||
              (qDigits.length >= 3 && pDigits.contains(qDigits)) ||
              p.opNumber.toLowerCase().contains(query) ||
              p.doctor.toLowerCase().contains(query) ||
              p.diseaseHistory.toLowerCase().contains(query) ||
              p.medicalHistory.toLowerCase().contains(query) ||
              p.drugAllergies.toLowerCase().contains(query) ||
              p.address.toLowerCase().contains(query);
        }).toList();

        // 2. Matched Invoices
        final matchedInvoices = allInvoices.where((inv) {
          if (query.isEmpty) return false;
          final invDigits = inv.phone.replaceAll(RegExp(r'\D'), '');
          final directMatch = inv.id.toLowerCase().contains(query) ||
              inv.patientName.toLowerCase().contains(query) ||
              inv.phone.contains(query) ||
              (qDigits.length >= 3 && invDigits.contains(qDigits)) ||
              inv.doctor.toLowerCase().contains(query) ||
              inv.paymentMode.toLowerCase().contains(query) ||
              inv.notes.toLowerCase().contains(query);

          if (directMatch) return true;

          // Also match if linked patient matches
          return matchedPatients.any((p) =>
              p.phone == inv.phone || p.name.toLowerCase() == inv.patientName.toLowerCase());
        }).toList();

        // 3. Matched Appointments
        final matchedAppointments = allAppointments.where((apt) {
          if (query.isEmpty) return false;
          final aptDigits = apt.phone.replaceAll(RegExp(r'\D'), '');
          final directMatch = apt.id.toLowerCase().contains(query) ||
              apt.patientName.toLowerCase().contains(query) ||
              apt.phone.contains(query) ||
              (qDigits.length >= 3 && aptDigits.contains(qDigits)) ||
              apt.doctor.toLowerCase().contains(query) ||
              apt.reason.toLowerCase().contains(query) ||
              apt.status.toLowerCase().contains(query) ||
              apt.notes.toLowerCase().contains(query) ||
              apt.date.contains(query);

          if (directMatch) return true;

          return matchedPatients.any((p) =>
              p.phone == apt.phone || p.name.toLowerCase() == apt.patientName.toLowerCase());
        }).toList();

        final totalMatches = matchedPatients.length + matchedInvoices.length + matchedAppointments.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Search Records & Invoices'),
            actions: [
              if (query.isNotEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalMatches Found',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Search Input Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Name, Phone, OP #, Invoice #, Doctor...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),

                    // Filter Chips Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('All Records', 'all', totalMatches),
                          const SizedBox(width: 8),
                          _filterChip('Patients', 'patients', matchedPatients.length),
                          const SizedBox(width: 8),
                          _filterChip('Invoices', 'invoices', matchedInvoices.length),
                          const SizedBox(width: 8),
                          _filterChip('Appointments', 'appointments', matchedAppointments.length),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Main Body Content
              Expanded(
                child: query.isEmpty
                    ? _buildWelcomeGuide()
                    : totalMatches == 0
                        ? EmptyStateView(
                            icon: Icons.search_off_rounded,
                            title: 'No Matching Records Found',
                            message: 'No patient profiles, invoices, or clinical appointments matched "$query".',
                          )
                        : _buildSearchResults(
                            matchedPatients: matchedPatients,
                            matchedInvoices: matchedInvoices,
                            matchedAppointments: matchedAppointments,
                            currency: currency,
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, String value, int count) {
    final isSelected = _activeFilter == value;
    final displayLabel = _searchController.text.isNotEmpty ? '$label ($count)' : label;

    return ChoiceChip(
      label: Text(displayLabel),
      selected: isSelected,
      onSelected: (_) => setState(() => _activeFilter = value),
      selectedColor: AppTheme.primarySubtle,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.primaryDark : const Color(0xFF475569),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppTheme.primaryTeal : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildWelcomeGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.manage_search_rounded, color: AppTheme.primaryTeal, size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lookup Clinical Records & Files',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Unified patient, billing & calendar search',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Search across the entire dental database with any of the following:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                _guideBullet('👤 Patient Name', 'e.g. "Rajesh Kumar" or "Ananya"'),
                _guideBullet('📞 Phone Number', 'e.g. "9845012345" (partial or full)'),
                _guideBullet('📋 OP Record Number', 'e.g. "OP-1001", "OP-1002"'),
                _guideBullet('🧾 Invoice Number', 'e.g. "INV-2026-001"'),
                _guideBullet('🩺 Procedure / Complaint', 'e.g. "Root Canal", "Wisdom Tooth"'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Suggestion Chips
          const Text(
            '⚡ Quick Lookups',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickSuggestions.map((s) {
              return ActionChip(
                avatar: const Icon(Icons.arrow_outward_rounded, size: 14, color: AppTheme.primaryTeal),
                label: Text(s),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                onPressed: () {
                  _searchController.text = s;
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _guideBullet(String title, String example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  TextSpan(text: example, style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults({
    required List<Patient> matchedPatients,
    required List<Invoice> matchedInvoices,
    required List<Appointment> matchedAppointments,
    required NumberFormat currency,
  }) {
    final showPatients = (_activeFilter == 'all' || _activeFilter == 'patients') && matchedPatients.isNotEmpty;
    final showInvoices = (_activeFilter == 'all' || _activeFilter == 'invoices') && matchedInvoices.isNotEmpty;
    final showAppointments = (_activeFilter == 'all' || _activeFilter == 'appointments') && matchedAppointments.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Patients Section
        if (showPatients) ...[
          _sectionHeader('👥 Patient Records (${matchedPatients.length})', AppTheme.primaryTeal),
          const SizedBox(height: 8),
          ...matchedPatients.map((p) => _buildPatientCard(p, currency)),
          const SizedBox(height: 16),
        ],

        // 2. Invoices Section
        if (showInvoices) ...[
          _sectionHeader('🧾 Official Invoices (${matchedInvoices.length})', const Color(0xFF0284C7)),
          const SizedBox(height: 8),
          ...matchedInvoices.map((inv) => _buildInvoiceCard(inv, currency)),
          const SizedBox(height: 16),
        ],

        // 3. Appointments Section
        if (showAppointments) ...[
          _sectionHeader('📅 Clinical Appointments (${matchedAppointments.length})', const Color(0xFF8B5CF6)),
          const SizedBox(height: 8),
          ...matchedAppointments.map((apt) => _buildAppointmentCard(apt)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard(Patient p, NumberFormat currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPatientDetails(p),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primarySubtle,
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryDark, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primarySubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.opNumber,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.age > 0 ? '${p.age} yrs • ' : ''}${p.gender} • ${p.phone}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_outlined, color: AppTheme.primaryTeal, size: 20),
                    onPressed: () => _callPhone(p.phone),
                    tooltip: 'Call Patient',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medical_services_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.diseaseHistory.isNotEmpty ? p.diseaseHistory : 'Routine Consultation',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${p.totalVisits} visit${p.totalVisits > 1 ? 's' : ''} • ${currency.format(p.totalBilled)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
                    ),
                  ],
                ),
              ),
              if (p.drugAllergies.toLowerCase() != 'none') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      Text(
                        'Allergy: ${p.drugAllergies}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice inv, NumberFormat currency) {
    final isPending = inv.paymentMode.toLowerCase().contains('pending');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openInvoice(inv),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      inv.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      inv.paymentMode.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isPending ? const Color(0xFF92400E) : const Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      inv.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    currency.format(inv.totalAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${inv.phone} • Doctor: ${inv.doctor}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    inv.date,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  const Text(
                    'Tap to view receipt →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment apt) {
    Color statusBg;
    Color statusColor;
    if (apt.status == 'Completed') {
      statusBg = const Color(0xFFDCFCE7);
      statusColor = const Color(0xFF166534);
    } else if (apt.status == 'Cancelled') {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFDC2626);
    } else {
      statusBg = const Color(0xFFE0F2FE);
      statusColor = const Color(0xFF0369A1);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAppointmentActions(apt),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    apt.patientName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      apt.status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.primaryTeal),
                  const SizedBox(width: 6),
                  Text(
                    '${apt.timeSlot} • ${apt.date}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      apt.doctor,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                apt.reason,
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
